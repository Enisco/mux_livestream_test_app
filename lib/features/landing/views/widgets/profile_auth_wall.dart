import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What signing in buys, as the You tab pitches it to a reader who has not.
const _authWallFeatures = <(IconData, String)>[
  (IconsaxPlusBold.heart, AppStrings.authWallFollow),
  (IconsaxPlusBold.save_2, AppStrings.authWallSave),
  (Icons.auto_awesome_rounded, AppStrings.authWallRecommend),
  (IconsaxPlusBold.video, AppStrings.authWallGoLive),
];

/// The You tab while the app is still deciding whether anyone is signed in.
class ProfileTabLoading extends StatelessWidget {
  const ProfileTabLoading({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.base1,
    body: Center(
      child: CircularProgressIndicator(
        color: AppColors.brandPrimary,
        strokeWidth: 2,
      ),
    ),
  );
}

/// The You tab for a reader who has not signed in: what an account is for,
/// and the two ways to get one.
class ProfileAuthWall extends StatelessWidget {
  const ProfileAuthWall({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('auth-wall'),
      backgroundColor: AppColors.base1,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHero(),
              Padding(
                padding: EdgeInsets.fromLTRB(28.s, 4.s, 28.s, 48.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.authWallTitle,
                      textAlign: TextAlign.center,
                      style: AppStyles.heading(24, letterSpacing: 0.3),
                    ),
                    SizedBox(height: 10.s),
                    Text(
                      AppStrings.authWallSubtitle,
                      textAlign: TextAlign.center,
                      style: AppStyles.body(
                        14,
                        color: AppColors.neutral400,
                        lineHeight: 1.55,
                      ),
                    ),
                    SizedBox(height: 32.s),
                    for (final (icon, label) in _authWallFeatures)
                      Padding(
                        padding: EdgeInsets.only(bottom: 14.s),
                        child: Row(
                          children: [
                            Container(
                              width: 36.s,
                              height: 36.s,
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10.s),
                              ),
                              child: Icon(
                                icon,
                                color: AppColors.brandPrimary,
                                size: 18.s,
                              ),
                            ),
                            SizedBox(width: 14.s),
                            Expanded(
                              child: Text(label, style: AppStyles.label(14)),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 18.s),
                    PrimaryButton(
                      label: AppStrings.signIn,
                      height: 52.s,
                      labelStyle: AppStyles.button(
                        16,
                        weight: AppStyles.semiBold,
                      ),
                      onPressed: () => context.push(AppRouter.signIn),
                    ),
                    SizedBox(height: 12.s),
                    OutlinedButton(
                      onPressed: () => context.push(AppRouter.welcome),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: Size(double.infinity, 52.s),
                        side: BorderSide(
                          color: AppColors.buttonSecondaryActive,
                          width: 1.5.s,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PrimaryButton.radius.s,
                          ),
                        ),
                      ),
                      child: Text(
                        AppStrings.createAccount,
                        style: AppStyles.button(15, weight: AppStyles.medium),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The brand mark over its own glow, which is what the rest of the new
  /// design puts at the top of an unauthenticated screen.
  Widget _buildHero() {
    return SizedBox(
      height: 260.s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.1),
                radius: 0.75,
                colors: [
                  AppColors.brandPrimary.withValues(alpha: 0.18),
                  AppColors.base1,
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          GTubeLogoMark(scale: 1.4.s),
        ],
      ),
    );
  }
}
