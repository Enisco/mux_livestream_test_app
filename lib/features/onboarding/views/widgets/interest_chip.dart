import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Multi-select interest chip. Selecting one swaps its fill to
/// `Button Primary/Active` and replaces the category glyph with a check.
class InterestChip extends StatelessWidget {
  const InterestChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Category glyph shown when unselected. Some chips have none in the design.
  final Widget? icon;

  static const _radius = 12.0;
  static const _borderWidth = 1.5;
  static const _horizontalPadding = 24.0;
  static const _verticalPadding = 12.0;
  static const iconSize = 20.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final leading = selected
        ? SvgPicture.asset(
            AppAssets.iconCheck,
            width: iconSize,
            height: iconSize,
          )
        : icon;

    return Material(
      color: selected ? AppColors.brandPrimary : AppColors.brandAltDark,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: AppColors.neutral700,
              width: _borderWidth,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
            vertical: _verticalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: _gap)],
              Text(label, style: AppStyles.label(13, weight: AppStyles.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Youth & family" glyph — three vector layers laid out by percentage
/// inside a 20x20 box.
class FamilyGlyph extends StatelessWidget {
  const FamilyGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    const size = InterestChip.iconSize;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: size * 0.4062,
            top: size * 0.25,
            right: 0,
            bottom: 0,
            child: SvgPicture.asset(AppAssets.iconCatFamilyA),
          ),
          Positioned(
            left: 0,
            top: size * 0.0028,
            right: size * 0.0625,
            bottom: 0,
            child: SvgPicture.asset(AppAssets.iconCatFamilyB),
          ),
          Positioned(
            left: size * 0.0625,
            top: size * 0.0653,
            right: size * 0.375,
            bottom: 0,
            child: SvgPicture.asset(AppAssets.iconCatFamilyC),
          ),
        ],
      ),
    );
  }
}
