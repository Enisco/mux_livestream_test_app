import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The wrapping grid of topic pills.
///
/// Explore and search both draw it, under headings of their own, so the grid
/// carries no title — each screen supplies the heading its design asks for.
class CategoryChipGrid extends StatelessWidget {
  const CategoryChipGrid({
    super.key,
    required this.categories,
    this.onSelected,
  });

  final List<ExploreCategory> categories;
  final ValueChanged<ExploreCategory>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.s,
      runSpacing: 12.s,
      children: [
        for (final c in categories)
          _Chip(category: c, onTap: () => onSelected?.call(c)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.category, this.onTap});

  final ExploreCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(999.s),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: category.icon,
              color: AppColors.chipText,
              size: 18.s,
            ),
            SizedBox(width: 10.s),
            Text(
              category.label,
              style: AppStyles.label(
                13,
                family: AppStyles.featureFont,
                weight: AppStyles.semiBold,
                color: AppColors.chipText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
