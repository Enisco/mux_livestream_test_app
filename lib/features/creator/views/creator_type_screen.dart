import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/onboarding/views/widgets/onboarding_option_card.dart';
import 'package:test_app/features/onboarding/views/widgets/onboarding_progress_bar.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

enum CreatorType {
  individual,
  organization;

  String get value => name;
}

class CreatorTypeScreen extends StatelessWidget {
  const CreatorTypeScreen({super.key});

  static const _progress = 52 / 350;

  Future<void> _choose(BuildContext context, CreatorType type) async {
    await LocalStorage.setString(LocalStorage.creatorTypeKey, type.value);
    if (!context.mounted) return;
    switch (type) {
      case CreatorType.individual:
        context.go(AppRouter.creatorSetup);
      case CreatorType.organization:
        context.go(AppRouter.orgSetup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundColor: AppColors.brandSecondary,
      topBar: _TopBar(
        progress: _progress,
        onSkip: () => context.go(AppRouter.home),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: GTubeLogoMark.compact()),
          const SizedBox(height: 8),
          Text(
            AppStrings.creatorTypeTitle,
            textAlign: TextAlign.center,
            style: AppStyles.heading(20, letterSpacing: -0.8),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.creatorTypeSubtitle,
            textAlign: TextAlign.center,
            style: AppStyles.body(13),
          ),
          const SizedBox(height: 40),
          OnboardingOptionCard(
            icon: AppAssets.iconPerson,
            label: AppStrings.creatorTypeIndividual,
            onTap: () => _choose(context, CreatorType.individual),
          ),
          const SizedBox(height: 10),
          OnboardingOptionCard(
            icon: AppAssets.iconOrganization,
            label: AppStrings.creatorTypeOrganization,
            onTap: () => _choose(context, CreatorType.organization),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.progress, required this.onSkip});

  final double progress;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingProgressBar(progress: progress),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.pop(),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: SvgPicture.asset(
                      AppAssets.iconArrowLeft,
                      width: 20,
                      height: 10,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSkip,
                child: Text(
                  AppStrings.skip,
                  style: AppStyles.caption(
                    12,
                    color: AppColors.neutral50,
                    weight: AppStyles.medium,
                    lineHeight: 16 / 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
