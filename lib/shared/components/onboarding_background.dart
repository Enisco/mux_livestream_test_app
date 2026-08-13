import 'package:flutter/material.dart';

/// Full-bleed onboarding backdrop. The design centres a 1801.71 x 1014 plate on
/// a 390-wide frame, so only its middle band shows; the plate scales with the
/// screen to keep that crop identical on every device.
class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({super.key, required this.asset});

  final String asset;

  static const _designWidth = 390.0;
  static const _plateWidth = 1801.71;
  static const _plateHeight = 1014.001;
  static const _plateAspect = _plateWidth / _plateHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * (_plateWidth / _designWidth);
        return ClipRect(
          child: OverflowBox(
            maxWidth: width,
            maxHeight: width / _plateAspect,
            child: Image.asset(
              asset,
              width: width,
              height: width / _plateAspect,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}
