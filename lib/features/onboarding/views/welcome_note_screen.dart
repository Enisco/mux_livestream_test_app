import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/shared/components/typing_text.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Typewriter greeting on the way into onboarding. No controls: the copy types
/// itself out, holds, then continues to [nextRoute] (role selection by default).
class WelcomeNoteScreen extends StatefulWidget {
  const WelcomeNoteScreen({super.key, this.name, this.nextRoute});

  /// First name shown in the greeting. Falls back to the cached user.
  final String? name;
  final String? nextRoute;

  @override
  State<WelcomeNoteScreen> createState() => _WelcomeNoteScreenState();
}

class _WelcomeNoteScreenState extends State<WelcomeNoteScreen> {
  Timer? _holdTimer;

  /// The design timeline runs 5.24s; typing ends around 2.5s, so the remainder
  /// is a deliberate hold before the flow moves on.
  static const _holdAfterTyping = Duration(milliseconds: 2700);

  String get _firstName {
    final provided = widget.name?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return getIt<AuthRepo>().getCachedUser()?.firstName ?? '';
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onTypingDone() {
    _holdTimer = Timer(_holdAfterTyping, () {
      if (!mounted) return;
      context.go(widget.nextRoute ?? AppRouter.roleSelection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _firstName;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppStyles.splashBackground),
          child: SafeArea(
            // The greeting is the whole screen — centre it rather than pinning
            // it to a design-frame offset.
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 43),
                child: TypingText(
                  onCompleted: _onTypingDone,
                  lines: [
                    TypingLine([
                      TypingSpan(
                        '${AppStrings.welcomeNoteGreeting}$name,',
                        AppStyles.heading(
                          24,
                          family: AppStyles.featureFont,
                          weight: AppStyles.bold,
                        ),
                      ),
                    ]),
                    TypingLine([
                      TypingSpan(
                        AppStrings.welcomeNoteWelcome,
                        AppStyles.heading(
                          24,
                          family: AppStyles.featureFont,
                          weight: AppStyles.bold,
                        ),
                      ),
                      TypingSpan(
                        AppStrings.brandName,
                        AppStyles.heading(
                          24,
                          family: AppStyles.featureFont,
                          color: AppColors.brandGold,
                          weight: AppStyles.bold,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
