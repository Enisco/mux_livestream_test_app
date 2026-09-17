import 'package:flutter/material.dart';

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
            // The incoming minimums are the parent's, and on a viewport
            // taller than 2.6:1 the scaled plate is shorter than that
            // minimum — which is a non-normalized constraint, not a small
            // gap. Loosening both ends lets the plate be whatever size the
            // crop needs.
            minWidth: 0,
            minHeight: 0,
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
