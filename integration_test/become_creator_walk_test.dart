import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/views/creator_type_screen.dart';
import 'package:test_app/features/creator/views/studio_shell.dart';
import 'package:test_app/features/profile/views/profile_screen.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_theme.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Switching between the member app and the studio, against staging.
///
///   `flutter test integration_test/become_creator_walk_test.dart -d DEVICE`
///
/// The point of these is that the two sides agree about whether this reader
/// has a channel. A widget test cannot show that: the answer comes from
/// `GET /v1/creator/profile`, which answers **404** for a reader with none
/// and is the only thing that tells "no channel" apart from "the request
/// failed".
///
/// Registers a throwaway staging account per run; clean them up when done.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await setupLocator();
  });

  /// A signed-in reader with no channel at all.
  Future<String> signInAsViewer() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'gt.switch.$stamp@mail.com';
    await getIt<AuthRepo>().register(
      firstName: 'Ada',
      lastName: 'Member',
      email: email,
      password: 'ProbePass123!',
    );
    await getIt<AuthRepo>().login(email: email, password: 'ProbePass123!');
    // Nothing cached: this is a reader the app knows nothing about yet.
    await LocalStorage.remove(LocalStorage.creatorIdKey);
    return email;
  }

  Future<void> giveThemAChannel(String stamp) async {
    await getIt<CreatorRepo>().saveCreatorProfile(
      handle: 'switch$stamp',
      displayName: 'Grace Chapel',
      type: 'individual',
      categorySlugs: const ['sermons'],
    );
  }

  /// The You tab, with the routes the studio block leads to.
  Future<GoRouter> pumpProfile(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: AppRouter.creatorType,
          builder: (_, _) => const CreatorTypeScreen(),
        ),
        GoRoute(path: AppRouter.studio, builder: (_, _) => const StudioShell()),
        GoRoute(
          path: AppRouter.home,
          builder: (_, _) => const Text('WATCHING'),
        ),
      ],
    );
    await tester.pumpWidget(
      SizingBuilder(
        baseSize: const Size(390, 844),
        respectSystemFontScale: false,
        builder: (context) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 10));
    return router;
  }

  testWidgets('a reader with no channel is invited to start one', (
    tester,
  ) async {
    await signInAsViewer();
    await pumpProfile(tester);

    expect(
      find.byKey(const ValueKey('profile-become-creator')),
      findsOneWidget,
    );
    // And is not shown a studio they do not have.
    expect(find.byKey(const ValueKey('profile-open-studio')), findsNothing);
  });

  testWidgets('tapping it opens creator onboarding', (tester) async {
    await signInAsViewer();
    await pumpProfile(tester);

    await tester.tap(find.byKey(const ValueKey('profile-become-creator')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Pushed rather than gone to, so the reader can back out and land on
    // the You tab again — which is why the block refreshes on return.
    expect(find.byType(CreatorTypeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-become-creator')), findsNothing);
  });

  testWidgets('a reader who has a channel is offered their studio instead', (
    tester,
  ) async {
    final stamp = '${DateTime.now().millisecondsSinceEpoch}';
    await signInAsViewer();
    await giveThemAChannel(stamp);
    // Forget it again: the app should find the channel from the server, the
    // way it would on a phone the reader has just signed in on.
    await LocalStorage.remove(LocalStorage.creatorIdKey);

    await pumpProfile(tester);

    expect(find.byKey(const ValueKey('profile-open-studio')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-become-creator')), findsNothing);
  });

  testWidgets('the studio opens, and leads back to watching', (tester) async {
    final stamp = '${DateTime.now().millisecondsSinceEpoch}';
    await signInAsViewer();
    await giveThemAChannel(stamp);
    final router = await pumpProfile(tester);

    await tester.tap(find.byKey(const ValueKey('profile-open-studio')));
    await tester.pumpAndSettle(const Duration(seconds: 15));
    expect(find.byType(StudioShell), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRouter.studio,
    );

    // "Your studios" carries the way back out.
    await tester.tap(find.byKey(const ValueKey('studio-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.studiosBackToWatching));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('WATCHING'), findsOneWidget);
    expect(find.byType(StudioShell), findsNothing);
  });
}
