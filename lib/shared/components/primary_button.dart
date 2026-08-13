import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Gradient pill with `Drop Shadow/300`. Disabled is a `Grey/300` fill at 57%
/// opacity.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.labelStyle,
    this.height,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;
  final bool enabled;
  final TextStyle? labelStyle;
  final double? height;

  static const radius = 22.0;
  static const _horizontalPadding = 24.0;
  static const _verticalPadding = 13.0;
  static const _disabledOpacity = 0.57;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: enabled
            ? const BoxDecoration(gradient: AppStyles.primaryButtonGradient)
            : const BoxDecoration(color: AppColors.grey300),
        child: InkWell(
          onTap: active ? onPressed : null,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: _verticalPadding,
            ),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    height: 20.s,
                    width: 20.s,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5.s,
                      color: AppColors.textPrimary,
                    ),
                  )
                : Text(
                    label,
                    style:
                        labelStyle ?? AppStyles.button(13, lineHeight: 28 / 13),
                  ),
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppStyles.primaryButtonShadow,
      ),
      child: enabled
          ? button
          : Opacity(opacity: _disabledOpacity, child: button),
    );
  }
}
