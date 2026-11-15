import 'dart:convert';

import 'package:test_app/core/logger.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The queries this reader has run before, newest first.
abstract final class RecentSearches {
  static const _key = 'gtube_recent_searches';

  /// Enough to be useful without pushing Browse off the screen.
  static const max = 8;

  static List<String> load() {
    final raw = LocalStorage.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<String>().toList(growable: false);
    } catch (e) {
      // A malformed entry is not worth surfacing; start the list over.
      logger.w('Recent searches unreadable', error: e);
      return const [];
    }
  }

  /// Moves an existing term back to the front rather than repeating it.
  static Future<List<String>> add(String query) {
    final term = query.trim();
    if (term.isEmpty) return Future.value(load());

    final next = [
      term,
      ...load().where((q) => q.toLowerCase() != term.toLowerCase()),
    ];
    return _save(next.take(max).toList(growable: false));
  }

  static Future<List<String>> remove(String query) =>
      _save(load().where((q) => q != query).toList(growable: false));

  static Future<List<String>> clear() => _save(const []);

  static Future<List<String>> _save(List<String> terms) async {
    if (terms.isEmpty) {
      await LocalStorage.remove(_key);
    } else {
      await LocalStorage.setString(_key, jsonEncode(terms));
    }
    return terms;
  }
}
