import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  static const _radius = 8.0;
  static const _borderWidth = 2.0;
  static const _horizontalPadding = 14.0;
  static const _verticalPadding = 16.0;
  static const _iconBoxPadding = 8.0;
  static const _iconSize = 20.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandTertiary,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: AppColors.neutral800,
              width: _borderWidth,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: _verticalPadding,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(_iconBoxPadding),
                child: SvgPicture.asset(
                  icon,
                  width: _iconSize,
                  height: _iconSize,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Text(
                  label,
                  style: AppStyles.label(
                    14,
                    weight: AppStyles.bold,
                    lineHeight: 20 / 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
