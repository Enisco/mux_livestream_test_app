import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Running a broadcast.
///
/// See [LiveSessionDraft] for the sequence and why each step exists. Every
/// mutating call here carries an `idempotencyKey`: the backend dedupes on
/// it, which matters when a flaky connection makes the app retry a start or
/// an end it has already sent.
class LivestreamRepo {
  LivestreamRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? getIt<ApiService>();

  static const _uuid = Uuid();

  static String _key(String what) => '${what}_${_uuid.v4()}';

  /// Step 1. The RTMP target and key, cached so a later broadcast does not
  /// have to ask again.
  Future<LivestreamProvision> provision(String creatorId) async {
    try {
      final response = await _api.post(
        ApiEndpoints.provisionLivestream(creatorId),
      );
      final provision = LivestreamProvision.fromJson(
        response.data as Map<String, dynamic>,
      );
      await LocalStorage.saveStreamCredentials(
        creatorId: provision.creatorId,
        muxLiveStreamId: provision.muxLiveStreamId,
        muxLivePlaybackId: provision.muxLivePlaybackId,
        streamKeyRef: provision.streamKeyRef,
        rtmpIngestUrl: provision.rtmpIngestUrl,
      );
      return provision;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 2. Returns the session's media id, which every later call uses.
  Future<String> createSession({
    required String creatorId,
    required LiveSessionDraft draft,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.createLiveSession(creatorId),
        data: draft.toJson(),
      );
      final id = (response.data['data'] as Map<String, dynamic>?)?['id'];
      if (id is! String || id.isEmpty) {
        throw const LiveException(LiveFailure.rejected);
      }
      await LocalStorage.setString(LocalStorage.liveMediaIdKey, id);
      return id;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 3. Must happen before the device pushes: ingest is disabled the
  /// rest of the time. The lease is about fifteen minutes.
  Future<DateTime?> armIngest(String mediaId) async {
    try {
      final response = await _api.post(
        ApiEndpoints.armLiveIngest(mediaId),
        data: {'idempotencyKey': _key('arm')},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      return DateTime.tryParse(data?['armedUntil'] as String? ?? '');
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 5. The session goes to `connecting` until the provider sees the
  /// encoder, so this returning is not the same as being on air.
  Future<LiveRuntime> start(String mediaId) async {
    try {
      final response = await _api.post(
        ApiEndpoints.startLiveSession(mediaId),
        data: {'idempotencyKey': _key('start')},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      return LiveRuntime.parse(data?['livestreamRuntimeStatus'] as String?);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// The snapshot the broadcast screen's counters read.
  Future<LivestreamStudio> studio(String mediaId) async {
    final response = await _api.get(ApiEndpoints.liveStudio(mediaId));
    final data = response.data['data'] as Map<String, dynamic>?;
    if (data == null) return LivestreamStudio.empty;
    return LivestreamStudio.fromJson(data);
  }

  /// Step 6. Ends a connecting, live or reconnecting broadcast.
  Future<void> end(String mediaId, {String reason = 'creator'}) async {
    try {
      await _api.post(
        ApiEndpoints.endLivestream(mediaId),
        data: {'idempotencyKey': _key('end'), 'reason': reason},
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Backs out of a session that never went on air. Unlike [end] this is
  /// not a completed broadcast: it archives the session with
  /// `endedReason: cancelled` and drops it from upcoming discovery.
  Future<void> cancel(String mediaId) async {
    try {
      await _api.post(
        ApiEndpoints.cancelLiveSession(mediaId),
        data: {'idempotencyKey': _key('cancel')},
      );
    } catch (e) {
      // Backing out is best effort; the lease expires on its own anyway.
      logger.w('Could not cancel the live session', error: e);
    }
  }

  /// Closes the ingest window when preparation is abandoned. Not the way to
  /// end a broadcast.
  Future<void> disableIngest(String mediaId) async {
    try {
      await _api.post(
        ApiEndpoints.disableLiveIngest(mediaId),
        data: {'idempotencyKey': _key('disable')},
      );
    } catch (e) {
      logger.w('Could not disable ingest', error: e);
    }
  }

  static LiveException _translate(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const LiveException(LiveFailure.network);
    }

    final said = _sentence(e.response?.data);
    logger.w('Livestream refused: $said', error: e);
    final lower = said?.toLowerCase() ?? '';
    // Arm conflicts when another session owns the encoder or one is
    // already running, which is a 409 the creator can act on.
    if (e.response?.statusCode == 409 ||
        lower.contains('already live') ||
        lower.contains('another session')) {
      return LiveException(LiveFailure.conflict, said);
    }
    if (lower.contains('ingest') && lower.contains('arm')) {
      return LiveException(LiveFailure.notArmed, said);
    }
    return LiveException(LiveFailure.rejected, said);
  }

  static String? _sentence(dynamic payload) {
    if (payload is! Map) return null;
    final error = payload['error'];
    if (error is String && error.isNotEmpty) return error;
    if (error is List && error.isNotEmpty) return error.join('. ');
    return null;
  }
}
