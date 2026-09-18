import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/studio_sheets.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

const _context = DashboardContext(
  creatorId: 'c1',
  displayName: 'Pastor James',
  handle: 'pjames',
  role: 'owner',
  capabilities: {
    'canCreateMedia': true,
    'canCreateLivestream': true,
    'canManageGiving': true,
  },
);

Future<StudiosChoice?> _openStudios(WidgetTester tester) async {
  StudiosChoice? picked;
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: StudiosSheet(
            current: _context,
            onPick: (choice) => picked = choice,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return picked;
}

void main() {
  setUpAll(loadAppFonts);

  group('the studios sheet', () {
    testWidgets('names the studio the reader is in, and their role', (
      tester,
    ) async {
      await _openStudios(tester);

      expect(find.text(AppStrings.studiosSheetTitle), findsOneWidget);
      expect(find.text('Pastor James'), findsOneWidget);
      expect(find.text('Personal · Owner'), findsOneWidget);
    });

    testWidgets('offers switching, settings and the way back out', (
      tester,
    ) async {
      await _openStudios(tester);

      expect(find.text(AppStrings.studiosSwitch), findsOneWidget);
      expect(find.text(AppStrings.studiosSettings), findsOneWidget);
      expect(find.text(AppStrings.studiosBackToWatching), findsOneWidget);
    });

    testWidgets('invents no studios the reader does not belong to', (
      tester,
    ) async {
      await _openStudios(tester);

      // Nothing returns a membership list yet, so exactly one studio is
      // named — the real one. A placeholder row here would tell the reader
      // they belong to a ministry they do not.
      expect(find.text('CCI International'), findsNothing);
    });

    testWidgets('switching reports back as its own choice', (tester) async {
      StudiosChoice? picked;
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: StudiosSheet(
                current: _context,
                onPick: (choice) => picked = choice,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('studio-switch')));
      await tester.pump();
      expect(picked, StudiosChoice.switchStudio);
    });
  });

  group('the create sheet', () {
    testWidgets('offers every kind a full owner may make', (tester) async {
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: CreateSheet(kinds: CreateKind.values, onPick: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final kind in CreateKind.values) {
        expect(find.text(kind.title), findsOneWidget, reason: kind.title);
      }
    });

    testWidgets('offers only what was handed to it', (tester) async {
      // A member who cannot start a livestream should not be shown one.
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: CreateSheet(
                kinds: const [CreateKind.video, CreateKind.audio],
                onPick: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.createVideo), findsOneWidget);
      expect(find.text(AppStrings.createLivestream), findsNothing);
    });
  });

  test('capabilities gate the create kinds', () {
    expect(_context.can('canCreateLivestream'), isTrue);
    expect(_context.can('canManageTeam'), isFalse, reason: 'absent is false');
  });
}
