import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';

/// Typography and shared visual tokens. Text styles are semantic builders, not
/// one constant per design node: pick the role, pass the size, override only
/// where the design departs from the role's default.
class AppStyles {
  AppStyles._();

  /// UI typeface — the default for every builder below.
  static const String primaryFont = 'Satoshi';

  /// Welcome carousel cards and the welcome-note typewriter. Medium + Bold only.
  static const String featureFont = 'Inter';

  /// One-time-code numerals only, so [display] defaults to it. Medium only.
  static const String numeralFont = 'Red Hat Text';

  // Satoshi ships Light/Regular/Medium/Bold/Black. `semiBold` has no matching
  // file, so Flutter renders it from the nearest weight.
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight black = FontWeight.w900;

  // ── Text styles ────────────────────────────────────────────────────────────

  static TextStyle heading(
    double size, {
    String? family,
    Color? color,
    FontWeight weight = black,
    double? lineHeight,
    double? letterSpacing,
  }) => _base(
    fontSize: size,
    fontFamily: family,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
  );

  static TextStyle body(
    double size, {
    String? family,
    Color? color,
    FontWeight weight = medium,
    double? lineHeight,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) => _base(
    fontSize: size,
    fontFamily: family,
    fontWeight: weight,
    color: color ?? AppColors.neutral200,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );

  static TextStyle label(
    double size, {
    String? family,
    Color? color,
    FontWeight weight = medium,
    double? lineHeight,
    double? letterSpacing,
  }) => _base(
    fontSize: size,
    fontFamily: family,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
  );

  static TextStyle caption(
    double size, {
    String? family,
    Color? color,
    FontWeight weight = regular,
    double? lineHeight,
    double? letterSpacing,
  }) => _base(
    fontSize: size,
    fontFamily: family,
    fontWeight: weight,
    color: color ?? AppColors.neutral400,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
  );

  static TextStyle button(
    double size, {
    String? family,
    Color? color,
    FontWeight weight = bold,
    double? lineHeight,
    double? letterSpacing,
  }) => _base(
    fontSize: size,
    fontFamily: family,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
  );

  static TextStyle display(
    double size, {
    String? family,
    Color? color,
    FontWeight weight = medium,
    double? lineHeight,
    double? letterSpacing,
  }) => _base(
    fontSize: size,
    fontFamily: family ?? numeralFont,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
  );

  static TextStyle overline(
    double size, {
    String? family,
    Color? color,
    FontWeight weight = bold,
    double? lineHeight,
    double? letterSpacing,
  }) => _base(
    fontSize: size,
    fontFamily: family,
    fontWeight: weight,
    color: color ?? AppColors.textPrimary,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
  );

  // ── Internal ───────────────────────────────────────────────────────────────

  static TextStyle _base({
    required double fontSize,
    String? fontFamily,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? lineHeight,
    double? letterSpacing,
  }) {
    final resolvedWeight = fontWeight ?? regular;
    return TextStyle(
      fontFamily: fontFamily ?? primaryFont,
      fontSize: fontSize,
      fontWeight: resolvedWeight,
      fontStyle: fontStyle,
      color: color ?? AppColors.textPrimary,
      height: lineHeight,
      letterSpacing: letterSpacing,
      // Drives the variable Inter italic. Undeclared axes are ignored, so this
      // is inert for the static cuts.
      fontVariations: [
        FontVariation('wght', resolvedWeight.value.toDouble()),
        FontVariation('opsz', fontSize.clamp(_opszMin, _opszMax)),
      ],
    );
  }

  static const double _opszMin = 14;
  static const double _opszMax = 32;

  // ── Gradients ──────────────────────────────────────────────────────────────

  /// Background of the onboarding "division Block".
  static const splashBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.splashGradientTop,
      AppColors.splashGradientMid,
      AppColors.base1,
      AppColors.base1,
    ],
    stops: [0.0, 0.40, 0.75, 1.0],
  );

  static const primaryButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.brandPrimary, AppColors.brandPrimaryDeep],
  );

  // ── Shadows ────────────────────────────────────────────────────────────────

  /// Applied to a focused field.
  static const fieldFocusShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color(0x0A070400),
      offset: Offset(0, 10),
      blurRadius: 10,
      spreadRadius: -5,
    ),
  ];

  static const otpSlotShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(0, 12.955),
      blurRadius: 16.193,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color(0x0A070400),
      offset: Offset(0, 6.477),
      blurRadius: 6.477,
      spreadRadius: -5,
    ),
  ];

  /// Applied to the primary CTA.
  static const primaryButtonShadow = [
    BoxShadow(
      color: Color(0x1A0C0C0D),
      offset: Offset(0, 4),
      blurRadius: 4,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x0D0C0C0D),
      offset: Offset(0, 4),
      blurRadius: 4,
      spreadRadius: -1,
    ),
  ];

  /// Used by the compact logo tile and sheets.
  static const logoTileShadow = [
    BoxShadow(
      color: Color(0x1AF8F8FF),
      offset: Offset(0, 16),
      blurRadius: 32,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x0DFAFAFF),
      offset: Offset(0, 4),
      blurRadius: 4,
      spreadRadius: -4,
    ),
  ];

  // ── Legacy ─────────────────────────────────────────────────────────────────
  // For screens not yet rebuilt from the design. Delete each as it migrates.

  static const appBarTitle = TextStyle(
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static const credLabel = TextStyle(
    fontSize: 11,
    color: AppColors.textTertiary,
    letterSpacing: 0.5,
  );

  static const credValue = TextStyle(
    fontSize: 13,
    fontFamily: 'monospace',
    color: AppColors.textPrimary,
  );

  static const emptySubtitle = TextStyle(
    fontSize: 14,
    color: AppColors.textTertiary,
  );

  static const emptyTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const errorPath = TextStyle(
    fontSize: 12,
    color: AppColors.textTertiary,
  );

  static const errorTitle = TextStyle(
    fontSize: 18,
    color: AppColors.textPrimary,
  );

  static const extBadge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  static const fileCount = TextStyle(
    fontSize: 13,
    color: AppColors.textTertiary,
  );

  static const landingCardDesc = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static const landingCardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const loadingLabel = TextStyle(color: AppColors.textSecondary);

  static const playerTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
  );

  static const speedLabel = TextStyle(fontSize: 12);

  static const speedMenuItem = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const streamStatusBadge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
  );

  static const timeLabel = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const timeLabelDim = TextStyle(
    fontSize: 12,
    color: AppColors.textTertiary,
  );

  static const videoPath = TextStyle(
    fontSize: 11,
    color: AppColors.textTertiary,
  );

  static const videoTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
}
