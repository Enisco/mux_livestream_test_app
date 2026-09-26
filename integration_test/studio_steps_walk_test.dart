import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/creator/repo/creator_dashboard_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// The studio checklist, against staging.
///
///   `flutter test integration_test/studio_steps_walk_test.dart -d DEVICE`
///
/// A widget test can prove the rows lead somewhere, but not that the keys the
/// app routes on are the keys the server actually sends. Every destination in
/// `_openStep` is keyed by string, so a key the app has never heard of falls
/// through to "not built yet" — which is exactly the bug that was reported.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await setupLocator();
  });

  testWidgets('every step the server sends is one the app can open', (
    tester,
  ) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'gt.steps.$stamp@mail.com';
    await getIt<AuthRepo>().register(
      firstName: 'Step',
      lastName: 'Probe',
      email: email,
      password: 'ProbePass123!',
    );
    await getIt<AuthRepo>().login(email: email, password: 'ProbePass123!');

    // Onboarding grants the creator role, but the session token was issued
    // before it — the follow-up PATCH is refused until the next sign-in.
    try {
      await getIt<CreatorRepo>().saveCreatorProfile(
        handle: 'steps$stamp',
        displayName: 'Step Probe',
        type: 'individual',
        categorySlugs: const ['sermons'],
      );
    } catch (_) {
      // The channel exists either way; only the polish PATCH can fail here.
    }
    await getIt<AuthRepo>().login(email: email, password: 'ProbePass123!');

    final creator = await getIt<CreatorRepo>().fetchAndCacheCreatorId();
    expect(creator, isNotNull);

    final steps = await CreatorDashboardRepo().fetchGettingStarted(creator!);
    expect(steps, isNotEmpty, reason: 'a new studio should have a checklist');

    // Every key must have a title the app knows...
    for (final step in steps) {
      expect(
        AppStrings.studioStepTitles.containsKey(step.key),
        isTrue,
        reason: '${step.key} has no title, so the row would show its raw key',
      );
      // ...and a destination, rather than falling through to "not built yet".
      expect(
        const {
          'complete_profile',
          'publish_first_content',
          'go_live',
          'invite_team',
          'setup_giving',
        }.contains(step.key),
        isTrue,
        reason: '${step.key} has no destination in _openStep',
      );
    }

    // And a brand-new studio genuinely has work left, which is what makes
    // the card appear at all.
    final applicable = steps.where((s) => s.applicable);
    expect(applicable, isNotEmpty);
    expect(applicable.any((s) => !s.complete), isTrue);
  });
}
