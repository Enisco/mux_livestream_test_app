import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/data/records_dummy_data.dart';
import 'package:test_app/models/library_models/library_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Events the reader said they would go to, split by whether they still can.
///
/// Nothing is stored — see [RecordsDummyData]. Tapping RSVP flips the row
/// locally so the two states can be seen; it posts nothing.
class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final _controller = TextEditingController();
  String _query = '';
  final _going = <String>{};

  @override
  void initState() {
    super.initState();
    for (final e in RecordsDummyData.events) {
      if (e.going) _going.add(e.id);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<MyEvent> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return RecordsDummyData.events;
    return RecordsDummyData.events
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.creatorName.toLowerCase().contains(q) ||
              e.venue.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final upcoming = matches.where((e) => !e.past).toList(growable: false);
    final past = matches.where((e) => e.past).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryHeader(
            title: AppStrings.myEventsTitle,
            actionLabel: AppStrings.myEventsSort,
            actionIcon: HugeIcons.strokeRoundedSorting05,
            onAction: () => _report('Sorting is not built yet'),
            controller: _controller,
            onQueryChanged: (v) => setState(() => _query = v),
            searchHint: AppStrings.likedSearchHint,
          ),
          Expanded(
            child: matches.isEmpty
                ? SingleChildScrollView(
                    child: LibraryEmptyState(
                      icon: HugeIcons.strokeRoundedFavourite,
                      title: _query.trim().isEmpty
                          ? AppStrings.myEventsEmptyTitle
                          : AppStrings.libraryNoMatchTitle,
                      body: _query.trim().isEmpty
                          ? AppStrings.myEventsEmptyBody
                          : AppStrings.libraryNoMatchBody,
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.only(top: 12.s, bottom: 40.s),
                    children: [
                      LibraryCount(
                        text:
                            '${RecordsDummyData.eventsTotal} '
                            '${AppStrings.myEventsCountSuffix}',
                      ),
                      if (upcoming.isNotEmpty) ...[
                        LibraryGroupLabel(
                          label:
                              '${AppStrings.myEventsUpcoming} '
                              '(${upcoming.length})',
                          caps: true,
                        ),
                        for (final e in upcoming) _row(e),
                      ],
                      if (past.isNotEmpty) ...[
                        SizedBox(height: 10.s),
                        LibraryGroupLabel(
                          label: '${AppStrings.myEventsPast} (${past.length})',
                          caps: true,
                        ),
                        for (final e in past) _row(e),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(MyEvent event) {
    final going = _going.contains(event.id);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.s),
      padding: EdgeInsets.symmetric(vertical: 14.s),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.neutral900)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _report(event.title),
            child: Row(
              children: [
                _DateTile(day: event.day, month: event.month),
                SizedBox(width: 12.s),
                Expanded(child: _Details(event: event)),
                Icon(
                  AppIcons.chevronRight,
                  size: 16.s,
                  color: AppColors.neutral500,
                ),
              ],
            ),
          ),
          // A past event has nothing left to answer, so it carries no actions.
          if (!event.past) ...[
            SizedBox(height: 14.s),
            Row(
              children: [
                Expanded(
                  child: _EventButton(
                    label: going
                        ? AppStrings.myEventsGoing
                        : AppStrings.myEventsRsvp,
                    icon: going
                        ? HugeIcons.strokeRoundedCheckmarkCircle02
                        : null,
                    tint: going ? AppColors.green500 : null,
                    onTap: () => setState(() {
                      going ? _going.remove(event.id) : _going.add(event.id);
                    }),
                  ),
                ),
                SizedBox(width: 12.s),
                Expanded(
                  child: _EventButton(
                    label: AppStrings.myEventsAddToCalendar,
                    icon: HugeIcons.strokeRoundedCalendar03,
                    onTap: () =>
                        _report('Adding to your calendar is not built yet'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.day, required this.month});

  final String day;
  final String month;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46.s,
      padding: EdgeInsets.symmetric(vertical: 8.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(8.s),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: AppStyles.heading(
              18,
              color: AppColors.brandPrimary,
              lineHeight: 22 / 18,
            ),
          ),
          Text(
            month,
            style: AppStyles.label(
              11,
              color: AppColors.brandPrimary,
              lineHeight: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.event});

  final MyEvent event;

  @override
  Widget build(BuildContext context) {
    final muted = AppStyles.label(
      12,
      color: AppColors.neutral500,
      lineHeight: 16 / 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.label(14, weight: AppStyles.bold),
        ),
        SizedBox(height: 4.s),
        Row(
          children: [
            Flexible(
              child: Text(
                event.creatorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(
                  12,
                  color: AppColors.neutral400,
                  lineHeight: 16 / 12,
                ),
              ),
            ),
            if (event.creatorVerified) ...[
              SizedBox(width: 4.s),
              DesignIcon(AppAssets.iconFeedVerified, width: 14.s, height: 14.s),
            ],
          ],
        ),
        SizedBox(height: 4.s),
        Row(
          children: [
            DesignIcon(
              AppAssets.iconPin,
              width: 14.s,
              height: 14.s,
              color: AppColors.neutral500,
            ),
            SizedBox(width: 2.s),
            Flexible(
              child: Text(
                event.venue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
            SizedBox(width: 6.s),
            Text('·', style: muted),
            SizedBox(width: 6.s),
            Text(
              event.time,
              style: AppStyles.label(
                12,
                weight: AppStyles.bold,
                lineHeight: 16 / 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The bordered button under an upcoming event.
class _EventButton extends StatelessWidget {
  const _EventButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
  });

  final String label;
  final VoidCallback onTap;
  final List<List<dynamic>>? icon;

  /// Green once the reader has said they are going.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colour = tint ?? AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(color: tint ?? AppColors.neutral700),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final glyph?) ...[
              HugeIcon(icon: glyph, color: colour, size: 16.s),
              SizedBox(width: 8.s),
            ],
            Text(label, style: AppStyles.button(13, color: colour)),
          ],
        ),
      ),
    );
  }
}
