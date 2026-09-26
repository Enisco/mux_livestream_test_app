import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/views/giving_screen.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(home: child),
    ),
  );
  await tester.pump();
}

/// Tall enough that the lazy lists build every row at once.
const _tall = Size(390, 4000);

void main() {
  setUpAll(loadAppFonts);

  group('giving', () {
    testWidgets('leads with the year and what it came to', (tester) async {
      await _pump(tester, const GivingScreen(), size: _tall);

      expect(find.text('Given this year'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('₦225,000.00'), findsWidgets);
      expect(find.text('≈ \$145.00 total'), findsOneWidget);
      expect(find.text('6 gifts · Across 3 ministries'), findsOneWidget);
    });

    testWidgets('groups the gifts by month and names each document', (
      tester,
    ) async {
      await _pump(tester, const GivingScreen(), size: _tall);

      expect(find.text('Download yearly statement'), findsOneWidget);
      expect(find.text('JUNE 2026'), findsOneWidget);
      expect(find.text('MAY 2026'), findsOneWidget);
      // Each month repeats the same seven gifts.
      expect(find.text('Receipt'), findsNWidgets(6));
      expect(find.text('Invoice'), findsNWidgets(4));
      expect(find.text('Voucher'), findsNWidgets(4));
    });

    testWidgets('switching year switches the whole screen', (tester) async {
      await _pump(tester, const GivingScreen(), size: _tall);

      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('action-2025')));
      await tester.pumpAndSettle();

      expect(find.text('2025'), findsOneWidget);
      expect(find.text('JUNE 2025'), findsOneWidget);
      expect(find.text('JUNE 2026'), findsNothing);
    });

    testWidgets('a year with no gifts says so', (tester) async {
      await _pump(tester, const GivingScreen(), size: _tall);

      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('action-2024')));
      await tester.pumpAndSettle();

      expect(find.text('No givings yet'), findsOneWidget);
      expect(find.text('0 gifts'), findsOneWidget);
      expect(find.text('Download yearly statement'), findsNothing);
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      await _pump(tester, const GivingScreen(), size: const Size(320, 4000));
      expect(tester.takeException(), isNull);
    });
  });
}
