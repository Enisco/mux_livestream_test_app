import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;

  /// The provider's own sheet is open, or its answer is being exchanged at
  /// the gateway. The glyph becomes a spinner in place rather than beside
  /// the label, so the row keeps its height and its centring, and the
  /// button stops taking taps — a second one would open a second sheet.
  final bool busy;

  static const _radius = 10.0;
  static const _padding = 16.0;
  static const _iconSize = 20.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.buttonSecondaryActive,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: busy
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.neutral300,
                      )
                    : SvgPicture.asset(
                        icon,
                        width: _iconSize,
                        height: _iconSize,
                      ),
              ),
              const SizedBox(width: _gap),
              Text(
                label,
                style: AppStyles.button(14, weight: AppStyles.medium),
              ),
              const SizedBox(width: _gap + _iconSize),
            ],
          ),
        ),
      ),
    );
  }
}
