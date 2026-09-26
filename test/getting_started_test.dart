import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// The studio's getting-started checklist.
///
/// Two things it has to get right, and it got one of them wrong: every row
/// answered "not built yet" when tapped, even though the destinations all
/// exist. A checklist whose steps cannot be started is worse than no
/// checklist.
///
/// The other is the state of each row. `complete` is the server's answer,
/// per step — a brand-new studio on staging (2026-09-26) reports:
///
/// ```
/// complete_profile        complete=false  applicable=true
/// publish_first_content   complete=false  applicable=true
/// invite_team             complete=true   applicable=false
/// ```
///
/// So "done" is never inferred from anything the app knows, and a step that
/// does not apply to this studio is not shown at all — note `invite_team`
/// arrives *complete* but inapplicable, which would read as a finished step
/// for a solo creator who never had a team.
List<GettingStartedStep> _steps(List<Map<String, dynamic>> rows) =>
    rows.map(GettingStartedStep.fromJson).toList();

Future<void> _pumpCard(
  WidgetTester tester,
  List<GettingStartedStep> steps, {
  void Function(GettingStartedStep)? onStep,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: GettingStartedCard(steps: steps, onStep: onStep ?? (_) {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The colour of the bullet behind a row tells done from not-done.
Color _bulletColour(WidgetTester tester, String key) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(ValueKey('step-$key')),
          matching: find.byType(Container),
        )
        .at(1),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  setUpAll(loadAppFonts);

  group('done and not-done', () {
    testWidgets('an unfinished step shows its number, not a tick', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _steps(const [
          {
            'key': 'publish_first_content',
            'complete': false,
            'applicable': true,
          },
        ]),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(
        _bulletColour(tester, 'publish_first_content'),
        AppColors.neutral800,
      );
    });

    testWidgets('a finished step shows a tick, not its number', (tester) async {
      await _pumpCard(
        tester,
        _steps(const [
          {'key': 'complete_profile', 'complete': true, 'applicable': true},
        ]),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(_bulletColour(tester, 'complete_profile'), AppColors.brandPrimary);
    });

    testWidgets('one done and one not is the shape a new studio is in', (
      tester,
    ) async {
      // Exactly the screen a creator sees after setting up their profile.
      await _pumpCard(
        tester,
        _steps(const [
          {'key': 'complete_profile', 'complete': true, 'applicable': true},
          {
            'key': 'publish_first_content',
            'complete': false,
            'applicable': true,
          },
        ]),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
      // The unfinished one keeps its position in the list, not a count of
      // what is left.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(
        find.text(AppStrings.studioStepTitles['complete_profile']!),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.studioStepTitles['publish_first_content']!),
        findsOneWidget,
      );
    });

    testWidgets('done is never inferred — it is whatever the server said', (
      tester,
    ) async {
      // A step the server calls complete renders complete even where the
      // app has no way of knowing why.
      await _pumpCard(
        tester,
        _steps(const [
          {'key': 'go_live', 'complete': true, 'applicable': true},
        ]),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('every row leads somewhere', () {
    testWidgets('tapping an unfinished step reports it', (tester) async {
      GettingStartedStep? tapped;
      await _pumpCard(
        tester,
        _steps(const [
          {
            'key': 'publish_first_content',
            'complete': false,
            'applicable': true,
          },
        ]),
        onStep: (s) => tapped = s,
      );
      await tester.tap(
        find.byKey(const ValueKey('step-publish_first_content')),
      );
      await tester.pumpAndSettle();
      expect(tapped?.key, 'publish_first_content');
    });

    testWidgets('and so does tapping a finished one', (tester) async {
      // "Complete your profile" is how a creator goes back and changes the
      // photo they already set, so a tick must not make the row inert.
      GettingStartedStep? tapped;
      await _pumpCard(
        tester,
        _steps(const [
          {'key': 'complete_profile', 'complete': true, 'applicable': true},
        ]),
        onStep: (s) => tapped = s,
      );
      await tester.tap(find.byKey(const ValueKey('step-complete_profile')));
      await tester.pumpAndSettle();
      expect(tapped?.key, 'complete_profile');
      expect(tapped?.complete, isTrue);
    });

    testWidgets('no row anywhere says it is not built', (tester) async {
      await _pumpCard(
        tester,
        _steps(const [
          {'key': 'complete_profile', 'complete': true, 'applicable': true},
          {
            'key': 'publish_first_content',
            'complete': false,
            'applicable': true,
          },
        ]),
      );
      expect(find.textContaining('not built'), findsNothing);
    });
  });

  group('parsing the server\'s answer', () {
    test('complete and applicable are read per step', () {
      final steps = _steps(const [
        {'key': 'complete_profile', 'complete': false, 'applicable': true},
        {'key': 'invite_team', 'complete': true, 'applicable': false},
      ]);
      expect(steps[0].complete, isFalse);
      expect(steps[0].applicable, isTrue);
      expect(steps[1].complete, isTrue);
      expect(steps[1].applicable, isFalse);
    });

    test('a step missing its flags is unfinished and shown', () {
      // Safer than the other way round: a step wrongly ticked is a step
      // nobody does.
      final step = GettingStartedStep.fromJson(const {'key': 'x'});
      expect(step.complete, isFalse);
      expect(step.applicable, isTrue);
    });

    test(
      'an inapplicable step arrives complete, which is why it is filtered',
      () {
        // `invite_team` comes back complete:true for a solo creator. Showing
        // it would read as a finished step they never took.
        final steps = _steps(const [
          {'key': 'complete_profile', 'complete': false, 'applicable': true},
          {'key': 'invite_team', 'complete': true, 'applicable': false},
        ]).where((s) => s.applicable).toList();
        expect(steps.map((s) => s.key), ['complete_profile']);
        // And the checklist still counts as unfinished, so the card shows.
        expect(steps.any((s) => !s.complete), isTrue);
      },
    );

    test('a studio with everything done has no unfinished steps left', () {
      final steps = _steps(const [
        {'key': 'complete_profile', 'complete': true, 'applicable': true},
        {'key': 'publish_first_content', 'complete': true, 'applicable': true},
      ]);
      expect(steps.any((s) => !s.complete), isFalse);
    });
  });
}
