import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Liked and Saved are the same screen with a different word on the row's
/// trailing button, so they are one widget configured twice.
///
/// Both narrow by typing, both group by day, both clear behind a confirmation,
/// and Saved additionally filters by kind.
class LibraryListScreen extends StatefulWidget {
  const LibraryListScreen({
    super.key,
    required this.title,
    required this.load,
    required this.onRemove,
    required this.countLabel,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    required this.clearTitle,
    required this.clearBody,
    required this.trailingIcon,
    this.filters = const [],
  });

  final String title;

  /// One page of the list. Liked and Saved differ only in which route this
  /// calls — the row shape, the grouping and the narrowing are the same.
  final Future<LibraryPage> Function({String? cursor}) load;

  /// Take a row back out: the thumbs-up and the bookmark are the same
  /// interaction that put it here.
  final Future<void> Function(HistoryEntry entry) onRemove;

  /// How the list names its own size — counted, so a library of one does
  /// not read as "1 things".
  final String Function(int) countLabel;

  final List<List<dynamic>> emptyIcon;
  final String emptyTitle;
  final String emptyBody;

  final String clearTitle;
  final String clearBody;

  /// A thumbs-up on Liked, a bookmark on Saved — the thing that put the row
  /// here, and the way to take it back out.
  final List<List<dynamic>> trailingIcon;

  /// Saved filters by kind; Liked does not.
  final List<String> filters;

  @override
  State<LibraryListScreen> createState() => _LibraryListScreenState();
}

class _LibraryListScreenState extends State<LibraryListScreen> {
  final _controller = TextEditingController();

  String _query = '';
  late String _filter = widget.filters.isEmpty
      ? ''
      : AppStrings.libraryFilterAll;
  final _removed = <String>{};

  List<HistoryDay> _loaded = const [];
  int _total = 0;
  String? _cursor;
  bool _loading = true;
  bool _failed = false;
  bool _loadingMore = false;

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
      final page = await widget.load();
      if (!mounted) return;
      setState(() {
        _loaded = page.days;
        _total = page.total ?? _count(page.days);
        _cursor = page.nextCursor;
        _removed.clear();
        _loading = false;
      });
    } catch (e) {
      logger.w('Library list failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// A page can hydrate to fewer rows than the engagement page held, because
  /// content deleted or made private since is dropped — so keep following
  /// the cursor rather than stopping on a short page.
  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.load(cursor: cursor);
      if (!mounted) return;
      setState(() {
        _loaded = mergeDays(_loaded, page.days);
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      logger.w('Library page failed', error: e);
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  static int _count(List<HistoryDay> days) =>
      days.fold(0, (n, d) => n + d.entries.length);

  /// Open what the row is a picture of.
  ///
  /// The library is not one of the surfaces the beacon's `source` enum knows,
  /// so these clicks are reported as `unknown` rather than invented.
  void _open(HistoryEntry entry) {
    if (!openFeedItem(context, entry.source, source: AnalyticsSource.unknown)) {
      _say(AppStrings.libraryRowGone);
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

  /// Take the row out at once, and put it back if the write fails.
  Future<void> _remove(HistoryEntry entry) async {
    setState(() => _removed.add(entry.id));
    try {
      await widget.onRemove(entry);
    } catch (e) {
      logger.w('Library remove failed', error: e);
      if (!mounted) return;
      setState(() => _removed.remove(entry.id));
      _say(AppStrings.historyClearFailed);
    }
  }

  /// Which kinds a filter chip stands for. "All" stands for every kind.
  static const _kindsFor = <String, Set<HistoryKind>>{
    AppStrings.libraryFilterVideo: {HistoryKind.video, HistoryKind.library},
    AppStrings.libraryFilterAudio: {HistoryKind.audio},
    AppStrings.libraryFilterDevotionals: {HistoryKind.devotional},
    AppStrings.libraryFilterArticles: {HistoryKind.blog},
  };

  List<HistoryDay> get _days {
    final q = _query.trim().toLowerCase();
    final kinds = _kindsFor[_filter];

    final out = <HistoryDay>[];
    for (final day in _loaded) {
      final hits = day.entries
          .where((e) {
            if (_removed.contains(e.id)) return false;
            if (kinds != null && !kinds.contains(e.kind)) return false;
            if (q.isEmpty) return true;
            return e.title.toLowerCase().contains(q) ||
                e.creatorName.toLowerCase().contains(q);
          })
          .toList(growable: false);
      if (hits.isNotEmpty) out.add(HistoryDay(label: day.label, entries: hits));
    }
    return out;
  }

  bool get _narrowed =>
      _query.trim().isNotEmpty ||
      (_filter.isNotEmpty && _filter != AppStrings.libraryFilterAll);

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.fieldBg,
        title: Text(widget.clearTitle, style: AppStyles.heading(16)),
        content: Text(
          widget.clearBody,
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
              unawaited(_clearAll());
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

  /// There is no bulk route: clearing is one removal per row, which is what
  /// the interaction API offers. Rows that fail stay.
  Future<void> _clearAll() async {
    final rows = [
      for (final day in _loaded)
        for (final e in day.entries)
          if (!_removed.contains(e.id)) e,
    ];
    for (final entry in rows) {
      await _remove(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final remaining = _total - _removed.length;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryHeader(
            title: widget.title,
            actionLabel: AppStrings.historyClearAll,
            actionIcon: HugeIcons.strokeRoundedDelete02,
            onAction: _confirmClear,
            controller: _controller,
            onQueryChanged: (v) => setState(() => _query = v),
            searchHint: AppStrings.likedSearchHint,
            bottom: widget.filters.isEmpty
                ? null
                : LibraryFilterChips(
                    labels: widget.filters,
                    selected: _filter,
                    onSelected: (f) => setState(() => _filter = f),
                  ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  )
                : _failed
                ? ErrorStateView(onRetry: _load)
                : days.isEmpty
                ? SingleChildScrollView(
                    child: LibraryEmptyState(
                      icon: widget.emptyIcon,
                      title: _narrowed
                          ? AppStrings.libraryNoMatchTitle
                          : widget.emptyTitle,
                      body: _narrowed
                          ? AppStrings.libraryNoMatchBody
                          : widget.emptyBody,
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.axis == Axis.vertical &&
                          n.metrics.extentAfter < 400 &&
                          _cursor != null) {
                        unawaited(_loadMore());
                      }
                      return false;
                    },
                    child: ListView(
                      padding: EdgeInsets.only(top: 12.s, bottom: 40.s),
                      children: [
                        if (remaining > 0)
                          LibraryCount(text: widget.countLabel(remaining)),
                        for (final day in days) ...[
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
                                glyph: glyphFor(entry.kind),
                                badge: entry.duration,
                                progress: entry.progress,
                                meta: entry.isEvent ? null : metaFor(entry),
                                eventDate: entry.eventDate,
                                eventVenue: entry.eventVenue,
                                eventTime: entry.eventTime,
                                onTap: () => _open(entry),
                                trailing: _TrailingAction(
                                  icon: widget.trailingIcon,
                                  onTap: () => unawaited(_remove(entry)),
                                ),
                              ),
                            ),
                          SizedBox(height: 22.s),
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
          ),
        ],
      ),
    );
  }
}

/// The filled button that says why a row is in this list, and takes it out.
class _TrailingAction extends StatelessWidget {
  const _TrailingAction({required this.icon, required this.onTap});

  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32.s,
        height: 32.s,
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(8.s),
        ),
        child: Center(
          child: HugeIcon(
            icon: icon,
            color: AppColors.brandPrimary,
            size: 18.s,
          ),
        ),
      ),
    );
  }
}

/// Each kind names itself on the still. Shared with History.
List<List<dynamic>>? glyphFor(HistoryKind kind) => switch (kind) {
  HistoryKind.audio => HugeIcons.strokeRoundedMusicNote01,
  HistoryKind.devotional => HugeIcons.strokeRoundedBook02,
  HistoryKind.blog => HugeIcons.strokeRoundedBookOpen01,
  HistoryKind.event => HugeIcons.strokeRoundedCalendar03,
  _ => null,
};

/// "Video · 12K views · 6d" — each kind counts in its own words.
String metaFor(HistoryEntry e) => [
  e.kind.label,
  if (e.count > 0) '${formatCount(e.count)} ${e.kind.countNoun}',
  if (e.age.isNotEmpty) e.age,
].join(' · ');
