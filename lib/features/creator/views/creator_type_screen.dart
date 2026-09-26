import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/models/onboarding_models/onboarding_state.dart';
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

/// Who the channel is for.
///
/// The answer decides which setup form comes next and, later, whether the
/// studio has one owner or a team, so it is asked before anything is typed.
class CreatorTypeScreen extends StatelessWidget {
  const CreatorTypeScreen({super.key});

  Future<void> _choose(BuildContext context, CreatorType type) async {
    await LocalStorage.setString(LocalStorage.creatorTypeKey, type.value);
    recordOnboardingState(
      step: OnboardingStep.creatorProfileType,
      creatorType: type == CreatorType.individual
          ? OnboardingCreatorType.individual
          : OnboardingCreatorType.organization,
    );
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
      topBar: CreatorFlowHeader(
        title: AppStrings.creatorTypeTitle,
        subtitle: AppStrings.creatorTypeSubtitle,
        onBack: () => context.pop(),
      ),
      // The footnote answers the question the two cards raise — whether this
      // replaces the account they already watch with.
      footer: Text(
        AppStrings.creatorTypeFootnote,
        textAlign: TextAlign.center,
        style: AppStyles.body(
          12,
          color: AppColors.neutral400,
          lineHeight: 17 / 12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          CreatorChoiceCard(
            icon: AppAssets.iconPerson,
            title: AppStrings.creatorTypeIndividual,
            body: AppStrings.creatorTypeIndividualBody,
            onTap: () => _choose(context, CreatorType.individual),
          ),
          const SizedBox(height: 14),
          CreatorChoiceCard(
            icon: AppAssets.iconOrganization,
            title: AppStrings.creatorTypeOrganization,
            body: AppStrings.creatorTypeOrganizationBody,
            onTap: () => _choose(context, CreatorType.organization),
          ),
        ],
      ),
    );
  }
}
