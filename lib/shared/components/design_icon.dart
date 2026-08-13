import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DesignIcon extends StatelessWidget {
  const DesignIcon(
    this.asset, {
    super.key,
    required this.width,
    required this.height,
    this.box,
    this.color,
  });

  final String asset;
  final double width;
  final double height;

  final double? box;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glyph = SvgPicture.asset(
      asset,
      width: width,
      height: height,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
    if (box == null) return glyph;
    return SizedBox(
      width: box,
      height: box,
      child: Center(child: glyph),
    );
  }
}
