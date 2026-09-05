import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Side inset for everything on Explore that is not a scrolling rail.
///
/// The design draws section content at 18 and the search field at 20; 20 wins
/// so the field, the headers and the chips share one edge.
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
            SizedBox(width: 8.s),
            Icon(
              AppIcons.chevronRight,
              size: 16.s,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A header above a horizontally scrolling row of cards.
///
/// The row is laid out with the gutter as its padding rather than the
/// section's, so cards scroll past the screen edge instead of stopping short
/// of it — that overflow is what tells the reader there is more to the right.
///
/// It takes its height from the tallest card rather than being told one. An
/// earlier version passed a fixed height worked out from the design, which
/// overflowed the moment a card grew by a pixel — a sponsored badge, a font
/// metric, a longer count. A rail holds a handful of cards, so building them
/// all is cheaper than being wrong about how tall they are.
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
