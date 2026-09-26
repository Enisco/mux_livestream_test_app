import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData.dark().copyWith(
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: AppStyles.primaryFont,
      fontFamilyFallback: AppStyles.emojiFallback,
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brandPrimary,
      secondary: AppColors.brandPrimary,
      onPrimary: Colors.black,
      surface: AppColors.base2,
    ),
    scaffoldBackgroundColor: AppColors.base1,
    cardTheme: CardThemeData(
      color: AppColors.neutral900,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.base1,
      elevation: 0,
      centerTitle: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.brandPrimary,
      foregroundColor: Colors.black,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.brandPrimary,
      thumbColor: AppColors.brandPrimary,
      overlayColor: AppColors.brandPrimary.withValues(alpha: 0.2),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.neutral900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    ),
  );
}
