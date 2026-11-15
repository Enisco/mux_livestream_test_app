import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Side inset for everything on Explore that is not a scrolling rail.
const double kExploreGutter = 20;

/// Vertical space between one section and the next.
const double kExploreSectionGap = 24;

/// A section's title and its "see all" chevron.
class ExploreSectionHeader extends StatelessWidget {
  const ExploreSectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSeeAll,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: kExploreGutter.s),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(
                  14,
                  weight: AppStyles.bold,
                  lineHeight: 20 / 14,
                ),
              ),
            ),
            // No chevron where there is nowhere to go: Trending and
            // Continue watching are orderings rather than kinds, so no type
            // tab means either of them.
            if (onSeeAll != null) ...[
              SizedBox(width: 8.s),
              Icon(
                AppIcons.chevronRight,
                size: 16.s,
                color: AppColors.textPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A header above a horizontally scrolling row of cards.
class ExploreRail extends StatelessWidget {
  const ExploreRail({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
    this.gap = 16,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onSeeAll;
  final double gap;

  /// Events hang from the bottom of the rail; every other card sits at the top.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExploreSectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(height: 12.s),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: kExploreGutter.s),
          child: Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (var i = 0; i < itemCount; i++) ...[
                if (i > 0) SizedBox(width: gap.s),
                itemBuilder(context, i),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
