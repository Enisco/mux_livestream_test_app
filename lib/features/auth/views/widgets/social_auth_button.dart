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
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;

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
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(icon, width: _iconSize, height: _iconSize),
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
