import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/auth/views/widgets/auth_flow.dart';
import 'package:test_app/features/auth/views/widgets/feature_card_carousel.dart';
import 'package:test_app/features/auth/views/widgets/social_auth_button.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_background.dart';
import 'package:test_app/shared/services/social_sign_in.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:hugeicons/hugeicons.dart';
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
      child: AuthFlowListener(
        // This page has no error banner of its own — the three buttons are
        // the whole of it — so a refusal is said in a snackbar. A
        // cancellation says nothing: backing out of Apple's sheet is not a
        // thing to be told about.
        onState: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppStyles.splashBackground,
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: OnboardingBackground(asset: AppAssets.onboardingBg),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const _Header(),
                      const Expanded(
                        child: Center(child: FeatureCardCarousel()),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _actionsInset,
                        ),
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
    final bloc = context.read<AuthBloc>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final busy = state is AuthSocialLoading ? state.provider : null;
          final working = state is AuthSocialLoading || state is AuthLoading;

          // A provider the build cannot start is left out rather than
          // greyed out. A dead button beside a live one reads as the live
          // one being broken too — and on Android the Apple button could
          // never work, because Apple's own flow is iOS-only here.
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final provider in SocialProvider.values)
                if (bloc.offers(provider)) ...[
                  SocialAuthButton(
                    key: ValueKey('continue-with-${provider.slug}'),
                    icon: switch (provider) {
                      SocialProvider.google => AppAssets.iconGoogle,
                      SocialProvider.apple => AppAssets.iconApple,
                    },
                    label: switch (provider) {
                      SocialProvider.google => AppStrings.continueWithGoogle,
                      SocialProvider.apple => AppStrings.continueWithApple,
                    },
                    busy: busy == provider,
                    onPressed: working
                        ? null
                        : () => bloc.add(AuthSocialSignInRequested(provider)),
                  ),
                  const SizedBox(height: 10),
                ],
              SocialAuthButton(
                key: const ValueKey('continue-with-email'),
                icon: AppAssets.iconMail,
                label: AppStrings.continueWithEmail,
                onPressed: working
                    ? null
                    : () => context.push(AppRouter.signUp),
              ),
              const SizedBox(height: 23),
              const _BrowseRow(),
              const SizedBox(height: 23),
              const _SignInRow(),
            ],
          );
        },
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
          const HugeIcon(
            icon: AppIcons.forward,
            color: AppColors.brandPrimary,
            size: 16,
          ),
        ],
      ),
    );
  }
}

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
