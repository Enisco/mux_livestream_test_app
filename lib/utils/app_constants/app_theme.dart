import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData.dark().copyWith(
    // Everything falls back to Satoshi, including the legacy screens whose
    // styles predate AppStyles and set no family of their own. The emoji
    // fallback rides along so text that never goes through AppStyles — Material
    // widgets, plain Text — can still render emoji.
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: AppStyles.primaryFont,
      fontFamilyFallback: AppStyles.emojiFallback,
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primary,
      onPrimary: Colors.black,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.black,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.primary,
      thumbColor: AppColors.primary,
      overlayColor: AppColors.primary.withValues(alpha: 0.2),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    ),
  );
}
