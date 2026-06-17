import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../core/app_styles.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _IconContainer(),
          const SizedBox(height: 24.0),
          Text(AppStrings.noVideosTitle, style: AppStyles.emptyTitle),
          const SizedBox(height: 8.0),
          Text(AppStrings.noVideosSubtitle, style: AppStyles.emptySubtitle),
        ],
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  const _IconContainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100.0,
      height: 100.0,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: const Icon(
        Icons.video_library_rounded,
        size: 48.0,
        color: AppColors.primary,
      ),
    );
  }
}
