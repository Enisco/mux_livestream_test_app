import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

/// SVG rather than a flag emoji — no emoji glyph renders on the iOS simulator
/// and many Android builds ship none. See docs/OPEN_ISSUES.md.
class CountryFlagIcon extends StatelessWidget {
  const CountryFlagIcon({super.key, required this.isoCode, this.height = 14});

  final String isoCode;

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
