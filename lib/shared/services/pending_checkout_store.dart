import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The in-flight checkout attempt. It outlives the process because the creator
/// leaves the app to pay, and the attempt has to be recognisable when they come
/// back — or on the next cold start if they never do.
///
/// The idempotency key is stored beside the session id because the API demands
/// a *stable* key per attempt: replaying it returns the same session with a
/// fresh launch ticket, while a new key while one is live is rejected with 409.
abstract class PendingCheckoutStore {
  Future<String?> get sessionId;
  Future<String?> get attemptKey;
  Future<String?> get planTier;

  Future<void> save({
    required String sessionId,
    required String attemptKey,
    String? planTier,
  });

  Future<void> clear();

  factory PendingCheckoutStore() = SecurePendingCheckoutStore;
}

class SecurePendingCheckoutStore implements PendingCheckoutStore {
  SecurePendingCheckoutStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _sessionKey = 'gtube_pending_checkout_session';
  static const _attemptKey = 'gtube_pending_checkout_attempt';
  static const _tierKey = 'gtube_pending_checkout_tier';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> get sessionId => _storage.read(key: _sessionKey);

  @override
  Future<String?> get attemptKey => _storage.read(key: _attemptKey);

  @override
  Future<String?> get planTier => _storage.read(key: _tierKey);

  @override
  Future<void> save({
    required String sessionId,
    required String attemptKey,
    String? planTier,
  }) => Future.wait<void>([
    _storage.write(key: _sessionKey, value: sessionId),
    _storage.write(key: _attemptKey, value: attemptKey),
    if (planTier != null) _storage.write(key: _tierKey, value: planTier),
  ]);

  @override
  Future<void> clear() => Future.wait<void>([
    _storage.delete(key: _sessionKey),
    _storage.delete(key: _attemptKey),
    _storage.delete(key: _tierKey),
  ]);
}

@visibleForTesting
class InMemoryPendingCheckoutStore implements PendingCheckoutStore {
  String? _session;
  String? _attempt;
  String? _tier;

  @override
  Future<String?> get sessionId async => _session;

  @override
  Future<String?> get attemptKey async => _attempt;

  @override
  Future<String?> get planTier async => _tier;

  @override
  Future<void> save({
    required String sessionId,
    required String attemptKey,
    String? planTier,
  }) async {
    _session = sessionId;
    _attempt = attemptKey;
    _tier = planTier ?? _tier;
  }

  @override
  Future<void> clear() async {
    _session = null;
    _attempt = null;
    _tier = null;
  }
}
