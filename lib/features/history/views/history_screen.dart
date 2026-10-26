import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/features/history/views/widgets/history_parts.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What the reader has watched and read, newest first.
///
/// A rail of part-watched things across the top, then everything else grouped
/// by the day it happened. Typing narrows the list without leaving the screen.
///
/// **Clearing hides; it does not delete.** Both delete routes answer with the
/// instant history is suppressed up to, and watching the same thing again
/// brings it back — so the confirmation says "hide", not "delete for ever".
///
/// Searching narrows what has been loaded, not what the route returns: there
/// is no `q` on the history route, and the design's field sits over the list
/// rather than above a server search.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.repo});

  /// Defaults to the real thing; a test supplies its own.
  final ViewerLibraryRepo? repo;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final _repo = widget.repo ?? ViewerLibraryRepo();
  final _controller = TextEditingController();

  String _query = '';
  bool _loading = true;
  bool _failed = false;
  bool _loadingMore = false;
  List<HistoryDay> _loaded = const [];
  String? _cursor;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await _repo.fetchHistory();
      if (!mounted) return;
      setState(() {
        _loaded = page.days;
        _cursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      logger.w('History failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// A page can arrive short, or empty with a cursor, because rows whose
  /// content has gone are dropped during hydration. Keep following the
  /// cursor rather than stopping on a thin page.
  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.fetchHistory(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _loaded = _merge(_loaded, page.days);
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      logger.w('History page failed', error: e);
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Join a new page onto the list, folding a day that spans the boundary
  /// into the one already on screen rather than heading it twice.
  static List<HistoryDay> _merge(List<HistoryDay> a, List<HistoryDay> b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    final out = [...a];
    for (final day in b) {
      final i = out.indexWhere((d) => d.label == day.label);
      if (i == -1) {
        out.add(day);
      } else {
        out[i] = HistoryDay(
          label: day.label,
          entries: [...out[i].entries, ...day.entries],
        );
      }
    }
    return out;
  }

  /// Matching is on the row's own words — title and creator — because that is
  /// all a reader can remember about something they watched.
  List<HistoryDay> get _days {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _loaded;

    final out = <HistoryDay>[];
    for (final day in _loaded) {
      final hits = day.entries
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                e.creatorName.toLowerCase().contains(q),
          )
          .toList(growable: false);
      if (hits.isNotEmpty) out.add(HistoryDay(label: day.label, entries: hits));
    }
    return out;
  }

  /// The rail across the top: what was started and not finished.
  ///
  /// Taken from the same rows rather than a second read — a history entry
  /// already carries how far in the viewer got.
  List<HistoryResumeItem> get _resume {
    if (_query.isNotEmpty) return const [];
    return [
      for (final day in _loaded)
        for (final e in day.entries)
          if (e.progress != null && !e.isEvent)
            HistoryResumeItem(
              id: e.id,
              title: e.title,
              creatorName: e.creatorName,
              creatorVerified: e.creatorVerified,
              progress: e.progress!,
              thumbnailUrl: e.thumbnailUrl,
              isAudio: e.kind == HistoryKind.audio,
              source: e.source,
            ),
    ];
  }

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.fieldBg,
        title: Text(AppStrings.historyClearTitle, style: AppStyles.heading(16)),
        content: Text(
          AppStrings.historyClearBody,
          style: AppStyles.body(13, color: AppColors.neutral400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              AppStrings.notNow,
              style: AppStyles.button(13, color: AppColors.neutral400),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_clear());
            },
            child: Text(
              AppStrings.historyClearConfirm,
              style: AppStyles.button(13, color: AppColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// Open what the row is a picture of.
  void _open(WebFeedItem? item) {
    if (!openFeedItem(context, item, source: AnalyticsSource.library)) {
      _say(AppStrings.libraryRowGone);
    }
  }

  void _todo(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what is not built yet', style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final resume = _resume;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryHeader(
            title: AppStrings.historyTitle,
            actionLabel: AppStrings.historyClearAll,
            actionIcon: HugeIcons.strokeRoundedDelete02,
            onAction: _confirmClear,
            controller: _controller,
            onQueryChanged: (v) => setState(() => _query = v),
            searchHint: AppStrings.historySearchHint,
          ),
          Expanded(child: _body(days, resume)),
        ],
      ),
    );
  }

  Widget _body(List<HistoryDay> days, List<HistoryResumeItem> resume) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed) return ErrorStateView(onRetry: _load);
    if (days.isEmpty && resume.isEmpty) {
      return RefreshIndicator(
        color: AppColors.brandPrimary,
        backgroundColor: AppColors.base1,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [_empty()],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.brandPrimary,
      backgroundColor: AppColors.base1,
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical &&
              n.metrics.extentAfter < 400 &&
              _cursor != null) {
            unawaited(_loadMore());
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: 12.s, bottom: 40.s),
          children: [
            if (resume.isNotEmpty) _resumeRail(resume),
            for (final day in days) ..._day(day),
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

  /// Hide everything watched up to now.
  ///
  /// The route suppresses history through an instant rather than deleting
  /// rows, so the list empties but anything watched again comes back. The
  /// confirmation copy says so.
  Future<void> _clear() async {
    try {
      await _repo.clearHistory();
      if (!mounted) return;
      setState(() {
        _loaded = const [];
        _cursor = null;
      });
    } catch (e) {
      logger.w('History clear failed', error: e);
      if (mounted) _say(AppStrings.historyClearFailed);
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

  Widget _empty() => LibraryEmptyState(
    icon: HugeIcons.strokeRoundedUserGroup,
    title: _query.isEmpty
        ? AppStrings.historyEmptyTitle
        : AppStrings.historyNoMatchTitle,
    body: _query.isEmpty
        ? AppStrings.historyEmptyBody
        : AppStrings.historyNoMatchBody,
  );

  Widget _resumeRail(List<HistoryResumeItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 12.s),
          child: Text(
            AppStrings.historyResume,
            style: AppStyles.label(
              14,
              weight: AppStyles.bold,
              lineHeight: 20 / 14,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0) SizedBox(width: 16.s),
                HistoryResumeCard(item: item, onTap: () => _open(item.source)),
              ],
            ],
          ),
        ),
        SizedBox(height: 22.s),
      ],
    );
  }

  List<Widget> _day(HistoryDay day) => [
    LibraryGroupLabel(label: day.label),
    for (final entry in day.entries)
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.s),
        child: ContentListRow(
          title: entry.title,
          creatorName: entry.creatorName,
          creatorVerified: entry.creatorVerified,
          thumbnailAsset: entry.thumbnailAsset,
          thumbnailUrl: entry.thumbnailUrl,
          glyph: _glyphFor(entry.kind),
          badge: entry.duration,
          progress: entry.progress,
          meta: entry.isEvent ? null : _metaFor(entry),
          eventDate: entry.eventDate,
          eventVenue: entry.eventVenue,
          eventTime: entry.eventTime,
          onTap: () => _open(entry.source),
          onMore: () => _todo('History actions'),
        ),
      ),
    SizedBox(height: 22.s),
  ];

  /// Each kind names itself on the still.
  static List<List<dynamic>>? _glyphFor(HistoryKind kind) => switch (kind) {
    HistoryKind.audio => HugeIcons.strokeRoundedMusicNote01,
    HistoryKind.devotional => HugeIcons.strokeRoundedBook02,
    HistoryKind.blog => HugeIcons.strokeRoundedBookOpen01,
    HistoryKind.event => HugeIcons.strokeRoundedCalendar03,
    _ => null,
  };

  /// "Video · 12k views · 6d" — each kind counts in its own words.
  static String _metaFor(HistoryEntry e) => [
    e.kind.label,
    if (e.count > 0) '${formatCount(e.count)} ${e.kind.countNoun}',
    if (e.age.isNotEmpty) e.age,
  ].join(' · ');
}
