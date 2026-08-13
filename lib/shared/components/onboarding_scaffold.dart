import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:test_app/shared/components/onboarding_background.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

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

  /// Off for screens with a vertical Expanded/Flexible child: while on, the
  /// child is laid out unbounded and a flex child throws.
  final bool scrollable;

  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(horizontal: horizontalPadding);

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
