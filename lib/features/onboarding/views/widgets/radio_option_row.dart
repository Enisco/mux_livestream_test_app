import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class RadioOptionRow extends StatelessWidget {
  const RadioOptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _radius = 8.0;
  static const _horizontalPadding = 14.0;
  static const _verticalPadding = 9.0;
  static const _iconBoxPadding = 8.0;
  static const _iconSize = 20.0;
  static const _radioSize = 24.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandAltDark,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: _verticalPadding,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(_iconBoxPadding),
                child: SvgPicture.asset(
                  icon,
                  width: _iconSize,
                  height: _iconSize,
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Text(
                  label,
                  style: AppStyles.label(13, weight: AppStyles.bold),
                ),
              ),
              const SizedBox(width: _gap),
              _Radio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: RadioOptionRow._radioSize,
      height: RadioOptionRow._radioSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            AppAssets.iconRadioButton,
            width: RadioOptionRow._radioSize,
            height: RadioOptionRow._radioSize,
          ),
          if (selected)
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
