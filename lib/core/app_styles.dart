import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppStyles {
  // App bar
  static const appBarTitle = TextStyle(
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );
  static const fileCount = TextStyle(
    fontSize: 13,
    color: AppColors.textTertiary,
  );

  // Home – video card
  static const videoTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const videoPath = TextStyle(
    fontSize: 11,
    color: AppColors.textTertiary,
  );
  static const extBadge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  // Home – empty state
  static const emptyTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const emptySubtitle = TextStyle(
    fontSize: 14,
    color: AppColors.textTertiary,
  );

  // Player
  static const playerTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
  );
  static const timeLabel = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  static const timeLabelDim = TextStyle(
    fontSize: 12,
    color: AppColors.textTertiary,
  );
  static const speedLabel = TextStyle(fontSize: 12);
  static const speedMenuItem = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );
  static const loadingLabel = TextStyle(color: AppColors.textSecondary);
  static const errorTitle = TextStyle(
    fontSize: 18,
    color: AppColors.textPrimary,
  );
  static const errorPath = TextStyle(
    fontSize: 12,
    color: AppColors.textTertiary,
  );

  // Landing screen
  static const landingCardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const landingCardDesc = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  // Stream credentials
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
  static const streamStatusBadge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
  );
}
