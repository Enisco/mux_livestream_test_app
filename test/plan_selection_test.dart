import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/features/creator/views/plan_selection_screen.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// The plan step, with the catalogue unreachable — which is its real state
/// while `GET /v1/payment/saas/plans` answers 500.
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
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
  await tester.pump();
}

/// Stands in for a catalogue that cannot be reached — `GET
/// /v1/payment/saas/plans` answers 500 on staging.
class _UnreachableCatalogue extends CreatorRepo {
  @override
  Future<List<SaasPlan>> fetchPlans({
    required BillingSubject billingSubject,
    required String currency,
    int page = 1,
    int limit = 12,
  }) async => throw Exception('catalogue unavailable');
}

/// Fails the test loudly if a Free selection ever starts a checkout.
class _NeverCheckout extends CheckoutHandoffService {
  @override
  Future<HandoffResult> start({
    required String creatorId,
    String? planTier,
  }) async => fail('Free must not start a checkout');
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    // The screen resolves both of these on build. The catalogue stands in for
    // the 500 staging currently returns, which is the state under test.
    await getIt.reset();
    getIt.registerSingleton<CreatorRepo>(_UnreachableCatalogue());
    getIt.registerSingleton<CheckoutHandoffService>(_NeverCheckout());
  });

  testWidgets('Free is offered as a plan in its own right', (tester) async {
    await _pump(tester);

    expect(find.text(AppStrings.planFree), findsOneWidget);
    expect(find.text(AppStrings.planBasic), findsOneWidget);
    expect(find.text(AppStrings.planPro), findsOneWidget);
    expect(find.text(AppStrings.planEnterprise), findsOneWidget);
  });

  testWidgets('Free is what the button acts on until told otherwise', (
    tester,
  ) async {
    await _pump(tester);

    // Pro used to be the default, which meant an unthinking tap started a
    // paid checkout.
    expect(find.text(AppStrings.continueWithFree), findsOneWidget);
  });

  testWidgets('the button names whichever tier is chosen', (tester) async {
    await _pump(tester);

    await tester.tap(find.text(AppStrings.planPro));
    await tester.pump();
    expect(
      find.text(AppStrings.continueWithTier(AppStrings.planPro)),
      findsOneWidget,
    );

    await tester.tap(find.text(AppStrings.planFree));
    await tester.pump();
    expect(find.text(AppStrings.continueWithFree), findsOneWidget);
  });

  testWidgets('choosing Free skips checkout entirely', (tester) async {
    await LocalStorage.setString(LocalStorage.creatorIdKey, 'creator-1');
    await _pump(tester);

    await tester.tap(find.text(AppStrings.continueWithFree));
    await tester.pumpAndSettle();

    expect(find.text('at ${AppRouter.creatorLive}'), findsOneWidget);
    expect(find.text('at ${AppRouter.checkoutStatus}'), findsNothing);
  });

  testWidgets('a studio with no channel is not sent to checkout', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text(AppStrings.continueWithFree));
    await tester.pumpAndSettle();

    expect(find.text('at ${AppRouter.home}'), findsOneWidget);
  });

  group('the currency symbol', () {
    test('covers the markets the app prices in', () {
      expect(AppStrings.currencySymbolFor('NGN'), '₦');
      expect(AppStrings.currencySymbolFor('USD'), r'$');
      expect(AppStrings.currencySymbolFor('GBP'), '£');
    });

    test('an unknown currency prints its code rather than a wrong sign', () {
      expect(AppStrings.currencySymbolFor('JPY'), 'JPY ');
    });
  });
}
