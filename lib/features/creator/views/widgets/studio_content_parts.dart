import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The pieces the Content tab is made of.

/// All / Videos / Audio / Posts / Events.
class StudioContentChips extends StatelessWidget {
  const StudioContentChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// Null is "All".
  final StudioContentKind? selected;
  final ValueChanged<StudioContentKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: AppStrings.contentChipAll,
            active: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final kind in StudioContentKind.chips) ...[
            SizedBox(width: 8.s),
            _Chip(
              label: kind.chip,
              active: selected == kind,
              onTap: () => onSelected(kind),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('content-chip-$label'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 8.s),
      decoration: BoxDecoration(
        color: active ? AppColors.brandPrimary : AppColors.fieldBg,
        borderRadius: BorderRadius.circular(999.s),
      ),
      child: Text(
        label,
        style: AppStyles.label(
          13,
          weight: AppStyles.bold,
          color: active ? AppColors.base1 : AppColors.neutral200,
        ),
      ),
    ),
  );
}

/// One piece of content: a still, what it is, and how it is doing.
class StudioContentRow extends StatelessWidget {
  const StudioContentRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  final StudioContentItem item;
  final VoidCallback onTap;

  /// Share for anything published, edit for a draft.
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    // Nothing to share until it exists, so a processing row offers nothing.
    final busy = item.state == StudioContentState.processing;

    return GestureDetector(
      key: ValueKey('content-${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.s),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutral900)),
        ),
        child: Row(
          children: [
            _Still(item: item),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(14, weight: AppStyles.bold),
                  ),
                  SizedBox(height: 4.s),
                  _MetaLine(item: item),
                ],
              ),
            ),
            if (!busy) ...[
              SizedBox(width: 10.s),
              GestureDetector(
                key: ValueKey('content-action-${item.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onAction,
                child: Padding(
                  padding: EdgeInsets.all(4.s),
                  child: HugeIcon(
                    icon: item.isDraft
                        ? HugeIcons.strokeRoundedEdit02
                        : HugeIcons.strokeRoundedShare08,
                    color: AppColors.brandPrimary,
                    size: 18.s,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Public · 5,180 views · 2d", "Draft · edited 1h ago", "Processing · 12 min
/// ago" — one line that says where a piece of content stands and how it is
/// doing, in the words its kind calls for.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.item});

  final StudioContentItem item;

  @override
  Widget build(BuildContext context) {
    final processing = item.state == StudioContentState.processing;
    final wrong =
        item.state == StudioContentState.failed ||
        item.state == StudioContentState.blocked;
    final parts = <String>[];

    switch (item.state) {
      case StudioContentState.processing:
        parts.add(AppStrings.contentProcessing);
        if (_ago(item.updatedAt) case final ago?) parts.add(ago);
      case StudioContentState.draft:
        parts.add(AppStrings.contentDraft);
        if (_ago(item.updatedAt) case final ago?) {
          parts.add('${AppStrings.contentEdited} $ago');
        }
      case StudioContentState.scheduled:
        parts.add(AppStrings.contentScheduled);
        if (_ago(item.startsAt) case final ago?) parts.add(ago);
      case StudioContentState.live:
        parts.add(AppStrings.contentLiveNow);
      case StudioContentState.failed:
        parts.add(AppStrings.contentFailed);
        if (_ago(item.updatedAt) case final ago?) parts.add(ago);
      case StudioContentState.inReview:
        parts.add(AppStrings.contentInReview);
        if (_ago(item.updatedAt) case final ago?) parts.add(ago);
      case StudioContentState.blocked:
        parts.add(AppStrings.contentBlocked);
      case StudioContentState.archived:
        parts.add(AppStrings.contentArchived);
      case StudioContentState.cancelled:
        parts.add(AppStrings.contentCancelled);
      case StudioContentState.ended:
        parts.add(AppStrings.contentEnded);
        if (_ago(item.endedAt) case final ago?) parts.add(ago);
      case StudioContentState.replay:
        // A recording reads as a replay first: that is what tells the
        // creator this row was broadcast rather than uploaded.
        parts.add(AppStrings.contentReplay);
        if (_visibility(item.visibility) case final label?) parts.add(label);
        parts.addAll(_figures());
        if (_ago(item.endedAt ?? item.publishedAt) case final ago?) {
          parts.add(ago);
        }
      case StudioContentState.published:
      case StudioContentState.other:
        if (_visibility(item.visibility) case final label?) parts.add(label);
        parts.addAll(_figures());
        if (_ago(item.publishedAt) case final ago?) parts.add(ago);
    }

    // Only a published row carries the globe/link/eye that says who can see
    // it; a draft or a processing row has no visibility worth naming yet.
    final icon =
        item.state == StudioContentState.published ||
            item.state == StudioContentState.replay
        ? _visibilityIcon(item.visibility)
        : null;

    return Row(
      children: [
        if (icon case final glyph?) ...[
          HugeIcon(icon: glyph, color: AppColors.neutral500, size: 12.s),
          SizedBox(width: 4.s),
        ],
        Expanded(
          child: Text(
            parts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.label(
              12,
              // A row still being processed says so in the brand colour: it
              // is the one state the creator is waiting on. One that went
              // wrong says so in red.
              color: wrong
                  ? AppColors.destructive
                  : processing
                  ? AppColors.brandPrimary
                  : AppColors.neutral500,
              lineHeight: 16 / 12,
            ),
          ),
        ),
      ],
    );
  }

  /// Each kind counts in its own words.
  List<String> _figures() => switch (item.kind) {
    StudioContentKind.video => [
      if (item.views > 0)
        '${formatCount(item.views)} ${AppStrings.contentViews}',
    ],
    // A stream is counted in people who were there, not in views.
    StudioContentKind.livestream => [
      if (item.views > 0)
        '${formatCount(item.views)} ${AppStrings.contentWatchedLive}',
    ],
    StudioContentKind.audio => [
      if (item.views > 0)
        '${formatCount(item.views)} ${AppStrings.contentPlays}',
    ],
    StudioContentKind.post => [
      if (item.views > 0)
        '${formatCount(item.views)} ${AppStrings.contentReads}',
    ],
    StudioContentKind.event => [
      if (item.goingCount > 0)
        '${formatCount(item.goingCount)} ${AppStrings.contentGoing}',
    ],
  };

  static String? _visibility(String visibility) => switch (visibility) {
    'public' => AppStrings.contentPublic,
    'unlisted' => AppStrings.contentUnlisted,
    'private' => AppStrings.contentPrivate,
    _ => null,
  };

  static List<List<dynamic>>? _visibilityIcon(String visibility) =>
      switch (visibility) {
        'public' => HugeIcons.strokeRoundedGlobe02,
        'unlisted' => HugeIcons.strokeRoundedLink02,
        'private' => HugeIcons.strokeRoundedViewOff,
        _ => null,
      };

  /// "12 min ago", "2d", "1h ago" — short, because the row has one line.
  static String? _ago(DateTime? at) {
    if (at == null) return null;
    final gap = DateTime.now().difference(at);
    if (gap.isNegative) return null;
    if (gap.inMinutes < 1) return AppStrings.contentJustNow;
    if (gap.inMinutes < 60) return '${gap.inMinutes} min ago';
    if (gap.inHours < 24) return '${gap.inHours}h ago';
    if (gap.inDays < 7) return '${gap.inDays}d';
    return '${(gap.inDays / 7).floor()}w';
  }
}

/// The thumbnail, or what stands in for one.
class _Still extends StatelessWidget {
  const _Still({required this.item});

  final StudioContentItem item;

  @override
  Widget build(BuildContext context) {
    // An event leads with its date rather than a picture — that is what the
    // creator is looking for in the list.
    if (item.kind == StudioContentKind.event && item.startsAt != null) {
      return _DateTile(at: item.startsAt!);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.s),
      child: SizedBox(
        width: 92.s,
        height: 56.s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.fieldBg),
            Center(
              child: HugeIcon(
                icon: switch (item.state) {
                  StudioContentState.processing =>
                    HugeIcons.strokeRoundedLoading03,
                  _ => switch (item.kind) {
                    StudioContentKind.video => HugeIcons.strokeRoundedVideo01,
                    StudioContentKind.livestream =>
                      HugeIcons.strokeRoundedLiveStreaming01,
                    StudioContentKind.audio =>
                      HugeIcons.strokeRoundedHeadphones,
                    StudioContentKind.post => HugeIcons.strokeRoundedBookOpen01,
                    StudioContentKind.event =>
                      HugeIcons.strokeRoundedCalendar03,
                  },
                },
                color: item.state == StudioContentState.processing
                    ? AppColors.brandPrimary
                    : AppColors.neutral500,
                size: 18.s,
              ),
            ),
            // The still goes over the glyph, so a row with no picture — or
            // one whose picture will not load — still reads as what it is
            // rather than as an empty grey box.
            if (item.stillUrl case final url?)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (item.state == StudioContentState.live)
              Positioned(
                left: 6.s,
                top: 6.s,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.s, vertical: 1.s),
                  decoration: BoxDecoration(
                    color: AppColors.destructive,
                    borderRadius: BorderRadius.circular(4.s),
                  ),
                  child: Text(
                    AppStrings.followingLive,
                    style: AppStyles.label(
                      8,
                      weight: AppStyles.bold,
                      lineHeight: 11 / 8,
                    ),
                  ),
                ),
              ),
            if (_duration(item.durationSeconds) case final label?)
              Positioned(
                right: 5.s,
                bottom: 4.s,
                child: Text(
                  label,
                  style: AppStyles.label(
                    10,
                    weight: AppStyles.bold,
                    color: AppColors.neutral100,
                    lineHeight: 13 / 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String? _duration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final d = Duration(seconds: seconds);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$mm:$ss' : '$mm:$ss';
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.at});

  final DateTime at;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: 92.s,
    height: 56.s,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.fieldBg,
      borderRadius: BorderRadius.circular(8.s),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          at.day.toString().padLeft(2, '0'),
          style: AppStyles.heading(
            17,
            color: AppColors.brandPrimary,
            lineHeight: 21 / 17,
          ),
        ),
        Text(
          _months[at.month - 1],
          style: AppStyles.label(
            10,
            color: AppColors.brandPrimary,
            lineHeight: 13 / 10,
          ),
        ),
      ],
    ),
  );
}
