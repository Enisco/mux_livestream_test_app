import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/app_session_service.dart';
import 'package:test_app/shared/services/connectivity_service.dart';
import 'package:test_app/shared/services/device_info_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

class _QueuedEvent {
  _QueuedEvent(this.payload, {required this.immediate});

  final Map<String, dynamic> payload;
  final bool immediate;
  int attempts = 0;
}

/// Batches media analytics beacons and posts them to the gateway.
///
/// Billing invariants: paid events need a server-issued [PromotionAttribution];
/// qualified impressions de-duplicate per delivery per session on a
/// deterministic `eventId`; failed flushes re-queue unless the server rejected
/// the payload (4xx).
class AnalyticsService with WidgetsBindingObserver {
  AnalyticsService({
    required ApiService api,
    required DeviceInfoService deviceInfo,
    required AppSessionService session,
    required TokenStorageService tokenStorage,
    required ConnectivityService connectivity,
  }) : _api = api,
       _deviceInfo = deviceInfo,
       _session = session,
       _tokenStorage = tokenStorage,
       _connectivity = connectivity;

  final ApiService _api;
  final DeviceInfoService _deviceInfo;
  final AppSessionService _session;
  final TokenStorageService _tokenStorage;
  final ConnectivityService _connectivity;

  static const _flushInterval = Duration(seconds: 15);
  static const _flushAtCount = 10;
  static const _maxBatchSize = 40;
  static const _maxBatchesPerFlush = 5;
  static const _maxBufferedEvents = 300;
  static const _maxAttempts = 4;
  static const _baseBackoff = Duration(seconds: 3);
  static const _uuid = Uuid();

  final List<_QueuedEvent> _buffer = [];
  Timer? _timer;
  Future<void>? _inFlight;
  DateTime? _retryNotBefore;
  int _consecutiveFailures = 0;

  /// Set once the `/auth` beacon route rejects us — it wants a browser CSRF
  /// token. We then stay on the optional-auth route, which still attributes via
  /// the Bearer token.
  bool _authRouteRejected = false;

  final Set<String> _qualifiedImpressionsSent = {};

  /// Guards against a double-tap emitting two paid clicks for one delivery.
  final Map<String, DateTime> _recentPromotionClicks = {};
  static const _clickDebounce = Duration(seconds: 2);

  void init() => WidgetsBinding.instance.addObserver(this);

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The mobile equivalent of a keepalive unload flush: get progress,
    // view_ended, and completion out before the OS suspends us.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(flushNow());
    }
  }

  // ── Playback events ─────────────────────────────────────────────────────────

  void trackViewStarted({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    String source = AnalyticsSource.unknown,
    double positionSeconds = 0,
  }) => _enqueue(
    _build(
      eventType: AnalyticsEventType.viewStarted,
      mediaId: mediaId,
      creatorId: creatorId,
      mediaType: mediaType,
      source: source,
      positionSeconds: positionSeconds,
    ),
  );

  void trackPlay({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    double positionSeconds = 0,
    String source = AnalyticsSource.unknown,
  }) => _enqueue(
    _build(
      eventType: AnalyticsEventType.play,
      mediaId: mediaId,
      creatorId: creatorId,
      mediaType: mediaType,
      source: source,
      positionSeconds: positionSeconds,
    ),
  );

  void trackPause({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    double positionSeconds = 0,
    double? watchDurationSeconds,
    String source = AnalyticsSource.unknown,
  }) => _enqueue(
    _build(
      eventType: AnalyticsEventType.pause,
      mediaId: mediaId,
      creatorId: creatorId,
      mediaType: mediaType,
      source: source,
      positionSeconds: positionSeconds,
      watchDurationSeconds: watchDurationSeconds,
    ),
  );

  void trackSeek({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    required double positionSeconds,
    String source = AnalyticsSource.unknown,
  }) => _enqueue(
    _build(
      eventType: AnalyticsEventType.seek,
      mediaId: mediaId,
      creatorId: creatorId,
      mediaType: mediaType,
      source: source,
      positionSeconds: positionSeconds,
    ),
  );

  void trackProgress({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    double positionSeconds = 0,
    double? watchDurationSeconds,
    String source = AnalyticsSource.unknown,
  }) => _enqueue(
    _build(
      eventType: AnalyticsEventType.progress,
      mediaId: mediaId,
      creatorId: creatorId,
      mediaType: mediaType,
      source: source,
      positionSeconds: positionSeconds,
      watchDurationSeconds: watchDurationSeconds,
    ),
  );

  /// Viewer left, closed the player, or a livestream ended. Flushed immediately.
  void trackViewEnded({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    double positionSeconds = 0,
    double? watchDurationSeconds,
    String source = AnalyticsSource.unknown,
  }) {
    _enqueue(
      _build(
        eventType: AnalyticsEventType.viewEnded,
        mediaId: mediaId,
        creatorId: creatorId,
        mediaType: mediaType,
        source: source,
        positionSeconds: positionSeconds,
        watchDurationSeconds: watchDurationSeconds,
      ),
    );
  }

  /// VOD playback reached the actual end. Never used for livestream close.
  void trackCompletion({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    double positionSeconds = 0,
    double? watchDurationSeconds,
    String source = AnalyticsSource.unknown,
  }) {
    _enqueue(
      _build(
        eventType: AnalyticsEventType.completion,
        mediaId: mediaId,
        creatorId: creatorId,
        mediaType: mediaType,
        source: source,
        positionSeconds: positionSeconds,
        watchDurationSeconds: watchDurationSeconds,
      ),
    );
  }

  // ── Discovery events ────────────────────────────────────────────────────────

  /// Organic impression for a destination screen. Takes no attribution — a
  /// destination must never emit a catch-up paid impression.
  void trackImpression({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    String source = AnalyticsSource.unknown,
  }) => _enqueue(
    _build(
      eventType: AnalyticsEventType.impression,
      mediaId: mediaId,
      creatorId: creatorId,
      mediaType: mediaType,
      source: source,
    ),
  );

  /// Primary-navigation `click`, plus `promotion_click` when the card carries
  /// server-issued attribution. Call from the source surface just before
  /// navigating; the flush isn't awaited. Content clicks only — not likes,
  /// follows, bookmarks or context menus.
  void trackContentClick({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    required String source,
    PromotionAttribution? promotion,
  }) {
    _enqueue(
      _build(
        eventType: AnalyticsEventType.click,
        mediaId: mediaId,
        creatorId: creatorId,
        mediaType: mediaType,
        source: source,
      ),
      flush: false,
    );

    if (promotion != null && _allowPromotionClick(promotion)) {
      _enqueue(
        _build(
          eventType: AnalyticsEventType.promotionClick,
          mediaId: mediaId,
          creatorId: creatorId,
          mediaType: mediaType,
          source: source,
          promotion: promotion,
        ),
        flush: false,
      );
    }
    unawaited(flushNow());
  }

  /// Billable impression for a promoted placement that met the visibility/dwell
  /// threshold. De-duplicated per delivery per session, with a deterministic
  /// `eventId` so a retried flush is idempotent server-side.
  void trackPromotedQualifiedImpression({
    required String mediaId,
    required String creatorId,
    String? mediaType,
    required String source,
    required PromotionAttribution promotion,
    required int visibleDurationMs,
  }) {
    if (!_qualifiedImpressionsSent.add(promotion.deliveryKey)) {
      logger.d('Analytics: qualified impression already sent → $promotion');
      return;
    }
    _enqueue(
      _build(
        eventType: AnalyticsEventType.promotedQualifiedImpression,
        mediaId: mediaId,
        creatorId: creatorId,
        mediaType: mediaType,
        source: source,
        promotion: promotion,
        visibleDurationMs: visibleDurationMs,
        // Stable across retries: same session + same delivery => same UUID.
        eventId: _deterministicEventId(
          '${AnalyticsEventType.promotedQualifiedImpression}|'
          '${_session.analyticsSessionId}|${promotion.deliveryKey}',
        ),
      ),
    );
  }

  /// False if this delivery just produced a paid click — stops a double-tap
  /// billing twice.
  bool _allowPromotionClick(PromotionAttribution promotion) {
    final now = DateTime.now();
    _recentPromotionClicks.removeWhere(
      (_, at) => now.difference(at) > _clickDebounce,
    );
    final last = _recentPromotionClicks[promotion.deliveryKey];
    if (last != null && now.difference(last) < _clickDebounce) return false;
    _recentPromotionClicks[promotion.deliveryKey] = now;
    return true;
  }

  // ── Flushing ────────────────────────────────────────────────────────────────

  /// Sends everything buffered now, bypassing the backoff window. Waits out any
  /// in-flight batch first, so a caller is never silently no-op'd.
  Future<void> flushNow() async {
    final running = _inFlight;
    if (running != null) await running;
    await _flush(force: true);
  }

  /// Legacy entry point kept for existing callers.
  void flush() => unawaited(flushNow());

  void _enqueue(Map<String, dynamic> event, {bool flush = true}) {
    final eventType = event['eventType'] as String? ?? '';
    final immediate = AnalyticsEventType.immediate.contains(eventType);
    _buffer.add(_QueuedEvent(event, immediate: immediate));
    _trimBuffer();

    _timer ??= Timer.periodic(_flushInterval, (_) => unawaited(_flush()));

    if (!flush) return;
    if (immediate || _buffer.length >= _flushAtCount) {
      unawaited(_flush(force: immediate));
    }
  }

  /// Bounds memory while offline. Paid and session-terminal events are dropped
  /// last — losing a `progress` beacon costs nothing, losing a paid one costs
  /// revenue.
  void _trimBuffer() {
    if (_buffer.length <= _maxBufferedEvents) return;
    final overflow = _buffer.length - _maxBufferedEvents;
    var removed = 0;
    _buffer.removeWhere((e) {
      if (removed >= overflow) return false;
      if (e.immediate) return false;
      removed++;
      return true;
    });
    // Still over budget (everything left is high-value): drop oldest first.
    if (_buffer.length > _maxBufferedEvents) {
      _buffer.removeRange(0, _buffer.length - _maxBufferedEvents);
    }
    logger.w(
      'Analytics: buffer overflow, dropped $overflow low-value event(s)',
    );
  }

  /// Concurrent callers share one in-flight run.
  Future<void> _flush({bool force = false}) {
    final running = _inFlight;
    if (running != null) return running;
    final run = _drain(force: force).whenComplete(() => _inFlight = null);
    _inFlight = run;
    return run;
  }

  Future<void> _drain({required bool force}) async {
    if (_buffer.isEmpty) return;
    if (!force && _retryNotBefore != null) {
      if (DateTime.now().isBefore(_retryNotBefore!)) return;
    }

    // Successive batches so a backlog clears in one run, bounded so a flush
    // can't monopolise the network.
    var sent = 0;
    while (_buffer.isNotEmpty && sent < _maxBatchesPerFlush) {
      final batch = _buffer.take(_maxBatchSize).toList();
      _buffer.removeRange(0, batch.length);
      sent++;
      try {
        await _post(batch.map((e) => e.payload).toList(growable: false));
        _consecutiveFailures = 0;
        _retryNotBefore = null;
        logger.d('Analytics: flushed ${batch.length} event(s)');
      } catch (e) {
        // Stop on the first failure; backoff governs when we try again.
        _handleFlushFailure(batch, e);
        break;
      }
    }

    if (_buffer.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _handleFlushFailure(List<_QueuedEvent> batch, Object error) {
    final status = error is DioException ? error.response?.statusCode : null;
    // 4xx (bar throttling/timeout) means the payload itself was rejected;
    // identical bytes would fail again.
    final retryable =
        status == null || status >= 500 || status == 408 || status == 429;

    if (!retryable) {
      logger.w(
        'Analytics: server rejected ${batch.length} event(s) with $status — dropped',
        error: error,
      );
      return;
    }

    final requeue = <_QueuedEvent>[];
    var exhausted = 0;
    for (final event in batch) {
      event.attempts++;
      if (event.attempts >= _maxAttempts) {
        exhausted++;
        continue;
      }
      requeue.add(event);
    }
    // Head-insert so view_started → progress → view_ended ordering survives.
    _buffer.insertAll(0, requeue);
    _trimBuffer();

    _consecutiveFailures++;
    final backoff =
        _baseBackoff * (1 << (_consecutiveFailures - 1).clamp(0, 4));
    _retryNotBefore = DateTime.now().add(backoff);
    _timer ??= Timer.periodic(_flushInterval, (_) => unawaited(_flush()));

    logger.w(
      'Analytics: flush failed (status $status) — requeued ${requeue.length}, '
      'gave up on $exhausted, retrying in ${backoff.inSeconds}s',
    );
  }

  Future<void> _post(List<Map<String, dynamic>> events) async {
    final body = {'events': events};

    if (!_authRouteRejected && await _tokenStorage.hasSession) {
      try {
        await _api.post(ApiEndpoints.beaconsAuth, data: body);
        return;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        // Auth route wants a browser CSRF token; fall back permanently to the
        // optional-auth route, which still reads our Bearer token.
        if (status == 401 || status == 403 || status == 404) {
          _authRouteRejected = true;
          logger.d(
            'Analytics: /beacons/auth unavailable ($status) — '
            'using optional-auth route for the rest of this session',
          );
        } else {
          rethrow;
        }
      }
    }

    await _api.post(ApiEndpoints.beacons, data: body);
  }

  // ── Payload ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> _build({
    required String eventType,
    required String mediaId,
    required String creatorId,
    String? mediaType,
    required String source,
    double? positionSeconds,
    double? watchDurationSeconds,
    PromotionAttribution? promotion,
    int? visibleDurationMs,
    String? eventId,
  }) {
    final normalizedType = MediaTypes.normalize(mediaType);
    return {
      'eventId': eventId ?? _uuid.v4(),
      'mediaId': mediaId,
      'mediaType': ?normalizedType,
      'creatorId': creatorId,
      'eventType': eventType,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      'positionSeconds': ?positionSeconds,
      'watchDurationSeconds': ?watchDurationSeconds,
      'source': AnalyticsSource.normalize(source),
      if (promotion != null) ...promotion.toBeaconFields(),
      'visibleDurationMs': ?visibleDurationMs,
      'identity': {
        'sessionId': _session.analyticsSessionId,
        // Mobile has no `gt_anon_viewer` cookie — send the persisted equivalent.
        'anonymousViewerId': _session.anonymousViewerId,
      },
      'client': {
        'platform': _deviceInfo.platform,
        'appVersion': _deviceInfo.appVersion,
        'deviceType': _deviceInfo.deviceType,
        // Captured at enqueue time: report the network playback happened on,
        // not the one the flush went out over.
        'networkType': _connectivity.networkType,
      },
    };
  }

  String _deterministicEventId(String name) =>
      _uuid.v5(Namespace.url.value, name);
}
