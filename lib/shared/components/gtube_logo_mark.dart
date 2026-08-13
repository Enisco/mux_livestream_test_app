import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class GTubeLogoMark extends StatelessWidget {
  const GTubeLogoMark({super.key, this.scale = 1.0})
    : showRing = true,
      filled = false,
      _shadowSpread = 0;

  const GTubeLogoMark.plain({super.key, this.scale = 1.0})
    : showRing = false,
      filled = true,
      _shadowSpread = -5.803;

  final double scale;
  final bool showRing;
  final bool filled;
  final double _shadowSpread;

  static Widget compact() => const _CompactLogoTile();

  static const _ringWidth = 52.8;
  static const _ringHeight = 63.6;
  static const _ringRadius = 13.512;
  static const _ringBorder = 2.4;
  static const _tileRadius = 9.313;
  static const _tileBorder = 0.591;
  static const _tilePadding = 8.444;
  static const _glyphWidth = 35.651;
  static const _glyphHeight = 39.687;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ringWidth * scale,
      height: _ringHeight * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(_tilePadding * scale),
            decoration: BoxDecoration(
              color: filled ? AppColors.base1 : null,
              borderRadius: BorderRadius.circular(_tileRadius * scale),
              border: Border.all(
                color: AppColors.neutral700,
                width: _tileBorder * scale,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.logoGlowOuter,
                  offset: Offset(0, 23.21 * scale),
                  blurRadius: 46.42 * scale,
                  spreadRadius: _shadowSpread * scale,
                ),
                BoxShadow(
                  color: AppColors.logoGlowInner,
                  offset: Offset(0, 5.803 * scale),
                  blurRadius: 5.803 * scale,
                  spreadRadius: _shadowSpread * scale,
                ),
              ],
            ),
            child: Image.asset(
              AppAssets.gtubeLogo,
              width: _glyphWidth * scale,
              height: _glyphHeight * scale,
              fit: BoxFit.contain,
            ),
          ),
          if (showRing)
            Container(
              width: _ringWidth * scale,
              height: _ringHeight * scale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_ringRadius * scale),
                border: Border.all(
                  color: AppColors.brandPrimary,
                  width: _ringBorder * scale,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactLogoTile extends StatelessWidget {
  const _CompactLogoTile();

  static const _padding = 5.821;
  static const _radius = 9.313;
  static const _border = 0.407;
  static const _glyphWidth = 24.576;
  static const _glyphHeight = 27.358;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: AppColors.base1,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppColors.neutral700, width: _border),
        boxShadow: AppStyles.logoTileShadow,
      ),
      child: Image.asset(
        AppAssets.gtubeLogo,
        width: _glyphWidth,
        height: _glyphHeight,
        fit: BoxFit.contain,
      ),
    );
  }
}
