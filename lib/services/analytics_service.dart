import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import '../utils/api_endpoints.dart';
import '../core/logger.dart';
import 'api_service.dart';
import 'device_info_service.dart';

class AnalyticsService {
  final ApiService _api = GetIt.instance<ApiService>();
  final DeviceInfoService _deviceInfo = GetIt.instance<DeviceInfoService>();

  // Stable ID for the entire app session — reused across all events.
  final String _sessionId = const Uuid().v4();

  final List<Map<String, dynamic>> _buffer = [];
  Timer? _timer;
  bool _flushing = false;

  // ── Public tracking API ───────────────────────────────────────────────────────

  void trackViewStarted({
    required String mediaId,
    required String creatorId,
    String source = 'unknown',
    double positionSeconds = 0,
  }) => _enqueue(_build(
    eventType: 'view_started',
    mediaId: mediaId,
    creatorId: creatorId,
    source: source,
    positionSeconds: positionSeconds,
  ));

  void trackPlay({
    required String mediaId,
    required String creatorId,
    double positionSeconds = 0,
    String source = 'unknown',
  }) => _enqueue(_build(
    eventType: 'play',
    mediaId: mediaId,
    creatorId: creatorId,
    source: source,
    positionSeconds: positionSeconds,
  ));

  void trackPause({
    required String mediaId,
    required String creatorId,
    double positionSeconds = 0,
    String source = 'unknown',
  }) => _enqueue(_build(
    eventType: 'pause',
    mediaId: mediaId,
    creatorId: creatorId,
    source: source,
    positionSeconds: positionSeconds,
  ));

  void trackProgress({
    required String mediaId,
    required String creatorId,
    double positionSeconds = 0,
    String source = 'unknown',
  }) => _enqueue(_build(
    eventType: 'progress',
    mediaId: mediaId,
    creatorId: creatorId,
    source: source,
    positionSeconds: positionSeconds,
  ));

  void trackCompletion({
    required String mediaId,
    required String creatorId,
    double positionSeconds = 0,
    String source = 'unknown',
  }) => _enqueue(_build(
    eventType: 'completion',
    mediaId: mediaId,
    creatorId: creatorId,
    source: source,
    positionSeconds: positionSeconds,
  ));

  // Force-send buffered events (e.g. on completion or app background).
  void flush() => _flush();

  // ── Internals ─────────────────────────────────────────────────────────────────

  void _enqueue(Map<String, dynamic> event) {
    _buffer.add(event);
    // Start periodic flush on first event.
    _timer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => _flush(),
    );
    // Flush immediately if buffer is getting large.
    if (_buffer.length >= 10) _flush();
  }

  Future<void> _flush() async {
    if (_flushing || _buffer.isEmpty) return;
    _flushing = true;
    final events = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    try {
      await _api.post(ApiEndpoints.beaconsAuth, data: {'events': events});
      logger.d('Analytics: flushed ${events.length} event(s)');
    } catch (e) {
      logger.w('Analytics: flush failed (${events.length} event(s) dropped)', error: e);
    } finally {
      _flushing = false;
    }
  }

  Map<String, dynamic> _build({
    required String eventType,
    required String mediaId,
    required String creatorId,
    required String source,
    required double positionSeconds,
  }) => {
    'eventId': const Uuid().v4(),
    'mediaId': mediaId,
    'creatorId': creatorId,
    'eventType': eventType,
    'occurredAt': DateTime.now().toUtc().toIso8601String(),
    'positionSeconds': positionSeconds,
    'source': source,
    'identity': {'sessionId': _sessionId},
    'client': {
      'platform': _deviceInfo.platform,
      'appVersion': _deviceInfo.appVersion,
      'deviceType': 'phone',
      'networkType': 'unknown',
    },
  };
}
