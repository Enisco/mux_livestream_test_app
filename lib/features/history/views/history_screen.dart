import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/history/data/history_dummy_data.dart';
import 'package:test_app/features/history/views/widgets/history_parts.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What the reader has watched and read, newest first.
///
/// A rail of part-watched things across the top, then everything else grouped
/// by the day it happened. Typing narrows the list without leaving the screen.
///
/// The rows are placeholders — see [HistoryDummyData], which also names the one
/// endpoint that does exist and should be wired first.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _controller = TextEditingController();

  String _query = '';
  bool _cleared = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Matching is on the row's own words — title and creator — because that is
  /// all a reader can remember about something they watched.
  List<HistoryDay> get _days {
    if (_cleared || HistoryDummyData.isEmpty) return const [];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return HistoryDummyData.days;

    final out = <HistoryDay>[];
    for (final day in HistoryDummyData.days) {
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

  List<HistoryResumeItem> get _resume =>
      _cleared || _query.isNotEmpty ? const [] : HistoryDummyData.resume;

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.fieldBg,
        title: Text(
          AppStrings.historyClearTitle,
          style: AppStyles.heading(16),
        ),
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
              // Local only: there is no route to clear anything server-side.
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
          HistoryHeader(
            controller: _controller,
            onQueryChanged: (v) => setState(() => _query = v),
            onClearAll: _confirmClear,
          ),
          Expanded(
            child: days.isEmpty && resume.isEmpty
                ? SingleChildScrollView(child: _empty())
                : ListView(
                    padding: EdgeInsets.only(top: 12.s, bottom: 40.s),
                    children: [
                      if (resume.isNotEmpty) _resumeRail(resume),
                      for (final day in days) ..._day(day),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => HistoryEmptyState(
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
                HistoryResumeCard(
                  item: item,
                  onTap: () => _todo(item.title),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 22.s),
      ],
    );
  }

  List<Widget> _day(HistoryDay day) => [
    Padding(
      padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 12.s),
      child: Text(
        day.label,
        style: AppStyles.label(14, weight: AppStyles.bold, lineHeight: 20 / 14),
      ),
    ),
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
          onTap: () => _todo(entry.title),
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
