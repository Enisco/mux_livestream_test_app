import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/explore/views/widgets/explore_rail.dart';
import 'package:test_app/models/explore_models/explore_models.dart';
import 'package:test_app/shared/components/category_chip_grid.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The Browse block on Explore: every topic the catalogue is filed under.
///
/// The pills themselves are [CategoryChipGrid], which search also draws under
/// a heading of its own.
class ExploreCategoryChips extends StatelessWidget {
  const ExploreCategoryChips({
    super.key,
    required this.categories,
    this.onSelected,
  });

  final List<ExploreCategory> categories;
  final ValueChanged<ExploreCategory>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kExploreGutter.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.exploreBrowse,
            style: AppStyles.label(
              14,
              weight: AppStyles.bold,
              lineHeight: 20 / 14,
            ),
          ),
          SizedBox(height: 12.s),
          CategoryChipGrid(categories: categories, onSelected: onSelected),
        ],
      ),
    );
  }
}
