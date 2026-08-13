import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/onboarding/views/discovery_source_screen.dart';
import 'package:test_app/features/onboarding/views/interests_screen.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';

import 'helpers/load_app_fonts.dart';

const _sizes = <String, Size>{
  'iPhone SE': Size(375, 667),
  'iPhone 15': Size(393, 852),
  'iPhone 17 Pro Max': Size(440, 956),
};

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('onboarding screens lay out cleanly', () {
    for (final entry in _sizes.entries) {
      testWidgets('discovery source — ${entry.key}', (tester) async {
        await _pumpAt(tester, entry.value, const DiscoverySourceScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('interests — ${entry.key}', (tester) async {
        await _pumpAt(tester, entry.value, const InterestsScreen());
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('OnboardingScaffold', () {
    testWidgets('lays out a flex child when scrolling is off', (tester) async {
      await _pumpAt(
        tester,
        const Size(393, 852),
        const OnboardingScaffold(
          scrollable: false,
          child: Column(children: [Expanded(child: SizedBox())]),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
