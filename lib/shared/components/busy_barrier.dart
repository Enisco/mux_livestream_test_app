import 'dart:async';

import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Runs [work] behind a barrier that explains the wait and swallows taps.
Future<T> runBusy<T>(
  BuildContext context,
  Future<T> Function() work, {
  required String message,
}) async {
  if (!context.mounted) return work();
  final navigator = Navigator.of(context, rootNavigator: true);
  var showing = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.overlayDark,
      builder: (_) => PopScope(
        // Backing out would leave the request running and the screen about to
        // change under a creator who thinks they cancelled.
        canPop: false,
        // A dialog route carries no Material of its own, and a Text without
        // one above it renders in the debug fallback style.
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.base2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    style: AppStyles.body(13, color: AppColors.neutral300),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) => showing = false),
  );
  try {
    return await work();
  } finally {
    if (showing && navigator.canPop()) navigator.pop();
  }
}
