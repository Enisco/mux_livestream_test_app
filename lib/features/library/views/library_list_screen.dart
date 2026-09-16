import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
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
    required this.days,
    required this.total,
    required this.countSuffix,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    required this.clearTitle,
    required this.clearBody,
    required this.trailingIcon,
    this.filters = const [],
  });

  final String title;
  final List<HistoryDay> days;

  /// The whole library's size, which is larger than the rows on hand.
  final int total;
  final String countSuffix;

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
  bool _cleared = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Which kinds a filter chip stands for. "All" stands for every kind.
  static const _kindsFor = <String, Set<HistoryKind>>{
    AppStrings.libraryFilterVideo: {HistoryKind.video, HistoryKind.library},
    AppStrings.libraryFilterAudio: {HistoryKind.audio},
    AppStrings.libraryFilterDevotionals: {HistoryKind.devotional},
    AppStrings.libraryFilterArticles: {HistoryKind.blog},
  };

  List<HistoryDay> get _days {
    if (_cleared) return const [];
    final q = _query.trim().toLowerCase();
    final kinds = _kindsFor[_filter];

    final out = <HistoryDay>[];
    for (final day in widget.days) {
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
              // Local only: no route lists or clears these yet.
              setState(() => _cleared = true);
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

  @override
  Widget build(BuildContext context) {
    final days = _days;
    final remaining = widget.total - _removed.length;

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
            child: days.isEmpty
                ? SingleChildScrollView(
                    child: LibraryEmptyState(
                      icon: widget.emptyIcon,
                      title: _narrowed && !_cleared
                          ? AppStrings.libraryNoMatchTitle
                          : widget.emptyTitle,
                      body: _narrowed && !_cleared
                          ? AppStrings.libraryNoMatchBody
                          : widget.emptyBody,
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.only(top: 12.s, bottom: 40.s),
                    children: [
                      if (!_cleared)
                        LibraryCount(
                          text:
                              '${formatCount(remaining)} '
                              '${widget.countSuffix}',
                        ),
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
                              glyph: glyphFor(entry.kind),
                              badge: entry.duration,
                              progress: entry.progress,
                              meta: entry.isEvent ? null : metaFor(entry),
                              eventDate: entry.eventDate,
                              eventVenue: entry.eventVenue,
                              eventTime: entry.eventTime,
                              trailing: _TrailingAction(
                                icon: widget.trailingIcon,
                                onTap: () =>
                                    setState(() => _removed.add(entry.id)),
                              ),
                            ),
                          ),
                        SizedBox(height: 22.s),
                      ],
                    ],
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
