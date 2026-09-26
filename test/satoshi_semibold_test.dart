import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/utils/app_constants/app_styles.dart';
import 'helpers/load_app_fonts.dart';

/// SemiBold had no static cut, so `AppStyles.semiBold` fell back to the
/// nearest weight. The variable face covers it now — but only because every
/// style carries the exact weight as a `FontVariation`, which is what
/// actually instances a variable font. Registering the file alone would
/// render it at the face's default (900).
void main() {
  setUpAll(loadAppFonts);

  test('a semibold style asks for 600 on the weight axis', () {
    final style = AppStyles.label(14, weight: AppStyles.semiBold);

    expect(style.fontFamily, 'Satoshi');
    expect(style.fontWeight, FontWeight.w600);
    expect(style.fontVariations, contains(const FontVariation('wght', 600)));
  });

  test('every weight the app uses names itself on the axis', () {
    for (final weight in [
      AppStyles.light,
      AppStyles.regular,
      AppStyles.medium,
      AppStyles.semiBold,
      AppStyles.bold,
      AppStyles.black,
    ]) {
      final style = AppStyles.body(14, weight: weight);
      expect(
        style.fontVariations,
        contains(FontVariation('wght', weight.value.toDouble())),
        reason: 'w${weight.value}',
      );
    }
  });

  testWidgets('semibold text lays out and paints', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Free · Pro',
              style: AppStyles.label(14, weight: AppStyles.semiBold),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Free · Pro'), findsOneWidget);
  });
}
