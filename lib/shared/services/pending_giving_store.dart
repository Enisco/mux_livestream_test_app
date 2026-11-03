import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The gifts this device has started paying for.
///
/// A **list**, where the subscription store holds one attempt, because the two
/// products are constrained differently: the server allows only one live
/// subscription session per creator, but gifts may coexist, and a reader who
/// gives to two ministries in a row has two sessions open at once. Keeping one
/// slot would make the second gift's return link unrecognisable, and an
/// unrecognised link is silently ignored — the giver would pay and be told
/// nothing.
///
/// Only session ids are kept. They are not credentials and they prove nothing;
/// their whole job is to let the return link be matched against an attempt
/// this device actually started, before an authenticated read decides what
/// really happened. No amount, ministry, ticket or provider reference is
/// stored.
abstract class PendingGivingStore {
  /// Session ids, newest first.
  Future<List<String>> get sessions;

  Future<bool> has(String sessionId);

  Future<void> remember(String sessionId);

  Future<void> forget(String sessionId);

  Future<void> clear();

  factory PendingGivingStore() = SecurePendingGivingStore;
}

class SecurePendingGivingStore implements PendingGivingStore {
  SecurePendingGivingStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _key = 'gtube_pending_giving_sessions';

  /// Enough for a giver working through several ministries in one sitting.
  /// Older attempts fall off rather than growing without bound — a session
  /// expires server-side within a day anyway, and a forgotten id costs only
  /// the status screen, never the gift.
  static const maxRemembered = 10;

  final FlutterSecureStorage _storage;

  @override
  Future<List<String>> get sessions async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return [
        for (final id in decoded as List? ?? const [])
          if (id is String && id.isNotEmpty) id,
      ];
    } catch (_) {
      // Unreadable storage is not worth failing a gift over.
      return const [];
    }
  }

  @override
  Future<bool> has(String sessionId) async =>
      (await sessions).contains(sessionId);

  @override
  Future<void> remember(String sessionId) async {
    if (sessionId.isEmpty) return;
    final current = await sessions;
    final next = [
      sessionId,
      for (final id in current)
        if (id != sessionId) id,
    ];
    await _storage.write(
      key: _key,
      value: jsonEncode(next.take(maxRemembered).toList()),
    );
  }

  @override
  Future<void> forget(String sessionId) async {
    final current = await sessions;
    if (!current.contains(sessionId)) return;
    final next = [
      for (final id in current)
        if (id != sessionId) id,
    ];
    if (next.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: jsonEncode(next));
    }
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

@visibleForTesting
class InMemoryPendingGivingStore implements PendingGivingStore {
  final List<String> _ids = [];

  @override
  Future<List<String>> get sessions async => List.unmodifiable(_ids);

  @override
  Future<bool> has(String sessionId) async => _ids.contains(sessionId);

  @override
  Future<void> remember(String sessionId) async {
    if (sessionId.isEmpty) return;
    _ids
      ..remove(sessionId)
      ..insert(0, sessionId);
    if (_ids.length > SecurePendingGivingStore.maxRemembered) {
      _ids.removeRange(SecurePendingGivingStore.maxRemembered, _ids.length);
    }
  }

  @override
  Future<void> forget(String sessionId) async => _ids.remove(sessionId);

  @override
  Future<void> clear() async => _ids.clear();
}
