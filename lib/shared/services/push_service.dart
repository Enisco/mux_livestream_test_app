import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/notifications/repo/notification_repo.dart';

/// Where a push token comes from.
///
/// Kept as a function rather than a dependency so this service compiles and
/// is testable with no messaging SDK present. Today nothing supplies one —
/// see the class note.
typedef PushTokenSource = Future<String?> Function();

/// Telling the server where to send this install's pushes.
///
/// The server half is **ready**: `POST /v1/notification/device-token` takes
/// `{token, platform, deviceId}` and keys on `deviceId`, so a rotated token
/// replaces its predecessor rather than adding a second device.
/// `DELETE` with `{deviceId}` takes it back. Both were exercised against
/// staging on 2026-10-14; `platform` accepts `android`, `ios` and `web`
/// despite the validator printing its enum empty.
///
/// The **device half is not**, and cannot be finished from inside this
/// repository. Delivering a push needs a Firebase project, an
/// `android/app/google-services.json`, an `ios/Runner/GoogleService-Info.plist`
/// and an APNs key uploaded to Firebase — none of which can be created here,
/// and adding `firebase_messaging` without them fails the Android build
/// outright.
///
/// So this holds the whole lifecycle and takes the token from [tokenSource].
/// When the Firebase files land, the only change is to pass
/// `FirebaseMessaging.instance.getToken` in and to forward `onTokenRefresh`
/// to [register]. Nothing else here moves.
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
  ///
  /// Called after sign-in and on every token rotation. Safe to call repeatedly:
  /// a token already sent is not sent again, and a failure is logged rather
  /// than surfaced — a reader does not need to know their push registration
  /// is late, and it is retried on the next launch.
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
