import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum Gender {
  male('male', AppStrings.genderMale),
  female('female', AppStrings.genderFemale),
  other('other', AppStrings.genderOther);

  const Gender(this.value, this.label);

  final String value;
  final String label;
}

/// Bottom sheet behind "Gender (optional)"
class GenderPickerSheet extends StatelessWidget {
  const GenderPickerSheet({super.key});

  static Future<Gender?> show(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const GenderPickerSheet(),
  );

  static const _height = 236.0;
  static const _cornerRadius = 24.0;
  static const _handleWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: const BoxDecoration(
        color: AppColors.base1,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_cornerRadius),
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: _handleWidth,
                height: 3,
                child: ColoredBox(color: AppColors.neutral400),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 51,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.selectAGender,
                  style: AppStyles.body(16, color: AppColors.neutral400),
                ),
                const SizedBox(height: 24),
                for (final gender in Gender.values) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(gender),
                    child: Text(
                      gender.label,
                      style: AppStyles.label(16, weight: AppStyles.bold),
                    ),
                  ),
                  if (gender != Gender.values.last) const SizedBox(height: 15),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
