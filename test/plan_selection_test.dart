import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/features/creator/views/plan_selection_screen.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// Stands in for the handoff, which is the screen's only collaborator now
/// that the plan catalogue lives on the web surface.
class _FakeHandoff extends CheckoutHandoffService {
  _FakeHandoff({this.available = true, this.outcome = HandoffOutcome.launched});

  final bool available;
  final HandoffOutcome outcome;
  int starts = 0;

  @override
  Future<bool> canPurchaseSubscription() async => available;

  @override
  Future<HandoffResult> start({
    required String creatorId,
    String? planTier,
  }) async {
    starts++;
    // The plan is never named by mobile: the web surface chooses it.
    expect(planTier, isNull);
    return HandoffResult(outcome, sessionId: 'session-1');
  }
}

Future<void> _pump(WidgetTester tester, _FakeHandoff handoff) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await getIt.reset();
  getIt.registerSingleton<CheckoutHandoffService>(handoff);

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PlanSelectionScreen()),
          for (final path in const [
            AppRouter.creatorLive,
            AppRouter.home,
            AppRouter.checkoutStatus,
          ])
            GoRoute(path: path, builder: (_, _) => Text('at $path')),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setString(LocalStorage.creatorIdKey, 'creator-1');
  });

  testWidgets('no plan catalogue is shown — the web surface owns it', (
    tester,
  ) async {
    await _pump(tester, _FakeHandoff());

    for (final tier in const ['Basic', 'Pro', 'Enterprise']) {
      expect(find.text(tier), findsNothing, reason: tier);
    }
    expect(find.text(AppStrings.compareEverything), findsNothing);
  });

  testWidgets('both ways forward are offered when purchase is allowed', (
    tester,
  ) async {
    await _pump(tester, _FakeHandoff());

    expect(find.text(AppStrings.planChoose), findsOneWidget);
    expect(find.text(AppStrings.continueWithFree), findsOneWidget);
    expect(find.textContaining('secure browser'), findsOneWidget);
  });

  testWidgets('the purchase action is hidden where it cannot be sold', (
    tester,
  ) async {
    // The guide requires hiding it, not disabling it.
    await _pump(tester, _FakeHandoff(available: false));

    expect(find.text(AppStrings.planChoose), findsNothing);
    expect(find.text(AppStrings.continueWithFree), findsOneWidget);
    expect(find.text(AppStrings.planUnavailableHere), findsOneWidget);
  });

  testWidgets('Free skips the handoff entirely', (tester) async {
    final handoff = _FakeHandoff();
    await _pump(tester, handoff);

    await tester.tap(find.byKey(const ValueKey('continue-free')));
    await tester.pumpAndSettle();

    expect(find.text('at ${AppRouter.creatorLive}'), findsOneWidget);
    expect(handoff.starts, 0);
  });

  testWidgets('choosing a paid plan hands off and then watches the session', (
    tester,
  ) async {
    final handoff = _FakeHandoff();
    await _pump(tester, handoff);

    await tester.tap(find.byKey(const ValueKey('choose-plan')));
    await tester.pumpAndSettle();

    expect(handoff.starts, 1);
    expect(find.text('at ${AppRouter.checkoutStatus}'), findsOneWidget);
  });

  testWidgets('a resumed session is watched rather than restarted', (
    tester,
  ) async {
    final handoff = _FakeHandoff(outcome: HandoffOutcome.alreadyActive);
    await _pump(tester, handoff);

    await tester.tap(find.byKey(const ValueKey('choose-plan')));
    await tester.pumpAndSettle();

    expect(find.text('at ${AppRouter.checkoutStatus}'), findsOneWidget);
  });

  testWidgets('an unavailable storefront hides the action after the fact', (
    tester,
  ) async {
    final handoff = _FakeHandoff(outcome: HandoffOutcome.unavailable);
    await _pump(tester, handoff);

    await tester.tap(find.byKey(const ValueKey('choose-plan')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.planChoose), findsNothing);
    expect(find.text('at ${AppRouter.checkoutStatus}'), findsNothing);
  });

  testWidgets('a creator without a channel is not handed off', (tester) async {
    await LocalStorage.remove(LocalStorage.creatorIdKey);
    final handoff = _FakeHandoff();
    await _pump(tester, handoff);

    await tester.tap(find.byKey(const ValueKey('choose-plan')));
    await tester.pumpAndSettle();

    expect(handoff.starts, 0);
    expect(find.text('at ${AppRouter.home}'), findsOneWidget);
  });
}
