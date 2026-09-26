import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:test_app/core/logger.dart';
import 'package:test_app/shared/services/token_storage_service.dart';

/// The `/live` Socket.IO namespace.
///
/// The livestream contract publishes viewer counts, status, encoder and
/// ingest state, metrics and replay status over Socket.IO. The app had no
/// socket client, so the broadcast screen polled the studio snapshot every
/// four seconds — which is both wasteful and slow to notice the thing that
/// matters most, a stream ending.
///
/// Three things the contract is specific about, and all three are honoured
/// here:
///
///  * the namespace is `/live` on the API origin, **not** `/v1/live`;
///  * mobile authenticates with `auth.token`, not a query parameter, so the
///    JWT stays out of logs;
///  * `viewer_count` and `status_changed` each carry their own monotonic
///    `revision`, tracked **separately** — a stale payload must be dropped
///    rather than applied, and comparing one stream's revision against the
///    other's would drop good ones.
///
/// Events are hints, not the source of truth: the caller still refetches the
/// HTTP snapshot after a reconnect, as the contract asks.
class LiveSocketService {
  LiveSocketService({required TokenStorageService tokenStorage, String? origin})
    : _tokenStorage = tokenStorage,
      _origin = origin;

  final TokenStorageService _tokenStorage;
  final String? _origin;

  io.Socket? _socket;

  /// Rooms to re-join after a reconnect, because the server does not
  /// remember them for us.
  final Set<String> _studios = {};
  final Set<String> _streams = {};
  final Set<String> _creators = {};

  final _events = StreamController<LiveEvent>.broadcast();

  /// Every server event, already filtered for staleness.
  Stream<LiveEvent> get events => _events.stream;

  /// Fires when the socket reconnects, which is the caller's cue to refetch
  /// the authoritative snapshot.
  final _reconnects = StreamController<void>.broadcast();
  Stream<void> get reconnects => _reconnects.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Highest revision applied, per stream, per kind. The two never share a
  /// counter.
  final Map<String, int> _viewerRevision = {};
  final Map<String, int> _statusRevision = {};

  String get _namespaceUrl {
    final base = (_origin ?? dotenv.env['BASE_URL'] ?? '').trim();
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$trimmed/live';
  }

  /// Held while a connection is being set up.
  ///
  /// There is an `await` between the null check and the assignment — the
  /// access token is read from storage — so two callers arriving together
  /// would both get past the check and build a socket each, and the second
  /// would quietly orphan the first. Both screens that use this can call it
  /// more than once (a retry, a reload), so this is reachable.
  Future<void>? _connecting;

  Future<void> connect() {
    final inFlight = _connecting;
    if (inFlight != null) return inFlight;
    if (_socket != null) return Future.value();
    late final Future<void> attempt;
    attempt = _connect().whenComplete(() {
      if (identical(_connecting, attempt)) _connecting = null;
    });
    _connecting = attempt;
    return attempt;
  }

  Future<void> _connect() async {
    if (_socket != null) return;
    final url = _namespaceUrl;
    if (url == '/live') {
      logger.w('LiveSocket: no BASE_URL, staying offline');
      return;
    }

    final token = await _tokenStorage.accessToken;
    final builder = io.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(8000);
    // Anonymous viewers connect without one; only the studio needs a session.
    if (token != null && token.isNotEmpty) {
      builder.setAuth({'token': token});
    }

    final socket = io.io(url, builder.build());
    _socket = socket;

    socket.onConnect((_) {
      logger.d('LiveSocket: connected');
      _rejoinRooms();
    });
    socket.onReconnect((_) {
      logger.d('LiveSocket: reconnected');
      _rejoinRooms();
      if (!_reconnects.isClosed) _reconnects.add(null);
    });
    socket.onConnectError(
      (e) => logger.w('LiveSocket: connect error', error: e),
    );
    socket.onError((e) => logger.w('LiveSocket: error', error: e));

    for (final name in LiveEventType.values) {
      socket.on(name.wire, (data) => _emit(name, data));
    }

    socket.connect();
  }

  void _rejoinRooms() {
    for (final id in _studios) {
      _socket?.emit('live.subscribe_studio', {'streamId': id});
    }
    for (final id in _streams) {
      _socket?.emit('live.subscribe_stream', {'streamId': id});
    }
    for (final id in _creators) {
      _socket?.emit('live.subscribe_creator', {'creatorId': id});
    }
  }

  /// Exposed because the revision rules are the part most worth pinning
  /// down, and they are unreachable through a real socket in a unit test.
  @visibleForTesting
  void handleEvent(LiveEventType type, dynamic data) => _emit(type, data);

  void _emit(LiveEventType type, dynamic data) {
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);
    final streamId = payload['streamId'] as String? ?? '';
    final revision = (payload['revision'] as num?)?.toInt();

    // Revisions are per kind. Applying a payload older than one already seen
    // would flicker a counter backwards, or worse, resurrect an ended stream.
    if (revision != null && streamId.isNotEmpty) {
      final seen = switch (type) {
        LiveEventType.viewerCount => _viewerRevision,
        LiveEventType.statusChanged => _statusRevision,
        _ => null,
      };
      if (seen != null) {
        if (revision <= (seen[streamId] ?? -1)) return;
        seen[streamId] = revision;
      }
    }

    if (!_events.isClosed) {
      _events.add(LiveEvent(type: type, data: payload));
    }
  }

  void subscribeStudio(String streamId) {
    _studios.add(streamId);
    _socket?.emit('live.subscribe_studio', {'streamId': streamId});
  }

  void unsubscribeStudio(String streamId) {
    _studios.remove(streamId);
    _viewerRevision.remove(streamId);
    _statusRevision.remove(streamId);
    _socket?.emit('live.unsubscribe_studio', {'streamId': streamId});
  }

  void subscribeStream(String streamId, {String? shareToken}) {
    _streams.add(streamId);
    _socket?.emit('live.subscribe_stream', {
      'streamId': streamId,
      'shareToken': ?shareToken,
    });
  }

  void unsubscribeStream(String streamId) {
    _streams.remove(streamId);
    _viewerRevision.remove(streamId);
    _statusRevision.remove(streamId);
    _socket?.emit('live.unsubscribe_stream', {'streamId': streamId});
  }

  void subscribeCreator(String creatorId) {
    _creators.add(creatorId);
    _socket?.emit('live.subscribe_creator', {'creatorId': creatorId});
  }

  void unsubscribeCreator(String creatorId) {
    _creators.remove(creatorId);
    _socket?.emit('live.unsubscribe_creator', {'creatorId': creatorId});
  }

  /// Presence is counted only while media is actually playing — subscribing
  /// alone must not add a viewer. The server expires presence after 45s, so
  /// the contract asks for one of these every 20.
  void viewerHeartbeat(String streamId, {required bool playing}) {
    _socket?.emit('live.viewer_heartbeat', {
      'streamId': streamId,
      'playing': playing,
    });
  }

  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    _studios.clear();
    _streams.clear();
    _creators.clear();
    _viewerRevision.clear();
    _statusRevision.clear();
    await _events.close();
    await _reconnects.close();
  }
}

enum LiveEventType {
  viewerCount('livestream.viewer_count'),
  statusChanged('livestream.status_changed'),
  encoderStatusChanged('livestream.encoder_status_changed'),
  ingestStatusChanged('livestream.ingest_status_changed'),
  metricsUpdated('livestream.metrics_updated'),
  replayStatusChanged('livestream.replay_status_changed');

  const LiveEventType(this.wire);

  final String wire;
}

class LiveEvent {
  const LiveEvent({required this.type, required this.data});

  final LiveEventType type;
  final Map<String, dynamic> data;

  String get streamId => data['streamId'] as String? ?? '';
  String get creatorId => data['creatorId'] as String? ?? '';
  String? get status => data['status'] as String?;

  int? get viewerCount => (data['viewerCount'] as num?)?.toInt();
  int? get peakViewerCount => (data['peakViewerCount'] as num?)?.toInt();
}
