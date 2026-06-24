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

  // Video-format badge palette – all warm/amber-adjacent, no cool blues or purples
  static const fmtMp4 = Color(0xFFF59300); // amber (primary)
  static const fmtMkv = Color(0xFFD4950A); // dark golden
  static const fmtAvi = Color(0xFFE07A5F); // warm coral / terracotta
  static const fmtMov = Color(0xFFA68A6E); // warm tan
  static const fmtWebm = Color(0xFFF5CA5D); // light off-white gold
  static const fmtDefault = primary;
}
