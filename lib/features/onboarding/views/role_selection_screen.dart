import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/onboarding/views/widgets/onboarding_option_card.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

enum OnboardingIntent { watch, ministry }

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, this.name});

  final String? name;

  String _firstName() {
    final provided = name?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return LocalStorage.cachedFirstName ?? '';
  }

  Future<void> _choose(BuildContext context, OnboardingIntent intent) async {
    await LocalStorage.setString(LocalStorage.onboardingIntentKey, intent.name);
    if (!context.mounted) return;
    switch (intent) {
      case OnboardingIntent.watch:
        context.go(AppRouter.interests);
      case OnboardingIntent.ministry:
        context.go(AppRouter.creatorType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _firstName();
    return OnboardingScaffold(
      backgroundColor: AppColors.brandSecondary,
      centerContent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: GTubeLogoMark.compact()),
          const SizedBox(height: 8),
          Text(
            '${AppStrings.roleQuestionPrefix}$first,\n'
            '${AppStrings.roleQuestionSuffix}',
            textAlign: TextAlign.center,
            style: AppStyles.heading(20, letterSpacing: -0.8),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.roleSubtitle,
            textAlign: TextAlign.center,
            style: AppStyles.body(13),
          ),
          const SizedBox(height: 40),
          OnboardingOptionCard(
            icon: AppAssets.iconPlayOutline,
            label: AppStrings.roleWatch,
            onTap: () => _choose(context, OnboardingIntent.watch),
          ),
          const SizedBox(height: 10),
          OnboardingOptionCard(
            icon: AppAssets.iconVideoCamera,
            label: AppStrings.roleMinistry,
            onTap: () => _choose(context, OnboardingIntent.ministry),
          ),
        ],
      ),
    );
  }
}
