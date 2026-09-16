import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/data/records_dummy_data.dart';
import 'package:test_app/features/library/views/my_events_screen.dart';
import 'package:test_app/features/library/views/records_screens.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
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
const _tall = Size(390, 3600);

/// How dimmed a sheet row is — the sheet fades out what it cannot offer.
double _opacityOf(WidgetTester tester, String label) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  setUpAll(loadAppFonts);

  group('my events', () {
    testWidgets('groups by whether the date has passed', (tester) async {
      await _pump(tester, const MyEventsScreen(), size: _tall);

      expect(find.text('My events'), findsOneWidget);
      expect(find.text('10 events'), findsOneWidget);
      expect(find.text('UPCOMING (2)'), findsOneWidget);
      expect(find.text('PAST (2)'), findsOneWidget);
    });

    testWidgets('offers actions on upcoming events only', (tester) async {
      await _pump(tester, const MyEventsScreen(), size: _tall);

      // Two upcoming rows: one still to answer, one already answered.
      expect(find.text('RSVP'), findsOneWidget);
      expect(find.text('Going'), findsOneWidget);
      expect(find.text('Add to calendar'), findsNWidgets(2));
    });

    testWidgets('RSVP flips the row to Going and back', (tester) async {
      await _pump(tester, const MyEventsScreen(), size: _tall);

      await tester.tap(find.text('RSVP'));
      await tester.pump();
      expect(find.text('RSVP'), findsNothing);
      expect(find.text('Going'), findsNWidgets(2));

      await tester.tap(find.text('Going').first);
      await tester.pump();
      expect(find.text('RSVP'), findsOneWidget);
    });

    testWidgets('search narrows to the matching event', (tester) async {
      await _pump(tester, const MyEventsScreen(), size: _tall);

      await tester.enterText(find.byType(TextField), 'Night of');
      await tester.pump();

      expect(find.text('Night of Worship'), findsOneWidget);
      expect(find.text('Youth Conference'), findsNothing);
      // Only a past row survives, so no group of upcoming ones is drawn.
      expect(find.text('UPCOMING (2)'), findsNothing);
    });

    testWidgets('a query that matches nothing says so', (tester) async {
      await _pump(tester, const MyEventsScreen(), size: _tall);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();

      expect(find.text('Nothing matched'), findsOneWidget);
      expect(find.text('No events yet'), findsNothing);
    });
  });

  group('prayer requests', () {
    testWidgets('lists every request with its status', (tester) async {
      await _pump(tester, const PrayerRequestsScreen(), size: _tall);

      expect(find.text('My prayer requests'), findsOneWidget);
      expect(find.text('Cynthia Morgan'), findsOneWidget);
      expect(find.text('About: Walking by faith'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Open'), findsNWidgets(3)); // two pills + the chip
      expect(find.text('Shared 2 days ago'), findsOneWidget);
    });

    testWidgets('a filter chip keeps only that status', (tester) async {
      await _pump(tester, const PrayerRequestsScreen(), size: _tall);

      await tester.tap(find.text('Closed').first);
      await tester.pump();

      expect(find.text('Aisha Khan'), findsOneWidget);
      expect(find.text('Cynthia Morgan'), findsNothing);
    });

    testWidgets('the Audio chip narrows by content kind, not status', (
      tester,
    ) async {
      await _pump(tester, const PrayerRequestsScreen(), size: _tall);

      await tester.tap(find.text('Audio'));
      await tester.pump();

      // Both audio requests survive, though one is open and one prayed for.
      expect(find.text('Cynthia Morgan'), findsOneWidget);
      expect(find.text('Marcus Lee'), findsOneWidget);
      expect(find.text('Aisha Khan'), findsNothing);
      expect(find.text('General'), findsNothing);
    });

    testWidgets('deleting the last match leaves the empty state', (
      tester,
    ) async {
      await _pump(tester, const PrayerRequestsScreen(), size: _tall);

      await tester.tap(find.text('Closed').first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('more-p3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('action-Delete')));
      await tester.pumpAndSettle();

      expect(find.text('No request yet'), findsOneWidget);
    });

    testWidgets('Edit is offered only while the request is open', (
      tester,
    ) async {
      await _pump(tester, const PrayerRequestsScreen(), size: _tall);

      // Lena's request has been prayed for, so editing is closed off.
      await tester.tap(find.byKey(const ValueKey('more-p5')));
      await tester.pumpAndSettle();

      expect(find.text('Pray again'), findsOneWidget);
      expect(_opacityOf(tester, 'Edit'), lessThan(1));
    });

    testWidgets('Delete takes the request out of the list', (tester) async {
      await _pump(tester, const PrayerRequestsScreen(), size: _tall);

      await tester.tap(find.byKey(const ValueKey('more-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('action-Delete')));
      await tester.pumpAndSettle();

      expect(find.text('Cynthia Morgan'), findsNothing);
      expect(find.text('Marcus Lee'), findsOneWidget);
    });
  });

  group('testimonies', () {
    testWidgets('states where each one stands', (tester) async {
      await _pump(tester, const TestimoniesScreen(), size: _tall);

      expect(find.text('Testimonies'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Approved'), findsNWidgets(2));
      expect(find.text('Not approved'), findsNWidgets(2));
      expect(find.text('Submitted 3 days ago'), findsOneWidget);
    });

    testWidgets('an approved one names the wall it is live on', (tester) async {
      await _pump(tester, const TestimoniesScreen(), size: _tall);

      expect(find.text("Live on River Worship's wall"), findsNWidgets(2));
    });

    testWidgets('a pending one explains what happens next', (tester) async {
      await _pump(tester, const TestimoniesScreen(), size: _tall);

      expect(
        find.textContaining('will review this before it appears'),
        findsOneWidget,
      );
    });

    testWidgets('viewing on the wall is offered only once approved', (
      tester,
    ) async {
      await _pump(tester, const TestimoniesScreen(), size: _tall);

      // t1 is pending, so its wall link is closed off; t2 is approved.
      await tester.tap(find.byKey(const ValueKey('more-t1')));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'View on wall'), lessThan(1));

      await tester.tap(find.byKey(const ValueKey('action-Remove testimony')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-t2')));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'View on wall'), 1);
    });

    testWidgets('removing takes it out of the list', (tester) async {
      await _pump(tester, const TestimoniesScreen(), size: _tall);

      await tester.tap(find.byKey(const ValueKey('more-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('action-Remove testimony')));
      await tester.pumpAndSettle();

      expect(find.text('Pending review'), findsNothing);
      expect(
        find.text('Elena Rodriguez'),
        findsOneWidget,
        reason: 'the rest stay',
      );
    });
  });

  group('nothing overflows', () {
    for (final (name, screen) in <(String, Widget)>[
      ('my events', MyEventsScreen()),
      ('prayer requests', PrayerRequestsScreen()),
      ('testimonies', TestimoniesScreen()),
    ]) {
      testWidgets('$name on a narrow phone', (tester) async {
        await _pump(tester, screen, size: const Size(320, 3600));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the dummy rows are all accounted for', (tester) async {
      expect(RecordsDummyData.events.length, 4);
      expect(RecordsDummyData.prayers.length, 5);
      expect(RecordsDummyData.testimonies.length, 5);
    });
  });

  testWidgets('the screens sit on the app background', (tester) async {
    await _pump(tester, const TestimoniesScreen());
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.base1);
  });
}
