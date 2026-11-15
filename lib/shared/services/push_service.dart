import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/notifications/repo/notification_repo.dart';

/// Where a push token comes from.
typedef PushTokenSource = Future<String?> Function();

/// Telling the server where to send this install's pushes.
class PushService {
  PushService({NotificationRepo? repo, PushTokenSource? tokenSource})
    : _injected = repo,
      _tokenSource = tokenSource;

  final NotificationRepo? _injected;
  final PushTokenSource? _tokenSource;

  NotificationRepo get _repo => _injected ?? GetIt.instance<NotificationRepo>();

  String? _registered;

  /// Whether a token can be obtained at all on this build.
  bool get isAvailable => _tokenSource != null;

  /// Register this install for pushes, if there is a token to register.
  Future<void> register([String? token]) async {
    final value = token ?? await _read();
    if (value == null || value.isEmpty || value == _registered) return;
    try {
      await _repo.registerDevice(value);
      _registered = value;
      logger.i('Push token registered');
    } catch (e) {
      logger.w('Push token registration failed', error: e);
    }
  }

  /// On sign-out, so the next person to hold the phone does not receive this
  /// account's notifications.
  Future<void> unregister() async {
    _registered = null;
    try {
      await _repo.unregisterDevice();
    } catch (e) {
      logger.w('Push token removal failed', error: e);
    }
  }

  Future<String?> _read() async {
    final source = _tokenSource;
    if (source == null) {
      logger.i('No push token source configured — see PushService');
      return null;
    }
    try {
      return await source();
    } catch (e) {
      logger.w('Push token unavailable', error: e);
      return null;
    }
  }
}
