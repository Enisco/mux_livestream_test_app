import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/history/data/history_dummy_data.dart';
import 'package:test_app/features/history/views/history_screen.dart';
import 'package:test_app/features/history/views/widgets/history_parts.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/content_list_row.dart';
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
      builder: (context) => MaterialApp(
        home: Scaffold(backgroundColor: AppColors.base1, body: child),
      ),
    ),
  );
  await tester.pump();
}

/// Renders the whole list at once so lazily-built groups are present.
const _tall = Size(390, 2400);

void main() {
  setUpAll(loadAppFonts);

  group('the screen', () {
    testWidgets('lists the resume rail and every day group', (tester) async {
      // Tall enough that the lazy list builds every group; on a phone the
      // later ones are simply scrolled to.
      await _pump(tester, const HistoryScreen(), size: _tall);

      expect(find.text('Continue watching'), findsOneWidget);
      for (final day in HistoryDummyData.days) {
        expect(find.text(day.label), findsOneWidget, reason: day.label);
      }
      expect(find.text('Romans, chapter'), findsOneWidget);
    });

    testWidgets('typing narrows to matching rows and drops empty days', (
      tester,
    ) async {
      await _pump(tester, const HistoryScreen());

      await tester.enterText(find.byType(TextField), 'romans');
      await tester.pump();

      expect(find.text('Romans, chapter'), findsOneWidget);
      expect(find.text('Sunday Worship'), findsNothing);
      // "12 June" holds nothing matching, so its heading goes too.
      expect(find.text('12 June'), findsNothing);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('a search matches the creator as well as the title', (
      tester,
    ) async {
      await _pump(tester, const HistoryScreen());

      await tester.enterText(find.byType(TextField), 'horizon');
      await tester.pump();

      expect(find.text('When Mountains Move'), findsOneWidget);
      expect(find.text('Romans, chapter'), findsNothing);
    });

    testWidgets('the resume rail is hidden while searching', (tester) async {
      // It is not a search result, so leaving it up would look like one.
      await _pump(tester, const HistoryScreen());
      expect(find.text('Continue watching'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'romans');
      await tester.pump();

      expect(find.text('Continue watching'), findsNothing);
    });

    testWidgets('a query nothing matches explains itself', (tester) async {
      await _pump(tester, const HistoryScreen());

      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.pump();

      expect(find.text('Nothing matched'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsNothing);
    });

    testWidgets('clearing everything asks first, then empties the screen', (
      tester,
    ) async {
      await _pump(tester, const HistoryScreen());

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('Clear your history?'), findsOneWidget);

      // Backing out leaves the list alone.
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Romans, chapter'), findsOneWidget);

      await tester.tap(find.text('Clear all').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Romans, chapter'), findsNothing);
    });
  });

  group('a history row', () {
    testWidgets('counts each kind in its own words', (tester) async {
      await _pump(tester, const HistoryScreen(), size: _tall);

      // Video is counted in views, audio in plays, a blog in opens.
      expect(find.textContaining('12K views'), findsWidgets);
      expect(find.textContaining('10 plays'), findsOneWidget);
      expect(find.textContaining('12 opens'), findsOneWidget);
    });

    testWidgets('an event shows its date and place, not a view count', (
      tester,
    ) async {
      await _pump(tester, const HistoryScreen(), size: _tall);

      expect(find.text('12 June 2026'), findsOneWidget);
      expect(find.textContaining('River Worship'), findsOneWidget);
    });

    testWidgets('a row with no count does not print a bare zero', (
      tester,
    ) async {
      await _pump(
        tester,
        const ContentListRow(
          title: 'Untouched',
          creatorName: 'Someone',
          meta: 'Video · 6d',
        ),
      );
      expect(find.textContaining('0 views'), findsNothing);
    });

    testWidgets('a part-watched row draws its progress bar', (tester) async {
      await _pump(
        tester,
        const ContentListRow(
          title: 'Half seen',
          creatorName: 'Someone',
          progress: 0.4,
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.4, 0.001));
    });

    testWidgets('an unwatched row draws no bar at all', (tester) async {
      await _pump(
        tester,
        const ContentListRow(title: 'Fresh', creatorName: 'Someone'),
      );
      expect(find.byType(FractionallySizedBox), findsNothing);
    });
  });

  group('a resume card', () {
    testWidgets('shows how far in the reader got', (tester) async {
      await _pump(
        tester,
        const HistoryResumeCard(
          item: HistoryResumeItem(
            id: 'r',
            title: 'Half seen',
            creatorName: 'Grace Community',
            progress: 0.59,
          ),
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.59, 0.001));
    });

    testWidgets('a progress value beyond the end cannot overrun', (
      tester,
    ) async {
      await _pump(
        tester,
        const HistoryResumeCard(
          item: HistoryResumeItem(
            id: 'r',
            title: 'Done',
            creatorName: 'C',
            progress: 2,
          ),
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, 1);
    });
  });

  group('every kind is reachable', () {
    test('each kind knows what it counts', () {
      expect(HistoryKind.video.countNoun, 'views');
      expect(HistoryKind.audio.countNoun, 'plays');
      expect(HistoryKind.blog.countNoun, 'opens');
      expect(HistoryKind.event.countNoun, isEmpty);
    });

    test('the placeholder data exercises every kind the design draws', () {
      // Otherwise a variant can rot unnoticed until the API arrives.
      final used = {
        for (final day in HistoryDummyData.days)
          for (final e in day.entries) e.kind,
      };
      expect(used, containsAll(<HistoryKind>[
        HistoryKind.library,
        HistoryKind.video,
        HistoryKind.audio,
        HistoryKind.devotional,
        HistoryKind.blog,
        HistoryKind.event,
      ]));
    });
  });
}
