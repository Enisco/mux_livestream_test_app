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
import 'package:test_app/features/creator/views/creator_live_screen.dart';
import 'package:test_app/features/creator/views/creator_polish_screens.dart';
import 'package:test_app/features/creator/views/creator_profile_setup_screen.dart';
import 'package:test_app/features/creator/views/creator_type_screen.dart';
import 'package:test_app/features/creator/views/organization_profile_setup_screen.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_theme.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Walks creator onboarding on a device, against the real staging API.
///
/// This is the only test that proves the flow end to end: the widget tests
/// stub navigation and never call the API, so a screen can pass them while
/// creating no channel at all — which is exactly what organisation setup was
/// doing.
///
///   `flutter test integration_test/creator_onboarding_walk_test.dart -d DEVICE`
///
/// It registers a throwaway staging account per run. Those accumulate; clean
/// them up when you are done.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await setupLocator();
  });

  /// A fresh signed-in account, so each walk starts with no channel.
  Future<String> signIn() async {
    final email = 'gt.walk.${DateTime.now().millisecondsSinceEpoch}@mail.com';
    await getIt<AuthRepo>().register(
      firstName: 'Pastor',
      lastName: 'James',
      email: email,
      password: 'ProbePass123!',
    );
    await getIt<AuthRepo>().login(email: email, password: 'ProbePass123!');
    await LocalStorage.remove(LocalStorage.creatorIdKey);
    return email;
  }

  late GoRouter router;

  Future<void> pumpFlow(WidgetTester tester, {required String at}) async {
    // Built once and held: creating the router inside the builder would mint
    // a new one on every rebuild and snap the flow back to `initialLocation`.
    router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(
          path: AppRouter.creatorType,
          builder: (_, _) => const CreatorTypeScreen(),
        ),
        GoRoute(
          path: AppRouter.creatorSetup,
          builder: (_, _) => const CreatorProfileSetupScreen(),
        ),
        GoRoute(
          path: AppRouter.orgSetup,
          builder: (_, _) => const OrganizationProfileSetupScreen(),
        ),
        GoRoute(
          path: AppRouter.planSelection,
          builder: (_, _) => const Text('PLAN'),
        ),
        GoRoute(
          path: AppRouter.creatorLive,
          builder: (_, _) => const CreatorLiveScreen(),
        ),
        GoRoute(
          path: AppRouter.creatorBio,
          builder: (_, _) => const CreatorBioScreen(),
        ),
        GoRoute(
          path: AppRouter.creatorLinks,
          builder: (_, _) => const Text('LINKS'),
        ),
        GoRoute(path: AppRouter.home, builder: (_, _) => const Text('HOME')),
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
    await tester.pumpAndSettle();
  }

  /// Opens the topics sheet and takes the first category. Both forms now
  /// refuse to submit without one.
  Future<void> pickFirstCategory(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.mostlyShareHint));
    await tester.pumpAndSettle(const Duration(seconds: 8));
    final topic = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('topic-'),
    );
    expect(topic, findsWidgets, reason: 'the sheet must offer topics');
    await tester.tap(topic.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.creatorTopicsDone));
    await tester.pumpAndSettle();
  }

  testWidgets('an individual can create a channel and reach the plan step', (
    tester,
  ) async {
    await signIn();
    await pumpFlow(tester, at: AppRouter.creatorType);

    expect(find.text(AppStrings.creatorTypeTitle), findsOneWidget);
    await tester.tap(find.text(AppStrings.creatorTypeIndividual));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.creatorSetupTitle), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Pastor James ${DateTime.now().millisecondsSinceEpoch}',
    );
    await tester.pumpAndSettle();
    await pickFirstCategory(tester);

    await tester.tap(find.text(AppStrings.creatorSetupProceed));
    // The handle check debounces and the channel is created over the network.
    await tester.pumpAndSettle(const Duration(seconds: 12));

    expect(
      LocalStorage.creatorId,
      isNotNull,
      reason: 'the channel must exist before the plan step is reached',
    );
    expect(find.text('PLAN'), findsOneWidget);
  });

  testWidgets('the bio typed on its step actually reaches the server', (
    tester,
  ) async {
    await signIn();
    await pumpFlow(tester, at: AppRouter.creatorType);

    await tester.tap(find.text(AppStrings.creatorTypeIndividual));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Bio Walk ${DateTime.now().millisecondsSinceEpoch}',
    );
    await tester.pumpAndSettle();
    await pickFirstCategory(tester);
    await tester.tap(find.text(AppStrings.creatorSetupProceed));
    await tester.pumpAndSettle(const Duration(seconds: 12));

    final creatorId = LocalStorage.creatorId;
    expect(creatorId, isNotNull);

    await pumpFlow(tester, at: AppRouter.creatorBio);
    const bio = 'Spirit-led worship and teaching for our city.';
    await tester.enterText(find.byType(TextField), bio);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.continueLabel));
    await tester.pumpAndSettle(const Duration(seconds: 12));

    expect(find.text('LINKS'), findsOneWidget, reason: 'it moved on');

    final channel = await getIt<CreatorRepo>().fetchChannel(creatorId!);
    expect(channel?['bio'], bio, reason: 'the bio must have been written');
  });

  testWidgets('an organisation can create a channel', (tester) async {
    await signIn();
    await pumpFlow(tester, at: AppRouter.creatorType);

    await tester.tap(find.text(AppStrings.creatorTypeOrganization));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.creatorSetupTitle), findsOneWidget);

    // Fields are addressed by position: the org block is a fixed order and
    // finding by label means walking the whole scroll view.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Grace Community $stamp');
    await tester.pumpAndSettle();

    await pickFirstCategory(tester);

    await tester.enterText(fields.at(2), 'hello@grace$stamp.org');
    await tester.enterText(fields.at(3), '+2348012345678');
    await tester.enterText(fields.at(4), 'A church in Lagos.');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(AppStrings.orgCountryHint),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(AppStrings.orgCountryHint));
    await tester.pumpAndSettle();
    // The sheet lists 238 countries, so it is searched rather than scrolled.
    await tester.enterText(find.byType(TextField).last, 'Nigeria');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nigeria').last);
    await tester.pumpAndSettle();

    await tester.enterText(fields.at(5), 'Lagos');
    await tester.enterText(fields.at(6), 'Ikeja');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(AppStrings.creatorSetupProceed),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(AppStrings.creatorSetupProceed));
    await tester.pumpAndSettle(const Duration(seconds: 15));

    expect(
      LocalStorage.creatorId,
      isNotNull,
      reason: 'an organisation must be able to create a channel',
    );
    expect(find.text('PLAN'), findsOneWidget);

    final channel = await getIt<CreatorRepo>().fetchChannel(
      LocalStorage.creatorId!,
    );
    expect(channel?['type'], 'organization');
  });

  testWidgets('a form with no category does not reach the server', (
    tester,
  ) async {
    await signIn();
    await pumpFlow(tester, at: AppRouter.creatorType);

    await tester.tap(find.text(AppStrings.creatorTypeIndividual));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'No Category Channel');
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.creatorSetupProceed));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text(AppStrings.creatorCategoryMin1), findsOneWidget);
    expect(find.text('PLAN'), findsNothing);
    expect(LocalStorage.creatorId, isNull);
  });
}
