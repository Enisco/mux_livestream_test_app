import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The channel exists. Said plainly, before asking for anything else.
///
/// This is the hinge of the flow: the plan is settled and the studio is real,
/// so everything after it is optional polish the reader can walk away from.
class CreatorLiveScreen extends StatelessWidget {
  const CreatorLiveScreen({super.key});

  /// The channel name the setup form saved, falling back to nothing rather
  /// than to a placeholder — a greeting with the wrong name is worse than a
  /// greeting with none.
  static String? _firstName() {
    final saved = LocalStorage.getString(LocalStorage.creatorNameKey)?.trim();
    if (saved == null || saved.isEmpty) return null;
    return saved.split(RegExp(r'\s+')).last;
  }

  @override
  Widget build(BuildContext context) {
    final name = _firstName();

    return OnboardingScaffold(
      backgroundColor: AppColors.brandSecondary,
      backgroundAsset: AppAssets.worshipBg,
      centerContent: true,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CreatorSkipLine(
            label: AppStrings.creatorDoThisLater,
            // The channel exists by this point; skipping the polish steps
            // should still land in the studio it belongs to.
            onTap: () => context.go(AppRouter.studio),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: AppStrings.creatorLiveSetUp,
            height: 54,
            onPressed: () => context.go(AppRouter.creatorPhoto),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.statusDone,
            ),
            child: const Icon(Icons.check, size: 24, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            name == null
                ? AppStrings.creatorLiveTitlePrefix.replaceAll(',', '')
                : '${AppStrings.creatorLiveTitlePrefix} $name',
            textAlign: TextAlign.center,
            style: AppStyles.heading(20, letterSpacing: -0.6),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: AppStyles.body(
                13,
                color: AppColors.neutral300,
                lineHeight: 18 / 13,
              ),
              children: [
                const TextSpan(text: '${AppStrings.creatorLiveBodyPrefix} '),
                TextSpan(
                  text: AppStrings.creatorLiveBodyBrand,
                  style: AppStyles.body(
                    13,
                    color: AppColors.brandPrimary,
                    lineHeight: 18 / 13,
                  ),
                ),
                const TextSpan(text: AppStrings.creatorLiveBodySuffix),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
