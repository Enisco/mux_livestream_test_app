import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/views/widgets/feature_card_carousel.dart';
import 'package:test_app/features/auth/views/widgets/social_auth_button.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_background.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _actionsInset = 20.0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppStyles.splashBackground),
          child: Stack(
            children: [
              const Positioned.fill(
                child: OnboardingBackground(asset: AppAssets.onboardingBg),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const _Header(),
                    const Expanded(child: Center(child: FeatureCardCarousel())),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: _actionsInset),
                      child: _Actions(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GTubeLogoMark.plain(),
        SizedBox(height: 7),
        Text(
          AppStrings.welcomeTitle,
          style: AppStyles.heading(
            20,
            lineHeight: 32 / 20,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: 3),
        Text(
          AppStrings.welcomeSubtitle,
          style: AppStyles.body(14, color: AppColors.neutral300),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SocialAuthButton(
            icon: AppAssets.iconGoogle,
            label: AppStrings.continueWithGoogle,
            // TODO(auth): wire to the browser handoff OAuth flow
            onPressed: null,
          ),
          const SizedBox(height: 10),
          SocialAuthButton(
            icon: AppAssets.iconApple,
            label: AppStrings.continueWithApple,
            // TODO(auth): wire to Sign in with Apple.
            onPressed: null,
          ),
          const SizedBox(height: 10),
          SocialAuthButton(
            icon: AppAssets.iconMail,
            label: AppStrings.continueWithEmail,
            onPressed: () => context.push(AppRouter.signUp),
          ),
          const SizedBox(height: 23),
          const _BrowseRow(),
          const SizedBox(height: 23),
          const _SignInRow(),
        ],
      ),
    );
  }
}

class _BrowseRow extends StatelessWidget {
  const _BrowseRow();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go(AppRouter.home),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppStrings.justBrowse,
            style: AppStyles.label(
              14,
              color: AppColors.brandPrimary,
              weight: AppStyles.bold,
              lineHeight: 16 / 14,
            ),
          ),
          const SizedBox(width: 6),
          const SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: SvgPicture(_arrowRight, width: 16.667, height: 8.333),
            ),
          ),
        ],
      ),
    );
  }
}

const _arrowRight = SvgAssetLoader(AppAssets.iconArrowRight);

class _SignInRow extends StatelessWidget {
  const _SignInRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppStrings.alreadyHere,
          style: AppStyles.body(14, lineHeight: 16 / 14),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => context.push(AppRouter.signIn),
          child: Text(
            AppStrings.signInLink,
            style: AppStyles.label(
              14,
              color: AppColors.brandPrimary,
              weight: AppStyles.bold,
              lineHeight: 16 / 14,
            ),
          ),
        ),
      ],
    );
  }
}
