import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:test_app/shared/components/onboarding_background.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

///
/// Regions are pinned by role, not by position: [topBar] sits under the status
/// bar, [footer] above the home indicator, and [child] takes whatever is left
/// and scrolls if it doesn't fit. Nothing is derived from the design frame's
/// height, so a short device tightens the middle instead of pushing the top bar
/// down the screen.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    this.topBar,
    this.footer,
    this.backgroundAsset,
    this.backgroundColor,
    this.gradient,
    this.horizontalPadding = 20,
    this.topGap = 5,
    this.contentGap = 12,
    this.footerGap = 16,
    this.bottomGap = 16,
    this.scrollable = true,
    this.centerContent = false,
  });

  final Widget child;
  final Widget? topBar;
  final Widget? footer;
  final String? backgroundAsset;
  final Color? backgroundColor;
  final Gradient? gradient;

  final double horizontalPadding;

  final double topGap;

  final double contentGap;

  final double footerGap;

  final double bottomGap;

  /// Scrolls [child] when it overflows. Turn off for screens that manage their
  /// own scrolling.
  ///
  /// While this is on, [child] is laid out with an unbounded height, so it must
  /// not contain an [Expanded], [Flexible] or [Spacer] on the vertical axis —
  /// that combination throws. A screen that pins a header and scrolls a list
  /// below it wants `scrollable: false` and its own scroll view inside.
  final bool scrollable;

  /// Centres [child] in the space left over, for short screens like the
  /// password reset form.
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(horizontal: horizontalPadding);

    // Centred content still has to scroll when it outgrows the viewport, so the
    // scroll view's own height becomes the minimum for a centring box rather
    // than a position to place things at.
    final Widget content = centerContent
        ? LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(child: child),
              ),
            ),
          )
        : scrollable
        ? SingleChildScrollView(padding: padding, child: child)
        : Padding(padding: padding, child: child);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: backgroundColor ?? AppColors.base1,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: Stack(
            children: [
              if (backgroundAsset case final asset?)
                Positioned.fill(child: OnboardingBackground(asset: asset)),
              SafeArea(
                child: Column(
                  children: [
                    if (topBar case final bar?) ...[
                      SizedBox(height: topGap),
                      Padding(padding: padding, child: bar),
                      SizedBox(height: contentGap),
                    ],
                    Expanded(child: content),
                    if (footer case final foot?) ...[
                      SizedBox(height: footerGap),
                      Padding(padding: padding, child: foot),
                    ],
                    SizedBox(height: bottomGap),
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
