import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';

class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({super.key, required this.progress});

  final double progress;

  static const _height = 2.0;
  static const _trackRadius = 6.0;
  static const _fillRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_trackRadius),
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppColors.textPrimary),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(_fillRadius),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
