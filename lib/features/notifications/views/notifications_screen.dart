import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/library/repo/viewer_library_repo.dart'
    show dayLabel, shortAge;
import 'package:test_app/features/notifications/data/notification_store.dart';
import 'package:test_app/features/notifications/repo/notification_repo.dart';
import 'package:test_app/models/notification_models/notification_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Everything the platform has told this reader.
///
/// Grouped by day the way History is, because they answer the same question —
/// "what happened, and when". Unread rows carry a dot and a lighter plate;
/// tapping one marks it read whether or not it has anywhere to go.
///
/// The design has no frame for this screen, so it is built from the list
/// anatomy the rest of the app already uses: a [LibraryHeader] with one
/// action, day headings, and the same empty and error states.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.repo, this.store});

  /// Defaults to the real things; a test supplies its own.
  final NotificationRepo? repo;
  final NotificationStore? store;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final _repo = widget.repo ?? NotificationRepo();
  late final _store = widget.store ?? getIt<NotificationStore>();

  List<AppNotification> _rows = const [];
  int? _nextPage;
  bool _loading = true;
  bool _failed = false;
  bool _loadingMore = false;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await _repo.search();
      if (!mounted) return;
      setState(() {
        _rows = page.items;
        _nextPage = page.nextPage;
        _loading = false;
      });
      // The bell reads the same page rather than asking again.
      _store.adopt(page);
    } catch (e) {
      logger.w('Notifications failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final next = _nextPage;
    if (next == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.search(page: next);
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...page.items];
        _nextPage = page.nextPage;
        _loadingMore = false;
      });
    } catch (e) {
      logger.w('Notification page failed', error: e);
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Read the row, then go wherever it points.
  ///
  /// The read is optimistic and is not rolled back: a notification shown as
  /// read when the write failed is a far smaller wrong than one that keeps
  /// coming back after the reader has dealt with it.
  Future<void> _open(AppNotification row) async {
    if (row.isUnread) {
      setState(() {
        _rows = [
          for (final n in _rows)
            n.id == row.id ? n.markedRead(DateTime.now()) : n,
        ];
      });
      _store.markedOne();
      try {
        await _repo.markRead(row.id);
      } catch (e) {
        logger.w('Mark read failed', error: e);
      }
    }
    // Nothing staging sends carries an `actionUrl` yet. When one arrives it
    // is a route within the app, so it is pushed rather than opened out.
    final target = row.actionUrl;
    if (target != null && mounted) {
      logger.i('Notification action: $target');
    }
  }

  Future<void> _markAll() async {
    if (_markingAll || _rows.every((n) => !n.isUnread)) return;
    setState(() => _markingAll = true);
    final before = _rows;
    final now = DateTime.now();
    setState(() => _rows = [for (final n in _rows) n.markedRead(now)]);
    _store.markedAll();
    try {
      final count = await _repo.markAllRead();
      if (!mounted) return;
      setState(() => _markingAll = false);
      _say(AppStrings.notificationsMarkedAll(count));
    } catch (e) {
      logger.w('Mark all read failed', error: e);
      if (!mounted) return;
      setState(() {
        _rows = before;
        _markingAll = false;
      });
      unawaited(_store.refresh());
      _say(AppStrings.notificationsMarkAllFailed);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Rows under the heading for the day they arrived, newest first.
  List<(String, List<AppNotification>)> get _days {
    final out = <(String, List<AppNotification>)>[];
    for (final row in _rows) {
      final label = dayLabel(row.createdAt);
      if (out.isNotEmpty && out.last.$1 == label) {
        out.last.$2.add(row);
      } else {
        out.add((label, [row]));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final anyUnread = _rows.any((n) => n.isUnread);

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LibraryHeader(
              title: AppStrings.notificationsTitle,
              // Offered only when it would do something.
              actionLabel: anyUnread ? AppStrings.notificationsMarkAll : null,
              actionIcon: anyUnread
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : null,
              onAction: anyUnread ? () => unawaited(_markAll()) : null,
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed) return ErrorStateView(onRetry: _load);

    return RefreshIndicator(
      color: AppColors.brandPrimary,
      backgroundColor: AppColors.base1,
      onRefresh: _load,
      child: _rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 40.s),
                const LibraryEmptyState(
                  icon: HugeIcons.strokeRoundedNotification02,
                  title: AppStrings.notificationsEmptyTitle,
                  body: AppStrings.notificationsEmptyBody,
                ),
              ],
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.axis == Axis.vertical &&
                    n.metrics.extentAfter < 400 &&
                    _nextPage != null) {
                  unawaited(_loadMore());
                }
                return false;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 12.s, bottom: 40.s),
                children: [
                  for (final (label, rows) in _days) ...[
                    LibraryGroupLabel(label: label),
                    for (final row in rows)
                      _Row(row: row, onTap: () => unawaited(_open(row))),
                    SizedBox(height: 18.s),
                  ],
                  if (_loadingMore)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.s),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// One notification. Unread rows sit on a plate and carry a dot.
class _Row extends StatelessWidget {
  const _Row({required this.row, required this.onTap});

  final AppNotification row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = row.isUnread;
    return GestureDetector(
      key: ValueKey('notification-${row.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(16.s, 0, 16.s, 8.s),
        padding: EdgeInsets.all(12.s),
        decoration: BoxDecoration(
          color: unread ? AppColors.fieldBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10.s),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36.s,
              height: 36.s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neutral900,
              ),
              child: Center(
                child: HugeIcon(
                  icon: _glyphFor(row.type),
                  color: AppColors.brandPrimary,
                  size: 18.s,
                ),
              ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.title,
                    style: AppStyles.label(
                      14,
                      weight: unread ? AppStyles.bold : AppStyles.medium,
                      lineHeight: 20 / 14,
                    ),
                  ),
                  if (row.body.isNotEmpty) ...[
                    SizedBox(height: 3.s),
                    Text(
                      row.body,
                      style: AppStyles.label(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 17 / 12,
                      ),
                    ),
                  ],
                  SizedBox(height: 5.s),
                  Text(
                    shortAge(row.createdAt),
                    style: AppStyles.label(
                      11,
                      color: AppColors.neutral500,
                      lineHeight: 14 / 11,
                    ),
                  ),
                ],
              ),
            ),
            if (unread) ...[
              SizedBox(width: 10.s),
              Padding(
                padding: EdgeInsets.only(top: 6.s),
                child: Container(
                  width: 8.s,
                  height: 8.s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Each kind of notification names itself. An unknown type — one added
  /// server-side after this release — gets the bell rather than nothing.
  static List<List<dynamic>> _glyphFor(String type) => switch (type) {
    'WELCOME' || 'CREATOR_ONBOARDED' => HugeIcons.strokeRoundedUserCheck01,
    'FILE_UPLOAD_COMPLETE' ||
    'MEDIA_READY' ||
    'MEDIA_PUBLISHED' => HugeIcons.strokeRoundedVideoReplay,
    'NEW_FOLLOWER' || 'SUBSCRIPTION' => HugeIcons.strokeRoundedUserGroup,
    'COMMENT' || 'COMMENT_REPLY' => HugeIcons.strokeRoundedMessage01,
    'PRAYER_REQUEST' => HugeIcons.strokeRoundedHandPrayer,
    'TESTIMONY' => HugeIcons.strokeRoundedFavourite,
    'EVENT_REMINDER' || 'EVENT' => HugeIcons.strokeRoundedCalendar03,
    'LIVESTREAM_STARTED' || 'LIVE' => HugeIcons.strokeRoundedLiveStreaming01,
    _ => HugeIcons.strokeRoundedNotification02,
  };
}
