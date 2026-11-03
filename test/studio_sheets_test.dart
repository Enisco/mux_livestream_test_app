import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
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

  group('what every tab does with the answer', () {
    // Found on a device on 2026-11-03: "Back to watching" worked from the
    // Studio tab and nowhere else, and "Studio Settings" worked nowhere at
    // all. Three of the four tabs handled only `switchTo` and dropped the
    // other two answers on the floor, so the handling lives in one place
    // now and these are its tests.
    Future<BuildContext> pump(WidgetTester tester) async {
      late BuildContext captured;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) {
              captured = context;
              return const Text('A TAB');
            },
          ),
          GoRoute(
            path: AppRouter.studioProfile,
            builder: (_, _) => const Text('STUDIO SETTINGS'),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      return captured;
    }

    testWidgets('back to watching leaves, from whichever tab asked', (
      tester,
    ) async {
      final context = await pump(tester);
      var left = false;

      final next = applyStudiosOutcome(
        context,
        const StudiosOutcome.backToWatching(),
        onLeave: () => left = true,
      );

      expect(left, isTrue);
      expect(next, isNull);
    });

    testWidgets('settings opens the studio\'s own settings screen', (
      tester,
    ) async {
      // Not a snackbar repeating the sentence already under the row, and
      // not the onboarding chain, which starts every field empty.
      final context = await pump(tester);

      applyStudiosOutcome(context, const StudiosOutcome.settings());
      await tester.pumpAndSettle();

      expect(find.text('STUDIO SETTINGS'), findsOneWidget);
    });

    testWidgets('a studio is handed back for the tab to switch to', (
      tester,
    ) async {
      final context = await pump(tester);
      var left = false;

      final next = applyStudiosOutcome(
        context,
        const StudiosOutcome.switchTo('c2'),
        onLeave: () => left = true,
      );

      // The caller switches: what each tab has to throw away first differs.
      expect(next, 'c2');
      expect(left, isFalse);
    });

    testWidgets('a dismissed sheet does nothing at all', (tester) async {
      final context = await pump(tester);
      var left = false;

      expect(
        applyStudiosOutcome(context, null, onLeave: () => left = true),
        isNull,
      );
      await tester.pumpAndSettle();

      expect(left, isFalse);
      expect(find.text('STUDIO SETTINGS'), findsNothing);
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

  /// The studio's own logo, which the switcher and the pill both drew as a
  /// grey person icon however long the channel had had one.
  group('whose logo is on the row', () {
    const cdn = 'https://cdn.example.test';

    setUp(() => dotenv.testLoad(fileInput: 'CDN_BASE_URL=$cdn'));

    List<String> urls(WidgetTester tester) => [
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        if (image.image case final NetworkImage source) source.url,
    ];

    testWidgets('the open studio wears its own', (tester) async {
      await _openStudios(tester);
      expect(urls(tester), isEmpty, reason: 'no logo, no request');

      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: StudiosSheet(
                current: const DashboardContext(
                  creatorId: 'c1',
                  displayName: 'Pastor James',
                  handle: 'pjames',
                  role: 'owner',
                  avatarKey: 'public/avatar/c1/logo.jpg',
                  capabilities: {},
                ),
                onPick: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(urls(tester), ['$cdn/public/avatar/c1/logo.jpg']);
    });

    testWidgets('and so does every other studio listed', (tester) async {
      // The membership rows carry their own `avatarKey`; a switcher that
      // drew one logo four times would be worse than drawing none.
      await _openStudios(
        tester,
        studios: const [
          StudioMembership(
            creatorId: 'c2',
            displayName: 'CCI International',
            handle: 'cci',
            role: 'editor',
            avatarKey: 'public/avatar/c2/logo.jpg',
          ),
        ],
      );

      expect(urls(tester), ['$cdn/public/avatar/c2/logo.jpg']);
    });

    testWidgets('a studio with no logo keeps the ring', (tester) async {
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

      expect(urls(tester), isEmpty);
      expect(find.byIcon(Icons.person), findsNWidgets(2));
    });

    testWidgets('the pill in the tab header wears it too', (tester) async {
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: StudioPill(
                name: 'Pastor James',
                avatarKey: 'public/avatar/c1/logo.jpg',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(urls(tester), ['$cdn/public/avatar/c1/logo.jpg']);
    });

    testWidgets('a build with no CDN configured shows the ring', (
      tester,
    ) async {
      // `resolve` answers null without `CDN_BASE_URL`, and a null URL is
      // not something to hand `Image.network`.
      dotenv.testLoad(fileInput: '');
      await _openStudios(
        tester,
        studios: const [
          StudioMembership(
            creatorId: 'c2',
            displayName: 'CCI International',
            handle: 'cci',
            role: 'editor',
            avatarKey: 'public/avatar/c2/logo.jpg',
          ),
        ],
      );

      expect(urls(tester), isEmpty);
    });
  });

  test('capabilities gate the create kinds', () {
    expect(_context.can('canCreateLivestream'), isTrue);
    expect(_context.can('canManageTeam'), isFalse, reason: 'absent is false');
  });
}
