import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary – slightly deep amber
  static const primary = Color(0xFFF59300);
  static const primaryDark = Color(0xFFCC7700);
  static const primaryLight = Color(0xFFFFBC42);

  // Backgrounds
  static const background = Color(0xFF0E0E1A);
  static const surface = Color(0xFF1C1C2E);
  static const surfaceVariant = Color(0xFF252538);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0C4);
  static const textTertiary = Color(0xFF666680);

  // Semantic
  static const error = Color(0xFFE74C3C);

  // Overlay shades
  static const overlayDark = Color(0xBB000000);
  static const overlayMid = Color(0x80000000);
  static const overlayLight = Color(0x33000000);

  // ── Design-system tokens ───────────────────────────────────────────────────
  // The legacy constants above stay until the screens using them are redesigned.

  /// Brand primary.
  static const brandPrimary = Color(0xFFFFA500);

  /// The base canvas behind the onboarding flow.
  static const base1 = Color(0xFF0D0D0D);

  /// Secondary/supporting copy.
  static const neutral200 = Color(0xFFE5E5E5);

  /// The "Skip" affordance.
  static const neutral50 = Color(0xFFFAFAFA);

  /// Subheading copy.
  static const neutral300 = Color(0xFFD4D4D4);

  /// Placeholder and helper copy.
  static const neutral400 = Color(0xFFA1A1A1);

  /// Hairline borders.
  static const neutral700 = Color(0xFF404040);

  /// Grey button fill.
  static const buttonSecondaryActive = Color(0xFF313131);

  /// Input field fill.
  static const brandAltDark = Color(0xFF313131);

  /// End stop of the primary button gradient (starts at [brandPrimary]).
  static const brandPrimaryDeep = Color(0xFFCC6B00);

  /// Empty OTP slot placeholder.
  static const textMuted = Color(0xFF6A6A6A);

  /// Disabled primary button (rendered at 57% opacity).
  static const grey300 = Color(0xFFD0D5DD);

  /// Inner glow on the OTP mail badge.
  static const badgeInnerGlow = Color(0x1A737373);

  /// Handle-available confirmation.
  static const green500 = Color(0xFF00C951);

  /// Softer gold used for the brand name in the welcome-note typewriter.
  static const brandGold = Color(0xFFEDB021);

  /// Flat canvas on the role-selection screens.
  static const brandSecondary = Color(0xFF0D0D0D);

  /// Bottom-sheet row fill.
  static const base2 = Color(0xFF0E0E0E);

  /// Selectable option card fill.
  static const brandTertiary = Color(0xFF0E0E0E);

  /// Plan card border.
  static const neutral900 = Color(0xFF171717);

  /// Status pill fill.
  static const fieldBg = Color(0xFF151515);

  /// "RECOMMENDED" label.
  static const green600 = Color(0xFF00A63E);

  /// Comparison-table row divider.
  static const tableBorder = Color(0xFF1F1F24);

  /// "Most popular" badge.
  static const cyan500 = Color(0xFF00B8DB);

  /// Inner glow on pills.
  static const brandAccentLow = Color(0xFFFFDB99);

  /// End stop of the billing-toggle gradient.
  static const brandPrimaryMid = Color(0xFFE57F00);

  /// Option card border.
  static const neutral800 = Color(0xFF262626);

  // Welcome feature-card gradients (top-left → bottom-right, stop at 70.711%).
  static const cardPurpleFrom = Color(0xFF64618E);
  static const cardPurpleTo = Color(0xFF2A2754);
  static const cardRedFrom = Color(0xFFA25C61);
  static const cardRedTo = Color(0xFF682227);
  static const cardOliveFrom = Color(0xFF897E51);
  static const cardOliveTo = Color(0xFF4F4417);
  static const cardGreenFrom = Color(0xFF516959);
  static const cardGreenTo = Color(0xFF172F1F);

  /// Live badge fill on the welcome carousel.
  static const liveBadge = Color(0xFFFF3B30);

  /// Inactive home tab labels and the separator dot.
  static const neutral500 = Color(0xFF737373);

  /// Duration pill text.
  static const neutral100 = Color(0xFFF5F5F5);

  /// Verified-creator avatar ring.
  static const purple400 = Color(0xFFC27AFF);

  /// Off white.
  static const offWhite = Color(0xFFFBFBFB);

  // Splash background gradient stops (top → bottom).
  static const splashGradientTop = Color(0xFF313131);
  static const splashGradientMid = Color(0xFF151515);

  // Logo-mark glow, layered top-to-bottom.
  static const logoGlowOuter = Color(0x1AF8F8FF);
  static const logoGlowInner = Color(0x0DFAFAFF);

  // Video-format badge palette – all warm/amber-adjacent, no cool blues or purples
  static const fmtMp4 = Color(0xFFF59300); // amber (primary)
  static const fmtMkv = Color(0xFFD4950A); // dark golden
  static const fmtAvi = Color(0xFFE07A5F); // warm coral / terracotta
  static const fmtMov = Color(0xFFA68A6E); // warm tan
  static const fmtWebm = Color(0xFFF5CA5D); // light off-white gold
  static const fmtDefault = primary;
}
