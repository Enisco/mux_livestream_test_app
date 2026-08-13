import 'package:flutter/material.dart';

import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Picker behind "What do you mostly share?". Follows the gender sheet's
/// design; options come from `GET /v1/user/categories`.
class CategoryPickerSheet extends StatelessWidget {
  const CategoryPickerSheet({super.key, required this.categories});

  final List<ContentCategory> categories;

  static Future<ContentCategory?> show(
    BuildContext context,
    List<ContentCategory> categories,
  ) => showModalBottomSheet<ContentCategory>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => CategoryPickerSheet(categories: categories),
  );

  static const _cornerRadius = 24.0;
  static const _handleWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.base1,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_cornerRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          const SizedBox(
            width: _handleWidth,
            height: 3,
            child: ColoredBox(color: AppColors.neutral400),
          ),
          const SizedBox(height: 34),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                AppStrings.selectACategory,
                style: AppStyles.body(16, color: AppColors.neutral400),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 15),
              itemBuilder: (context, index) {
                final category = categories[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(category),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      category.name,
                      style: AppStyles.label(16, weight: AppStyles.bold),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
