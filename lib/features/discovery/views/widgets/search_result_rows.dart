import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount, relativeAge;
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/shared/services/viewer_identity.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The rows search results are built from.
///
/// Results are grouped by kind rather than mixed, so each row can be as small
/// as its kind allows — a ministry needs a follow button, a video needs a
/// still, an event needs a date. That is why these are compact rows rather
/// than the feed's full cards.

/// A group's caption: MINISTRIES, VIDEOS, EVENTS.
class SearchGroupHeader extends StatelessWidget {
  const SearchGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 10.s),
      child: Text(
        label,
        style: AppStyles.label(
          12,
          weight: AppStyles.black,
          color: AppColors.neutral400,
          lineHeight: 16 / 12,
        ),
      ),
    );
  }
}

/// A creator result, with the one action that matters on this screen.
class SearchMinistryRow extends StatelessWidget {
  const SearchMinistryRow({
    super.key,
    required this.item,
    required this.following,
    this.onTap,
    this.onFollow,
    this.onMore,
  });

  final WebFeedItem item;
  final bool following;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 27.s),
        padding: EdgeInsets.symmetric(vertical: 12.s),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutral900)),
        ),
        child: Row(
          children: [
            _Avatar(
              url: item.meta.thumbnailUrl,
              size: 32.s,
              ring: AppColors.cyan400,
            ),
            SizedBox(width: 10.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.creatorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyles.heading(13),
                        ),
                      ),
                      if (item.creatorVerified) ...[
                        SizedBox(width: 4.s),
                        DesignIcon(
                          AppAssets.iconFeedVerified,
                          width: 16.s,
                          height: 16.s,
                        ),
                      ],
                    ],
                  ),
                  if (item.creatorHandle.isNotEmpty)
                    Text(
                      '@${item.creatorHandle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.label(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 16 / 12,
                      ),
                    ),
                ],
              ),
            ),
            // Nobody follows their own ministry, and the API refuses it.
            if (!ViewerIdentity.owns(
              item.profileCreatorId,
              flaggedByApi: item.isOwnedByViewer,
            )) ...[
              SizedBox(width: 10.s),
              _OutlineButton(
                key: const ValueKey('search-follow'),
                label: following
                    ? AppStrings.searchFollowing
                    : AppStrings.searchFollow,
                onTap: onFollow,
              ),
            ],
            SizedBox(width: 10.s),
            _OutlineButton(
              icon: HugeIcons.strokeRoundedMoreVertical,
              onTap: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// A media, devotional or blog result.
///
/// The row itself is [ContentListRow], shared with history — the design draws
/// them identically, so they are one widget.
class SearchContentRow extends StatelessWidget {
  const SearchContentRow({
    super.key,
    required this.item,
    required this.kindLabel,
    this.onTap,
    this.onMore,
  });

  final WebFeedItem item;

  /// "Video", "Audio", "Blog" — what the meta line leads with.
  final String kindLabel;

  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final views = item.facets.views;
    final age = relativeAge(item.meta.publishedAt);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.s),
      child: ContentListRow(
        title: item.title,
        creatorName: item.creatorDisplayName,
        creatorVerified: item.creatorVerified,
        thumbnailUrl: item.meta.thumbnailUrl,
        meta: [
          kindLabel,
          if (views > 0)
            '${formatCount(views)} ${AppStrings.searchViewsSuffix}',
          if (age.isNotEmpty) age,
        ].join(' · '),
        onTap: onTap,
        onMore: onMore,
      ),
    );
  }
}

/// An event result: the date tile, who is hosting, and where.
class SearchEventRow extends StatelessWidget {
  const SearchEventRow({
    super.key,
    required this.item,
    this.onTap,
    this.onRsvp,
  });

  final WebFeedItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRsvp;

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
  Widget build(BuildContext context) {
    final at = item.startsAt?.toLocal();
    final muted = AppStyles.label(
      12,
      weight: AppStyles.bold,
      color: AppColors.neutral500,
      lineHeight: 16 / 12,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 11.s),
        child: Row(
          children: [
            if (at != null) ...[
              _DateTile(
                day: at.day.toString().padLeft(2, '0'),
                month: _months[at.month - 1],
              ),
              SizedBox(width: 10.s),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _Avatar(url: null, size: 12.s),
                      SizedBox(width: 4.s),
                      Flexible(
                        child: Text(
                          item.creatorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyles.label(
                            12,
                            color: AppColors.neutral400,
                            lineHeight: 16 / 12,
                          ),
                        ),
                      ),
                      if (item.creatorVerified) ...[
                        SizedBox(width: 4.s),
                        DesignIcon(
                          AppAssets.iconFeedVerified,
                          width: 16.s,
                          height: 16.s,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.s),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.heading(14, lineHeight: 20 / 14),
                  ),
                  SizedBox(height: 7.s),
                  Row(
                    children: [
                      if (item.meta.locationLabel case final where?
                          when where.isNotEmpty) ...[
                        DesignIcon(
                          AppAssets.iconPin,
                          width: 16.s,
                          height: 16.s,
                          color: AppColors.neutral500,
                        ),
                        SizedBox(width: 2.s),
                        Flexible(child: Text(where, maxLines: 1, style: muted)),
                        SizedBox(width: 6.s),
                        Text('·', style: muted),
                        SizedBox(width: 6.s),
                      ],
                      if (at != null) Text(_time(at), style: muted),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.s),
            _OutlineButton(label: AppStrings.searchRsvp, onTap: onRsvp),
          ],
        ),
      ),
    );
  }

  static String _time(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m${at.hour < 12 ? 'am' : 'pm'}';
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.day, required this.month});

  final String day;
  final String month;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 6.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.8.s),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.dateTileFrom, AppColors.dateTileTo],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: AppStyles.heading(
              19.2,
              color: AppColors.dateTileDay,
              lineHeight: 28.8 / 19.2,
            ),
          ),
          Text(
            month,
            style: AppStyles.label(
              14.4,
              color: AppColors.dateTileMonth,
              lineHeight: 19.2 / 14.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the queries this reader ran before.
class RecentSearchRow extends StatelessWidget {
  const RecentSearchRow({
    super.key,
    required this.term,
    this.onTap,
    this.onRemove,
  });

  final String term;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 8.s),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              color: AppColors.neutral400,
              size: 16.s,
            ),
            SizedBox(width: 10.s),
            Expanded(
              child: Text(
                term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(13, weight: AppStyles.bold),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: EdgeInsets.all(4.s),
                child: Icon(
                  Icons.close_rounded,
                  size: 16.s,
                  color: AppColors.neutral400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A phrase the field is offering to complete.
class SearchSuggestionRow extends StatelessWidget {
  const SearchSuggestionRow({
    super.key,
    required this.phrase,
    this.onTap,
    this.onFill,
  });

  final String phrase;

  /// Runs the search.
  final VoidCallback? onTap;

  /// Puts the phrase in the field without running it, so it can be edited.
  final VoidCallback? onFill;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 8.s),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              color: AppColors.neutral300,
              size: 16.s,
            ),
            SizedBox(width: 10.s),
            Expanded(
              child: Text(
                phrase,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(13, weight: AppStyles.bold),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onFill,
              child: Padding(
                padding: EdgeInsets.all(4.s),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowUpRight01,
                  color: AppColors.neutral400,
                  size: 16.s,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size, this.ring});

  final String? url;
  final double size;

  /// Cyan on a ministry result, purple on the creator line under a title —
  /// the design rings them differently so the two do not read as the same row.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.buttonSecondaryActive,
        border: Border.all(
          color: ring ?? AppColors.purple400,
          width: size / 16,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(Icons.person, size: size * 0.6, color: AppColors.neutral400)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.buttonSecondaryActive),
            ),
    );
  }
}

/// The bordered pill the design uses for Follow, RSVP and the overflow.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({super.key, this.label, this.icon, this.onTap});

  final String? label;
  final List<List<dynamic>>? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label == null ? 11.s : 16.s,
          vertical: label == null ? 5.s : 11.s,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(
            color: label == null ? AppColors.neutral800 : AppColors.neutral700,
            width: 1.5.s,
          ),
        ),
        child: icon != null
            ? HugeIcon(icon: icon!, color: AppColors.textPrimary, size: 20.s)
            : Text(label!, style: AppStyles.button(13)),
      ),
    );
  }
}
