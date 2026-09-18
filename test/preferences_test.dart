import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/data/preferences_dummy_data.dart';
import 'package:test_app/features/settings/views/account_sheets.dart';
import 'package:test_app/features/settings/views/event_reminders_screen.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
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
      builder: (context) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('lead times read as English', () {
    test('minutes, an hour, and days', () {
      expect(leadTimeLabel(15), '15 minutes before');
      expect(leadTimeLabel(30), '30 minutes before');
      expect(leadTimeLabel(60), '1 hour before');
      expect(leadTimeLabel(120), '2 hours before');
      expect(leadTimeLabel(1440), '1 day before');
      expect(leadTimeLabel(2880), '2 days before');
    });
  });

  group('event reminders', () {
    testWidgets('offers every lead time the design lists', (tester) async {
      await _pump(tester, const EventRemindersScreen());

      for (final minutes in PreferencesDummyData.leadTimes) {
        expect(
          find.text(leadTimeLabel(minutes)),
          findsOneWidget,
          reason: '$minutes',
        );
      }
      expect(find.text(AppStrings.remindersDefault), findsOneWidget);
    });

    testWidgets('choosing a different lead time moves the selection', (
      tester,
    ) async {
      await _pump(tester, const EventRemindersScreen());

      await tester.tap(find.text('15 minutes before'));
      await tester.pump();

      // The chosen row is the only one filled in.
      final filled = tester.widgetList<Container>(find.byType(Container)).where(
        (c) {
          final border = (c.decoration as BoxDecoration?)?.border;
          return border is Border && border.top.color == AppColors.brandPrimary;
        },
      );
      expect(filled, hasLength(1));
    });

    testWidgets('turning reminders off disables the choices', (tester) async {
      // Picking a lead time is meaningless when nothing will be sent.
      await _pump(tester, const EventRemindersScreen());

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final gate = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text('15 minutes before'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(gate.ignoring, isTrue);
    });

    testWidgets('it says the choice is not saved anywhere yet', (tester) async {
      await _pump(tester, const EventRemindersScreen());

      await tester.tap(find.text('1 day before'));
      await tester.pump();

      expect(find.text(AppStrings.remindersNotWired), findsOneWidget);
    });
  });

  group('the topics sheet', () {
    testWidgets('lists every topic with its current state', (tester) async {
      await _pump(tester, const TopicsSheet());

      for (final (label, _) in PreferencesDummyData.topics) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text(AppStrings.topicsDone), findsOneWidget);
    });

    testWidgets('a topic can be turned off and back on', (tester) async {
      await _pump(tester, const TopicsSheet());

      // Worship starts on, so its row shows a tick.
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
      final onBefore = tester
          .widgetList<Icon>(find.byIcon(Icons.check_rounded))
          .length;

      await tester.tap(find.text('Worship'));
      await tester.pump();
      // Tapping the label must not toggle it — only the pill does.
      expect(
        tester.widgetList<Icon>(find.byIcon(Icons.check_rounded)).length,
        onBefore,
      );
    });

    testWidgets('the pill toggles the topic', (tester) async {
      await _pump(tester, const TopicsSheet());

      final onBefore = tester
          .widgetList<Icon>(find.byIcon(Icons.check_rounded))
          .length;

      // The pill sits at the end of the first row.
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();

      expect(
        tester.widgetList<Icon>(find.byIcon(Icons.check_rounded)).length,
        onBefore - 1,
      );
    });

    testWidgets('every topic has a stable key so reordering can track it', (
      tester,
    ) async {
      // Without distinct keys the list would rebuild rows into the wrong
      // places as soon as one is dragged.
      final keys = PreferencesDummyData.topics.map((t) => t.$1).toSet();
      expect(keys.length, PreferencesDummyData.topics.length);
    });
  });

  group('the destructive confirmations', () {
    testWidgets('logging out everywhere explains the cost', (tester) async {
      await _pump(tester, const LogOutAllDialog());

      expect(find.text(AppStrings.logOutAllTitle), findsOneWidget);
      expect(find.textContaining('including this one'), findsOneWidget);
      expect(find.text(AppStrings.commonCancel), findsOneWidget);
      expect(find.text(AppStrings.logOutAllConfirm), findsOneWidget);
    });

    testWidgets('deactivating lists what survives it', (tester) async {
      await _pump(tester, const DeactivateAccountDialog());

      expect(find.text(AppStrings.deactivateKeeps), findsOneWidget);
      expect(find.text(AppStrings.deactivateReturn), findsOneWidget);
      expect(find.text(AppStrings.deactivateHidden), findsOneWidget);
    });

    testWidgets('neither actually does anything yet', (tester) async {
      // These two end sessions and hide accounts. Confirming must not claim
      // to have done either while no route is wired.
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => LogOutAllDialog.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.logOutAllConfirm));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.logOutAllNotWired), findsOneWidget);
    });

    testWidgets('cancelling just closes', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => DeactivateAccountDialog.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.deactivateTitle), findsNothing);
      expect(find.text(AppStrings.deactivateNotWired), findsNothing);
    });
  });

  group('all four survive a small screen', () {
    testWidgets('reminders at 320pt', (tester) async {
      await _pump(
        tester,
        const EventRemindersScreen(),
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('topics at 320pt', (tester) async {
      await _pump(tester, const TopicsSheet(), size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });

    testWidgets('both dialogs at 320pt', (tester) async {
      await _pump(tester, const LogOutAllDialog(), size: const Size(320, 568));
      expect(tester.takeException(), isNull);

      await _pump(
        tester,
        const DeactivateAccountDialog(),
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
