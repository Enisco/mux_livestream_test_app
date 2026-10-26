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

Future<StudiosOutcome?> _openStudios(
  WidgetTester tester, {
  List<StudioMembership> studios = const [],
}) async {
  StudiosOutcome? picked;
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: StudiosSheet(
            current: _context,
            studios: studios,
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

    testWidgets('offers settings and the way back out', (tester) async {
      // "Switch studio" is no longer a row of its own: the studios are
      // listed, so switching is tapping one.
      await _openStudios(tester);

      expect(find.text(AppStrings.studiosSwitch), findsNothing);
      expect(find.text(AppStrings.studiosSettings), findsOneWidget);
      expect(find.text(AppStrings.studiosBackToWatching), findsOneWidget);
    });

    testWidgets('invents no studios the reader does not belong to', (
      tester,
    ) async {
      await _openStudios(tester);

      // Only the current studio, when the reader belongs to no other.
      expect(find.text('CCI International'), findsNothing);
    });

    testWidgets('lists every studio the reader belongs to', (tester) async {
      // `GET /v1/creator/me/memberships` answers both the one they own and
      // the organisations they were added to.
      await _openStudios(
        tester,
        studios: const [
          StudioMembership(
            creatorId: 'c2',
            displayName: 'CCI International',
            handle: 'cci',
            role: 'editor',
          ),
        ],
      );

      expect(find.text('CCI International'), findsOneWidget);
    });

    testWidgets('and the current one is not offered twice', (tester) async {
      // A reader who both owns a studio and holds a member row in it is one
      // row, ticked — ownership is the stronger claim.
      await _openStudios(
        tester,
        studios: [
          StudioMembership(
            creatorId: _context.creatorId,
            displayName: _context.displayName,
            handle: _context.handle,
            role: 'owner',
          ),
        ],
      );

      expect(find.text(_context.displayName), findsOneWidget);
    });

    testWidgets('picking another reports its creator id', (tester) async {
      StudiosOutcome? picked;
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: StudiosSheet(
                current: _context,
                studios: const [
                  StudioMembership(
                    creatorId: 'c2',
                    displayName: 'CCI International',
                    handle: 'cci',
                    role: 'editor',
                  ),
                ],
                onPick: (choice) => picked = choice,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('studio-c2')));
      await tester.pump();
      expect(picked?.switchTo, 'c2');
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
