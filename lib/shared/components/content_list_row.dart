import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// A piece of content as a list row: still on the left, everything needed to
/// judge it on the right, and an overflow button.
///
/// Search results and history entries are the same row in the design, differing
/// only in what the still carries — a kind glyph, a runtime, a watched bar —
/// and whether the last line is a meta summary or an event's date and place.
/// One widget covers both so the two screens cannot drift apart.
class ContentListRow extends StatelessWidget {
  const ContentListRow({
    super.key,
    required this.title,
    required this.creatorName,
    this.creatorVerified = false,
    this.thumbnailUrl,
    this.thumbnailAsset,
    this.glyph,
    this.badge,
    this.progress,
    this.meta,
    this.eventDate,
    this.eventVenue,
    this.eventTime,
    this.titleMaxLines = 2,
    this.compact = false,
    this.moreKey,
    this.trailing,
    this.onTap,
    this.onMore,
  });

  final String title;
  final String creatorName;
  final bool creatorVerified;

  final String? thumbnailUrl;
  final String? thumbnailAsset;

  /// Centred on the still. Defaults to a play symbol; audio, devotionals,
  /// blogs and events each name themselves with their own.
  final List<List<dynamic>>? glyph;

  /// Bottom-right on the still — a runtime, usually.
  final String? badge;

  /// How far the reader got, 0-1. Draws the bar along the bottom of the still.
  final double? progress;

  /// "Video · 12k views · 6d". Replaced by the event lines when those are set.
  final String? meta;

  final String? eventDate;
  final String? eventVenue;
  final String? eventTime;

  final int titleMaxLines;

  /// Playlists draw the same row on a smaller still, with the runtime in the
  /// bottom-left corner rather than the bottom-right.
  final bool compact;

  /// Names the overflow button, for screens that open different sheets from
  /// different rows.
  final Key? moreKey;

  /// Replaces the overflow button — Liked and Saved put the thing that filed
  /// the row here instead, so tapping it takes the row back out.
  final Widget? trailing;

  final VoidCallback? onTap;
  final VoidCallback? onMore;

  bool get _isEvent => eventDate != null || eventVenue != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Still(
              url: thumbnailUrl,
              asset: thumbnailAsset,
              glyph: glyph,
              badge: badge,
              progress: progress,
              compact: compact,
            ),
            SizedBox(width: 8.s),
            Expanded(child: _Body(row: this)),
            SizedBox(width: 10.s),
            trailing ??
                GestureDetector(
                  key: moreKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onMore,
                  child: SizedBox(
                    width: 24.s,
                    height: 24.s,
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedMoreVertical,
                      color: AppColors.neutral400,
                      size: 20.s,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Still extends StatelessWidget {
  const _Still({
    this.url,
    this.asset,
    this.glyph,
    this.badge,
    this.progress,
    this.compact = false,
  });

  final String? url;
  final String? asset;
  final List<List<dynamic>>? glyph;
  final String? badge;
  final double? progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.s),
      child: SizedBox(
        width: compact ? 104.s : 146.s,
        height: compact ? 58.s : 87.s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (asset != null)
              Image.asset(asset!, fit: BoxFit.cover)
            else if (url != null && url!.isNotEmpty)
              Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.base2),
              )
            else
              const ColoredBox(color: AppColors.base2),
            Center(
              child: HugeIcon(
                icon: glyph ?? HugeIcons.strokeRoundedPlayCircle,
                color: AppColors.textPrimary,
                size: 20.s,
              ),
            ),
            if (badge case final label?)
              Positioned(
                left: compact ? 8.s : null,
                right: compact ? null : 8.s,
                bottom: 6.s,
                child: Text(
                  label,
                  style: AppStyles.label(
                    10,
                    weight: AppStyles.bold,
                    color: AppColors.neutral100,
                    lineHeight: 16 / 10,
                  ),
                ),
              ),
            if (progress case final p?)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 4.s,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: p.clamp(0, 1),
                      child: const ColoredBox(color: AppColors.brandPrimary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.row});

  final ContentListRow row;

  @override
  Widget build(BuildContext context) {
    final muted = AppStyles.label(
      12,
      weight: AppStyles.bold,
      color: AppColors.neutral500,
      lineHeight: 16 / 12,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          row.title,
          maxLines: row.titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.label(
            14,
            weight: AppStyles.bold,
            lineHeight: 20 / 14,
          ),
        ),
        SizedBox(height: 4.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Avatar(size: 14.s),
            SizedBox(width: 4.s),
            Flexible(
              child: Text(
                row.creatorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.body(
                  12,
                  weight: AppStyles.regular,
                  color: AppColors.neutral200,
                  lineHeight: 16 / 12,
                ),
              ),
            ),
            if (row.creatorVerified) ...[
              SizedBox(width: 4.s),
              DesignIcon(AppAssets.iconFeedVerified, width: 14.s, height: 14.s),
            ],
          ],
        ),
        SizedBox(height: 4.s),
        if (row._isEvent) ...[
          if (row.eventDate case final date?)
            Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          if (row.eventVenue != null || row.eventTime != null) ...[
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
                if (row.eventVenue case final where?)
                  Flexible(
                    child: Text(
                      where,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ),
                if (row.eventTime case final at?) ...[
                  SizedBox(width: 6.s),
                  Text('· $at', style: muted),
                ],
              ],
            ),
          ],
        ] else if (row.meta case final line?)
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
      ],
    );
  }
}

/// A placeholder ring. Creator avatars are not resolved from the feed's
/// `avatarKey` anywhere in the app yet, so every row draws the same stand-in.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.buttonSecondaryActive,
        border: Border.all(color: AppColors.purple400, width: size / 16),
      ),
      child: Icon(Icons.person, size: size * 0.6, color: AppColors.neutral400),
    );
  }
}
