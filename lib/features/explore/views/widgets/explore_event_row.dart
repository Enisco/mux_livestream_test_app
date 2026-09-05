import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/explore/views/widgets/card_bits.dart';
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// An upcoming event: a date tile beside the host, the event's name, and where
/// and when it happens.
class ExploreEventRow extends StatelessWidget {
  const ExploreEventRow({super.key, required this.event, this.onTap});

  static const double width = 222;

  final ExploreEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width.s,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (event.sponsored) ...[
              const ExploreSponsoredTag(),
              SizedBox(height: 8.s),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DateTile(day: event.day, month: event.month),
                SizedBox(width: 10.s),
                Expanded(child: _Details(event: event)),
              ],
            ),
          ],
        ),
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

class _Details extends StatelessWidget {
  const _Details({required this.event});

  final ExploreEvent event;

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
        Row(
          children: [
            ExploreAvatar(creator: event.creator, size: 12.s, ringWidth: 1),
            SizedBox(width: 4.s),
            Flexible(
              child: Text(
                event.creator.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.body(
                  12,
                  color: AppColors.neutral400,
                  lineHeight: 16 / 12,
                ),
              ),
            ),
            if (event.creator.verified) ...[
              SizedBox(width: 4.s),
              DesignIcon(AppAssets.iconFeedVerified, width: 16.s, height: 16.s),
            ],
          ],
        ),
        SizedBox(height: 4.s),
        Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.heading(14, lineHeight: 20 / 14),
        ),
        SizedBox(height: 7.s),
        Row(
          children: [
            DesignIcon(
              AppAssets.iconPin,
              width: 16.s,
              height: 16.s,
              color: AppColors.neutral500,
            ),
            SizedBox(width: 2.s),
            Flexible(child: Text(event.venue, maxLines: 1, style: muted)),
            SizedBox(width: 6.s),
            Text('·', style: muted),
            SizedBox(width: 6.s),
            Text(event.time, style: muted),
          ],
        ),
      ],
    );
  }
}
