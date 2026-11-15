import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/notifications/repo/notification_repo.dart';
import 'package:test_app/models/notification_models/notification_models.dart';

/// How many notifications are waiting, for the bell on every surface.
class NotificationStore extends ChangeNotifier {
  NotificationStore({NotificationRepo? repo})
    : _repo = repo ?? NotificationRepo();

  final NotificationRepo _repo;

  int _unread = 0;
  bool _hasMore = false;
  bool _loading = false;

  /// Unread rows among those counted. Never shown as a number when
  /// [hasMore] — the dot is drawn instead.
  int get unread => _unread;

  /// There are further pages, so [unread] is a floor rather than a total.
  bool get hasMore => _hasMore;

  bool get hasUnread => _unread > 0;

  /// Ask the server how many are waiting.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final page = await _repo.search(limit: NotificationRepo.pageSize);
      _apply(page);
    } catch (e) {
      logger.w('Unread count unavailable', error: e);
    } finally {
      _loading = false;
    }
  }

  /// Fold a page the list has already fetched into the count, so opening the
  /// screen does not cost a second read.
  void adopt(NotificationPage page) => _apply(page);

  void _apply(NotificationPage page) {
    final unread = page.items.where((n) => n.isUnread).length;
    final hasMore = page.nextPage != null;
    if (unread == _unread && hasMore == _hasMore) return;
    _unread = unread;
    _hasMore = hasMore;
    notifyListeners();
  }

  /// One row has been read, before the server has confirmed it.
  void markedOne() {
    if (_unread == 0) return;
    _unread--;
    notifyListeners();
  }

  /// Everything has been read.
  void markedAll() {
    if (_unread == 0 && !_hasMore) return;
    _unread = 0;
    _hasMore = false;
    notifyListeners();
  }

  /// On sign-out. A dot left over from the previous account is a leak.
  void clear() {
    if (_unread == 0 && !_hasMore) return;
    _unread = 0;
    _hasMore = false;
    notifyListeners();
  }
}
