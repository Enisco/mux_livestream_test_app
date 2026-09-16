import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/views/giving_screen.dart';
import 'package:test_app/features/subscriptions/data/subscriptions_dummy_data.dart';
import 'package:test_app/features/subscriptions/views/manage_following_screen.dart';
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

  group('managing who you follow', () {
    testWidgets('lists everyone, marking who is live', (tester) async {
      await _pump(tester, const ManageFollowingScreen(), size: _tall);

      expect(find.text('Following'), findsOneWidget);
      expect(find.text('See latest content'), findsOneWidget);
      for (final ministry in SubscriptionsDummyData.following) {
        expect(find.text(ministry.name), findsOneWidget, reason: ministry.name);
      }
      expect(find.text('LIVE'), findsNWidgets(2));
      expect(find.text('@newlife · Posted 1 hour ago'), findsOneWidget);
    });

    testWidgets('search narrows by name or handle', (tester) async {
      await _pump(tester, const ManageFollowingScreen(), size: _tall);

      await tester.enterText(find.byType(TextField), '@petra');
      await tester.pump();

      expect(find.text('Petra CC'), findsOneWidget);
      expect(find.text('Living Faith'), findsNothing);
    });

    testWidgets('a query matching nothing says so', (tester) async {
      await _pump(tester, const ManageFollowingScreen(), size: _tall);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();

      expect(find.text('No ministry matched'), findsOneWidget);
      // Not the starter card — they do follow people.
      expect(find.text('Ministries to get you started'), findsNothing);
    });

    testWidgets('unfollowing takes the row out', (tester) async {
      await _pump(tester, const ManageFollowingScreen(), size: _tall);

      await tester.tap(find.byKey(const ValueKey('unfollow-m2')));
      await tester.pump();

      expect(find.text('Living Faith'), findsNothing);
      expect(find.text('Cynthia Morgan'), findsOneWidget);
    });

    testWidgets('the bell sheet is one choice, not four', (tester) async {
      await _pump(tester, const ManageFollowingScreen(), size: _tall);

      await tester.tap(find.byKey(const ValueKey('notify-m1')));
      await tester.pumpAndSettle();

      expect(find.text('Get notified on all things'), findsOneWidget);
      expect(find.text('Unfollow Cynthia Morgan'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('level-none')));
      await tester.pumpAndSettle();

      // Reopening shows None in force instead of All.
      await tester.tap(find.byKey(const ValueKey('notify-m1')));
      await tester.pumpAndSettle();
      expect(find.text('Stay subscribed, no notifications'), findsOneWidget);
    });

    testWidgets('the sheet can unfollow too', (tester) async {
      await _pump(tester, const ManageFollowingScreen(), size: _tall);

      await tester.tap(find.byKey(const ValueKey('notify-m6')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unfollow The River Church'));
      await tester.pumpAndSettle();

      expect(find.text('The River Church'), findsNothing);
    });

    testWidgets('following nobody offers ministries to start with', (
      tester,
    ) async {
      await _pump(tester, const ManageFollowingScreen(), size: _tall);

      for (final ministry in SubscriptionsDummyData.following) {
        await tester.tap(find.byKey(ValueKey('unfollow-${ministry.id}')));
        await tester.pump();
      }

      expect(find.text('Follow ministries to fill this feed'), findsOneWidget);
      expect(find.text('Ministries to get you started'), findsOneWidget);
      expect(find.text('Follow'), findsNWidgets(3));
      expect(find.text('Show more'), findsOneWidget);
      // The field goes with the list it narrowed.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      await _pump(
        tester,
        const ManageFollowingScreen(),
        size: const Size(320, 4000),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
