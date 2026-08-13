import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

/// Country flag drawn from a bundled SVG rather than an emoji glyph.
///
/// Flag emoji do not render here: the engine cannot reach the system emoji font
/// on the iOS simulator, and many Android builds ship no flag glyphs at all.
/// See docs/OPEN_ISSUES.md.
class CountryFlagIcon extends StatelessWidget {
  const CountryFlagIcon({super.key, required this.isoCode, this.height = 14});

  final String isoCode;

  /// Width follows the 4:3 ratio the flag set is drawn at.
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 4 / 3;
    return SizedBox(
      width: width,
      height: height,
      child: CountryFlag.fromCountryCode(
        isoCode,
        theme: ImageTheme(
          width: width,
          height: height,
          shape: const RoundedRectangle(2),
        ),
      ),
    );
  }
}
