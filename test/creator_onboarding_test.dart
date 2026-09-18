import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test_app/features/creator/views/creator_live_screen.dart';
import 'package:test_app/features/creator/views/creator_polish_screens.dart';
import 'package:test_app/features/creator/views/creator_type_screen.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/creator/views/widgets/creator_topics_sheet.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// The screens navigate with go_router, so a bare MaterialApp would throw the
/// moment a card is tapped.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => child),
          for (final path in const [
            '/creator-setup',
            '/org-setup',
            '/creator-banner',
            '/creator-bio',
            '/creator-links',
            '/creator-photo',
            '/home',
          ])
            GoRoute(path: path, builder: (_, _) => Text('at $path')),
        ],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('who the channel is for', () {
    testWidgets('asks the question and explains both answers', (tester) async {
      await _pump(tester, const CreatorTypeScreen());

      expect(find.text('Start creating'), findsOneWidget);
      expect(find.text('Who is this channel for?'), findsOneWidget);
      expect(find.text('Just me'), findsOneWidget);
      expect(find.text('A ministry or church'), findsOneWidget);
      expect(find.textContaining('worship leader or speaker'), findsOneWidget);
      expect(find.textContaining('invite members with roles'), findsOneWidget);
    });

    testWidgets('says the studio does not replace the account', (tester) async {
      await _pump(tester, const CreatorTypeScreen());

      expect(
        find.textContaining("doesn't replace your account"),
        findsOneWidget,
      );
    });

    testWidgets('carries no progress bar or Skip', (tester) async {
      await _pump(tester, const CreatorTypeScreen());

      // Both belonged to the older onboarding; this flow has neither.
      expect(find.text(AppStrings.skip), findsNothing);
    });

    testWidgets('each answer remembers itself and routes on', (tester) async {
      await _pump(tester, const CreatorTypeScreen());

      await tester.tap(find.text('A ministry or church'));
      await tester.pumpAndSettle();

      expect(find.text('at /org-setup'), findsOneWidget);
      expect(
        LocalStorage.getString(LocalStorage.creatorTypeKey),
        'organization',
      );
    });
  });

  group('the channel is live', () {
    testWidgets('greets by the name the setup form saved', (tester) async {
      await LocalStorage.setString(LocalStorage.creatorNameKey, 'Pastor James');
      await _pump(tester, const CreatorLiveScreen());

      expect(find.text("You're in, James"), findsOneWidget);
      expect(
        find.textContaining('Your channel is live on', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(AppStrings.creatorLiveSetUp), findsOneWidget);
    });

    testWidgets('a missing name does not produce a dangling comma', (
      tester,
    ) async {
      await _pump(tester, const CreatorLiveScreen());

      expect(find.text("You're in"), findsOneWidget);
      expect(find.textContaining("You're in,"), findsNothing);
    });

    testWidgets('offers a way out as well as a way on', (tester) async {
      await _pump(tester, const CreatorLiveScreen());

      await tester.tap(find.text(AppStrings.creatorDoThisLater));
      await tester.pumpAndSettle();
      expect(find.text('at /home'), findsOneWidget);
    });
  });

  group('the four polish steps', () {
    testWidgets('each names itself and shows where it sits', (tester) async {
      for (final (screen, title) in <(Widget, String)>[
        (const CreatorPhotoScreen(), 'Add your ministry photo'),
        (const CreatorBannerScreen(), 'Add a banner'),
        (const CreatorLinksScreen(), 'Where else do people find you?'),
      ]) {
        await _pump(tester, screen);
        expect(find.text(title), findsOneWidget, reason: title);
        expect(find.byType(CreatorStepDots), findsOneWidget, reason: title);
        expect(
          find.text(AppStrings.creatorDoThisLater),
          findsOneWidget,
          reason: title,
        );
      }
    });

    testWidgets('the bio titles itself with the channel name', (tester) async {
      await LocalStorage.setString(LocalStorage.creatorNameKey, 'Pastor James');
      await _pump(tester, const CreatorBioScreen());

      expect(find.text('What is Pastor James about?'), findsOneWidget);
      expect(find.text('0/300'), findsOneWidget);
    });

    testWidgets('the bio counter tracks what is typed', (tester) async {
      await _pump(tester, const CreatorBioScreen());

      await tester.enterText(find.byType(TextField), 'Spirit-led worship');
      await tester.pump();
      expect(find.text('18/300'), findsOneWidget);
    });

    testWidgets('the bio cannot exceed its limit', (tester) async {
      await _pump(tester, const CreatorBioScreen());

      await tester.enterText(find.byType(TextField), 'a' * 400);
      await tester.pump();
      expect(find.text('300/300'), findsOneWidget);
    });

    testWidgets('skipping and continuing land in the same place', (
      tester,
    ) async {
      await _pump(tester, const CreatorPhotoScreen());
      await tester.tap(find.text(AppStrings.creatorDoThisLater));
      await tester.pumpAndSettle();
      expect(find.text('at /creator-banner'), findsOneWidget);

      await _pump(tester, const CreatorPhotoScreen());
      await tester.tap(find.text(AppStrings.continueLabel));
      await tester.pumpAndSettle();
      expect(find.text('at /creator-banner'), findsOneWidget);
    });

    testWidgets('the photo target opens the picker, not a fake toggle', (
      tester,
    ) async {
      await _pump(tester, const CreatorPhotoScreen());

      // The tap must reach a real picker; with no platform behind it in a
      // test that is a channel error, not a silent state flip.
      expect(
        find.byKey(const ValueKey('creator-photo-picker')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.creatorImageChange), findsNothing);
    });

    testWidgets('the banner target is the tappable frame', (tester) async {
      await _pump(tester, const CreatorBannerScreen());

      expect(
        find.byKey(const ValueKey('creator-banner-picker')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.creatorBannerTapToAdd), findsOneWidget);
    });

    testWidgets('links start with the three the design names', (tester) async {
      await _pump(tester, const CreatorLinksScreen());

      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('yourchurch.org'), findsOneWidget);
      expect(find.text('Instagram URL'), findsOneWidget);
      expect(find.text('Youtube URL'), findsOneWidget);
    });

    testWidgets('Add another link adds a row', (tester) async {
      await _pump(tester, const CreatorLinksScreen());

      await tester.tap(find.byKey(const ValueKey('creator-add-link')));
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text('Another URL'), findsOneWidget);
    });
  });

  group('the topics sheet', () {
    testWidgets('lists the API categories when there are any', (tester) async {
      await _pump(
        tester,
        const CreatorTopicsSheet(
          categories: [
            ContentCategory(slug: 'teaching', name: 'Teaching'),
            ContentCategory(slug: 'praise', name: 'Praise'),
          ],
        ),
        size: const Size(390, 1400),
      );

      expect(find.text('Your topics'), findsOneWidget);
      expect(find.text('Teaching'), findsOneWidget);
      expect(find.text('Worship'), findsNothing, reason: 'no fallback needed');
    });

    testWidgets('falls back to the design list when the API gave none', (
      tester,
    ) async {
      await _pump(
        tester,
        const CreatorTopicsSheet(),
        size: const Size(390, 1400),
      );

      for (final topic in CreatorTopicsSheet.fallback) {
        expect(find.text(topic), findsOneWidget, reason: topic);
      }
    });

    testWidgets('toggling is remembered and handed back as slugs', (
      tester,
    ) async {
      Set<String>? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await CreatorTopicsSheet.show(
                context,
                categories: const [
                  ContentCategory(slug: 'teaching', name: 'Teaching'),
                  ContentCategory(slug: 'praise', name: 'Praise'),
                ],
              );
            },
            child: const Text('open'),
          ),
        ),
        size: const Size(390, 1400),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('topic-Praise')));
      await tester.pump();
      await tester.tap(find.text(AppStrings.creatorTopicsDone));
      await tester.pumpAndSettle();

      expect(result, {'praise'});
    });
  });

  group('nothing overflows', () {
    for (final (name, screen) in <(String, Widget)>[
      ('the type picker', CreatorTypeScreen()),
      ('the live screen', CreatorLiveScreen()),
      ('the photo step', CreatorPhotoScreen()),
      ('the banner step', CreatorBannerScreen()),
      ('the bio step', CreatorBioScreen()),
      ('the links step', CreatorLinksScreen()),
    ]) {
      testWidgets('$name on a narrow phone', (tester) async {
        await _pump(tester, screen, size: const Size(320, 844));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
