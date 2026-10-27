import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/views/giving_earnings_screen.dart';
import 'package:test_app/features/creator/views/giving_funds_screen.dart';
import 'package:test_app/features/creator/views/giving_kyc_screen.dart';
import 'package:test_app/features/creator/views/giving_rail_screen.dart';
import 'package:test_app/features/creator/views/giving_screen.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// The creator's side of Giving.
///
/// Four rules from `creator-giving-and-recipient-integration-guide.md` carry
/// real money behind them, and each has a test here that fails if the client
/// starts guessing instead of reading:
///
/// - **Only an active rail may say gifts are being accepted.** Anything
///   short of it says the opposite, however far along it looks.
/// - **A balance the provider could not report is not a zero.** It is said
///   out loud, because a zero reads as "your money is gone".
/// - **A direct rail has no withdrawal at all**, and a provider-held one
///   with a request already in flight must not offer a second.
/// - **Settlement currencies are never added together**, which is why there
///   is no total across buckets anywhere on these screens.
///
/// The shapes below were probed against staging on 2026-10-26, including the
/// two refusals a new studio actually hits: `{application: null}` before
/// anything is applied for, and *"Giving application not found"* from every
/// reporting route until one exists.
class _FakeApi implements ApiService {
  _FakeApi({
    this.application,
    this.summary,
    this.transactions = const [],
    this.transactionPages,
    this.funds,
    this.optionItems,
    this.failReads = false,
    this.reportingRefuses = false,
  });

  /// Null models `{application: null}` — nothing applied for.
  final Map<String, dynamic>? application;

  final Map<String, dynamic>? summary;
  final List<Map<String, dynamic>> transactions;

  /// Successive pages of `transactions`, so a page that holds no refunds can
  /// be followed by one that does.
  final List<List<Map<String, dynamic>>>? transactionPages;

  final Map<String, dynamic>? funds;
  final List<Map<String, dynamic>>? optionItems;
  final bool failReads;

  /// Models the pre-application refusal every reporting route gives.
  final bool reportingRefuses;

  final List<String> got = [];
  final List<(String, Object?)> posted = [];
  final List<(String, Object?)> patched = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    got.add(path);
    if (failReads) throw _boom(path);
    if (path == '/v1/payment/earnings/application') {
      return _ok(path, {'application': application});
    }
    if (path == '/v1/payment/earnings/application/options') {
      return _ok(path, {
        'termsVersion': '2026-07-15',
        'items': optionItems ?? _defaultOptions,
      });
    }
    if (path == '/v1/payment/giving/funds') {
      return _ok(path, funds ?? _defaultFunds);
    }
    if (reportingRefuses) throw _boom(path, status: 404);
    if (path == '/v1/payment/earnings/summary') {
      return _ok(path, summary ?? _emptySummary);
    }
    if (transactionPages case final pages?) {
      final index =
          int.tryParse(queryParameters?['cursor'] as String? ?? '') ?? 0;
      return _ok(path, {
        'items': index < pages.length ? pages[index] : const [],
        'nextCursor': index + 1 < pages.length ? '${index + 1}' : null,
      });
    }
    return _ok(path, {'items': transactions, 'nextCursor': null});
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
    Map<String, dynamic>? queryParameters,
  }) async {
    posted.add((path, data));
    if (path == '/v1/auth/step-up/challenges') {
      return _ok(path, {
        'challengeId': 'ch-1',
        'expiresAt': '2026-10-26T22:00:00.000Z',
        'delivery': 'email',
      });
    }
    if (path.endsWith('/verify')) return _ok(path, {'grantToken': 'grant-1'});
    if (path == '/v1/payment/earnings/application') {
      return _ok(path, {'application': _draftApplication});
    }
    if (path == '/v1/payment/giving/funds') {
      return _ok(path, {
        'fund': {'id': 'f-2', 'slug': 'building', 'name': 'Building Fund'},
      });
    }
    return _ok(path, const <String, dynamic>{});
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    patched.add((path, data));
    return _ok(path, {'application': application});
  }

  DioException _boom(String path, {int status = 500}) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response(
      requestOptions: RequestOptions(path: path),
      statusCode: status,
    ),
  );

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

// ---------------------------------------------------------------------------
// Fixtures, as staging answers them
// ---------------------------------------------------------------------------

const _defaultOptions = [
  {
    'policyId': 'p-khaime',
    'policyVersion': 3,
    'paymentProvider': 'khaime',
    'custodyMode': 'provider_held',
    'holdDays': 0,
    'countryCode': 'NG',
    'creatorType': 'individual',
    'legalClassification': 'INDIVIDUAL',
    'settlementCurrency': 'NGN',
    'allowedAccountOwnership': ['legal_recipient'],
    'platformReviewRequired': true,
  },
  {
    'policyId': 'p-paystack',
    'policyVersion': 3,
    'paymentProvider': 'paystack',
    'custodyMode': 'direct',
    'holdDays': null,
    'countryCode': 'NG',
    'creatorType': 'individual',
    'legalClassification': 'INDIVIDUAL',
    'settlementCurrency': 'NGN',
    'allowedAccountOwnership': ['legal_recipient'],
    'platformReviewRequired': true,
  },
];

const _draftApplication = {
  'id': 'app-1',
  'creatorId': 'c-1',
  'creatorType': 'individual',
  'legalClassification': 'INDIVIDUAL',
  'legalRecipientName': 'James Nnamdi',
  'countryCode': 'NG',
  'status': 'draft',
  'kycStatus': 'not_started',
  'termsVersion': '2026-07-15',
  'termsAcceptedAt': '2026-10-19T09:00:00.000Z',
  'rails': <Map<String, dynamic>>[],
};

Map<String, dynamic> _applicationWith(
  List<Map<String, dynamic>> rails, {
  String status = 'active',
}) => {..._draftApplication, 'status': status, 'rails': rails};

const _activeKhaimeRail = {
  'id': 'rail-khaime',
  'paymentProvider': 'khaime',
  'custodyMode': 'provider_held',
  'holdDays': 0,
  'countryCode': 'NG',
  'settlementCurrency': 'NGN',
  'status': 'active',
  'kycStatus': 'verified',
  'enabled': true,
  'priority': 10,
};

const _reviewingPaystackRail = {
  'id': 'rail-paystack',
  'paymentProvider': 'paystack',
  'custodyMode': 'direct',
  'countryCode': 'NG',
  'settlementCurrency': 'NGN',
  'status': 'platform_review',
  'enabled': true,
  'priority': 20,
};

const _emptySummary = {
  'dataSource': 'provider_reported',
  'activeSettlementCurrency': null,
  'range': {'from': null, 'to': null, 'fundId': null, 'railId': null},
  'giftCount': 0,
  'donorCount': 0,
  'totalsByCurrency': <Map<String, dynamic>>[],
  'fundsByRail': <Map<String, dynamic>>[],
};

const _defaultFunds = {
  'funds': [
    {
      'id': 'f-1',
      'creatorId': 'c-1',
      'slug': 'general',
      'name': 'General ministry support',
      'description': 'Support the creator’s general ministry.',
      'active': true,
      'giftCount': 8,
      'donorCount': 3,
      'totalsByCurrency': [
        {
          'total': {
            'currency': 'NGN',
            'amountMinor': 10000000,
            'amount': 100000,
          },
        },
      ],
    },
  ],
  'limits': {'maxFunds': 1, 'currentFunds': 1, 'canCreate': false},
};

/// A case with nothing listed on it, which is what a fresh rail answers.
const _noRequirements = {
  'applicationId': 'app-1',
  'railId': 'rail-khaime',
  'requirements': <Map<String, dynamic>>[],
};

Map<String, dynamic> _money(String currency, int minor, double major) => {
  'currency': currency,
  'amountMinor': minor,
  'amount': major,
};

// ---------------------------------------------------------------------------

const _dashboard = DashboardContext(
  creatorId: 'c-1',
  displayName: 'Impact Probe Chapel',
  handle: 'impactprobe',
  role: 'owner',
  capabilities: {},
);

Future<_FakeApi> _pumpGiving(
  WidgetTester tester, {
  Map<String, dynamic>? application,
  List<Map<String, dynamic>>? optionItems,
  bool failReads = false,
  Size size = const Size(390, 844),
}) async {
  final api = _FakeApi(
    application: application,
    optionItems: optionItems,
    failReads: failReads,
  );
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: GivingScreen(
          repo: GivingRepo(api: api),
          context: _dashboard,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<_FakeApi> _pumpEarnings(
  WidgetTester tester, {
  Map<String, dynamic>? summary,
  List<Map<String, dynamic>> transactions = const [],
  List<List<Map<String, dynamic>>>? transactionPages,
  Map<String, dynamic>? funds,
}) async {
  final api = _FakeApi(
    summary: summary,
    transactions: transactions,
    transactionPages: transactionPages,
    funds: funds,
  );
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: GivingEarningsScreen(
          creatorId: 'c-1',
          repo: GivingRepo(api: api),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<_FakeApi> _pumpFunds(
  WidgetTester tester, {
  Map<String, dynamic>? funds,
  bool reportingRefuses = false,
}) async {
  final api = _FakeApi(
    summary: _emptySummary,
    funds: funds,
    reportingRefuses: reportingRefuses,
  );
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: GivingFundsScreen(
          creatorId: 'c-1',
          repo: GivingRepo(api: api),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// Bring something below the fold into view.
///
/// These screens are long lists, so anything past the first screenful is
/// simply not built until it is scrolled to.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRail(
  WidgetTester tester, {
  Map<String, dynamic> rail = _activeKhaimeRail,
  Map<String, dynamic> requirements = _noRequirements,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = _RequirementsApi(requirements, rail);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: GivingRailScreen(
          creatorId: 'c-1',
          rail: GivingRail.fromJson(rail),
          application: GivingApplication.fromJson(_applicationWith([rail])),
          repo: GivingRepo(api: api),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Answers the rail screen's two reads and nothing else.
class _RequirementsApi extends _FakeApi {
  _RequirementsApi(this.requirements, Map<String, dynamic> rail)
    : super(application: _applicationWith([rail]));

  final Map<String, dynamic> requirements;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/v1/payment/earnings/application/requirements') {
      return _ok(path, requirements);
    }
    return super.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  group('money', () {
    test('formats the server\'s major units, and never rebuilds them', () {
      const money = Money(currency: 'NGN', amountMinor: 3000000, amount: 30000);
      expect(money.display, '₦30,000.00');
      // The minor figure is accounting's, and is deliberately not the source
      // of the printed one.
      expect(money.amountMinor, 3000000);
    });

    test('knows the four settled currencies and prints the code otherwise', () {
      expect(
        const Money(currency: 'USD', amountMinor: 10000, amount: 100).display,
        r'$100.00',
      );
      expect(
        const Money(currency: 'GBP', amountMinor: 50, amount: 0.5).display,
        '£0.50',
      );
      expect(
        const Money(currency: 'KES', amountMinor: 100, amount: 1).display,
        'KES 1.00',
      );
    });

    test('a reversal keeps its minus in front of the symbol', () {
      // "₦-30,000.00" reads as a typo. The sign belongs before the symbol,
      // where it reads as money going the other way.
      const refund = Money(
        currency: 'NGN',
        amountMinor: -3000000,
        amount: -30000,
      );
      expect(refund.display, '-₦30,000.00');
    });

    test('a missing money object stays null rather than becoming zero', () {
      expect(Money.maybe(null), isNull);
      expect(Money.maybe(_money('NGN', 0, 0))?.isZero, isTrue);
    });
  });

  group('the application', () {
    test('a null application is "not requested", not a draft', () async {
      final api = _FakeApi();
      final application = await GivingRepo(api: api).fetchApplication('c-1');
      expect(application, isNull);
    });

    test('only an active, enabled rail is accepting gifts', () {
      final reviewing = GivingApplication.fromJson(
        _applicationWith([_reviewingPaystackRail], status: 'platform_review'),
      );
      expect(reviewing.isAcceptingGifts, isFalse);
      expect(reviewing.isUnderReview, isTrue);

      final live = GivingApplication.fromJson(
        _applicationWith([_activeKhaimeRail]),
      );
      expect(live.isAcceptingGifts, isTrue);

      // Active but switched out of routing accepts nothing.
      final paused = GivingApplication.fromJson(
        _applicationWith([
          {..._activeKhaimeRail, 'enabled': false},
        ]),
      );
      expect(paused.isAcceptingGifts, isFalse);
    });

    test('an unknown rail status does not break the tab', () {
      expect(
        RailStatus.from('something_new'),
        RailStatus.collectingInformation,
      );
      expect(RailStatus.from(null), RailStatus.collectingInformation);
    });

    test('a recipient is not offered a rail in another country', () {
      // The route answers with every combination policy allows the creator
      // type and does not narrow once an application fixes a country, so a
      // Nigerian recipient is still handed Stripe US. The rail's country is
      // the legal recipient's real country, so offering it would send them
      // into a verification they cannot pass. OPEN_ISSUES 38.
      final options = GivingOptions.fromJson({
        'termsVersion': '2026-07-15',
        'items': [
          ..._defaultOptions,
          {
            'policyId': 'p-stripe-us',
            'paymentProvider': 'stripe',
            'custodyMode': 'direct',
            'countryCode': 'US',
            'legalClassification': 'INDIVIDUAL',
            'settlementCurrency': 'USD',
          },
        ],
      });

      final offered = options.enrollable(
        classification: LegalClassification.individual,
        countryCode: 'NG',
      );
      expect(offered.map((o) => o.provider), [
        PaymentProvider.khaime,
        PaymentProvider.paystack,
      ]);

      // Without the country it is still there, which is what the server
      // actually returns.
      expect(
        options
            .enrollable(classification: LegalClassification.individual)
            .map((o) => o.provider),
        contains(PaymentProvider.stripe),
      );
    });

    test('options hide a provider that is already enrolled', () {
      final options = GivingOptions.fromJson({
        'termsVersion': '2026-07-15',
        'items': _defaultOptions,
      });
      final left = options.enrollable(
        classification: LegalClassification.individual,
        enrolled: const [PaymentProvider.khaime],
      );
      expect(left.map((o) => o.provider), [PaymentProvider.paystack]);
    });

    test('the account and the name it is held by are different facts', () {
      final rail = GivingRail.fromJson({
        ..._activeKhaimeRail,
        'settlementAccount': {
          'accountName': 'Opay Digital Services Limited',
          'holderName': 'Imran Abdulmalik',
          'accountNumberLast4': '7029',
        },
      });
      expect(rail.settlementAccountName, 'Opay Digital Services Limited');
      expect(rail.settlementAccountHolder, 'Imran Abdulmalik');
    });

    test('a zero hold is a real answer, not a missing one', () {
      final rail = GivingRail.fromJson(_activeKhaimeRail);
      expect(rail.holdDays, 0);
      expect(rail.custodyMode.isProviderHeld, isTrue);
    });
  });

  group('the Giving tab', () {
    testWidgets('an empty application offers to start one', (tester) async {
      final api = await _pumpGiving(tester);

      expect(find.text(AppStrings.givingNotStartedTitle), findsOneWidget);
      expect(find.text(AppStrings.givingStartApplication), findsOneWidget);
      // Nothing is asked for that cannot answer yet: the reporting routes
      // refuse outright before an application exists.
      expect(api.got, [
        '/v1/payment/earnings/application',
        '/v1/payment/earnings/application/options',
      ]);
    });

    testWidgets('a rail under review is not called accepting', (tester) async {
      await _pumpGiving(
        tester,
        application: _applicationWith([
          _reviewingPaystackRail,
        ], status: 'platform_review'),
      );

      expect(find.text(AppStrings.givingNotAccepting), findsOneWidget);
      expect(find.text(AppStrings.givingAccepting), findsNothing);
    });

    testWidgets('an active rail says gifts are being accepted', (tester) async {
      await _pumpGiving(
        tester,
        application: _applicationWith([_activeKhaimeRail]),
      );

      expect(find.text(AppStrings.givingAccepting), findsWidgets);
    });

    testWidgets('the terms version offered is the server\'s own', (
      tester,
    ) async {
      final api = await _pumpGiving(tester);
      await tester.tap(find.byKey(const ValueKey('giving-start')));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.givingTermsAccept('2026-07-15')),
        findsOneWidget,
      );
      expect(api.posted, isEmpty);
    });

    testWidgets('the application is not created until the terms are ticked', (
      tester,
    ) async {
      final api = await _pumpGiving(tester);
      await tester.tap(find.byKey(const ValueKey('giving-start')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('giving-save-recipient')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingTermsRequired), findsOneWidget);
      expect(api.posted, isEmpty);

      await tester.tap(find.byKey(const ValueKey('giving-accept-terms')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-save-recipient')));
      await tester.pumpAndSettle();

      expect(api.posted.first.$1, '/v1/payment/earnings/application');
      final body = api.posted.first.$2! as Map<String, dynamic>;
      expect(body['termsVersion'], '2026-07-15');
      expect(body['acceptTerms'], isTrue);
      expect(body['legalClassification'], 'INDIVIDUAL');
    });

    testWidgets('enrolling a rail goes through the emailed code', (
      tester,
    ) async {
      final api = await _pumpGiving(tester, application: _draftApplication);

      await tester.tap(find.byKey(const ValueKey('setup-khaime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-connect-securely')));
      await tester.pumpAndSettle();

      // The challenge goes out before the code is asked for, and the rail is
      // not enrolled until the grant comes back.
      expect(api.posted.first.$1, '/v1/auth/step-up/challenges');
      expect(
        (api.posted.first.$2! as Map<String, dynamic>)['operation'],
        'activate_givings',
      );
      expect(
        api.posted.map((p) => p.$1),
        isNot(contains('/v1/payment/earnings/rails')),
      );

      await tester.enterText(
        find.byKey(const ValueKey('giving-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('giving-verify')));
      await tester.pumpAndSettle();

      final enrol = api.posted.firstWhere(
        (p) => p.$1 == '/v1/payment/earnings/rails',
      );
      final body = enrol.$2! as Map<String, dynamic>;
      expect(body['paymentProvider'], 'khaime');
      expect(body['settlementCurrency'], 'NGN');
      // Spent immediately and never kept.
      expect(body['stepUpGrantToken'], 'grant-1');
    });

    testWidgets('a short code is refused before anything is sent', (
      tester,
    ) async {
      final api = await _pumpGiving(tester, application: _draftApplication);

      await tester.tap(find.byKey(const ValueKey('setup-khaime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-connect-securely')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('giving-code')), '12');
      await tester.tap(find.byKey(const ValueKey('giving-verify')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingCodeRequired), findsOneWidget);
      expect(
        api.posted.map((p) => p.$1),
        isNot(contains('/v1/auth/step-up/challenges/ch-1/verify')),
      );
    });

    testWidgets('a failed read offers a retry rather than an empty tab', (
      tester,
    ) async {
      await _pumpGiving(tester, failReads: true);

      expect(find.text(AppStrings.givingFailed), findsOneWidget);
      expect(find.text(AppStrings.givingNotStartedTitle), findsNothing);
    });

    testWidgets('the rails blurb is printed once, not twice', (tester) async {
      await _pumpGiving(
        tester,
        application: _applicationWith([_activeKhaimeRail]),
      );

      // It belongs under the section heading. The small print below the
      // cards used to repeat it word for word on the same screen.
      await _scrollTo(
        tester,
        find.textContaining(AppStrings.givingCurrencyNotProvider),
      );
      // Both are on screen together here, which is the whole point: the
      // policy line used to end with the section blurb word for word.
      expect(
        find.textContaining(AppStrings.givingRailsBody),
        findsOneWidget,
        reason: 'the section blurb must not be repeated in the policy line',
      );
    });

    testWidgets('a country reads as a country, not a code', (tester) async {
      await _pumpGiving(tester, application: _draftApplication);

      // The routes speak ISO codes; the design speaks country names.
      expect(find.textContaining('Nigeria'), findsWidgets);
      expect(find.textContaining('· NG ·'), findsNothing);
    });

    testWidgets('one enrolled rail offers no tie-break', (tester) async {
      await _pumpGiving(
        tester,
        application: _applicationWith([_activeKhaimeRail]),
      );

      expect(find.text(AppStrings.givingTieBreakTitle), findsNothing);
    });
  });

  group('earnings', () {
    testWidgets('a direct rail offers no withdrawal at all', (tester) async {
      await _pumpEarnings(
        tester,
        summary: {
          ..._emptySummary,
          'activeSettlementCurrency': 'NGN',
          'fundsByRail': [
            {
              'railId': 'rail-paystack',
              'paymentProvider': 'paystack',
              'custodyMode': 'direct',
              'settlementCurrency': 'NGN',
              'availability': 'provider_reported',
              'available': _money('NGN', 4000000, 40000),
            },
          ],
        },
      );

      expect(find.text(AppStrings.earningsNoWithdrawal), findsOneWidget);
      expect(
        find.byKey(const ValueKey('withdraw-rail-paystack')),
        findsNothing,
      );
    });

    testWidgets('a withdrawal already in flight disables a second', (
      tester,
    ) async {
      await _pumpEarnings(
        tester,
        summary: {
          ..._emptySummary,
          'activeSettlementCurrency': 'NGN',
          'fundsByRail': [
            {
              'railId': 'rail-khaime',
              'paymentProvider': 'khaime',
              'custodyMode': 'provider_held',
              'settlementCurrency': 'NGN',
              'availability': 'withdrawable',
              'available': _money('NGN', 7500000, 75000),
              'pendingPayout': _money('NGN', 2000000, 20000),
            },
          ],
        },
      );

      expect(find.text(AppStrings.earningsPayoutInFlight), findsOneWidget);
      expect(find.byKey(const ValueKey('withdraw-rail-khaime')), findsNothing);
      expect(
        find.text(AppStrings.earningsPayoutPending('₦20,000.00')),
        findsOneWidget,
      );
    });

    testWidgets('a studio with no rail is not told a provider failed', (
      tester,
    ) async {
      // Nothing has happened yet, which is not the same as a provider
      // failing to answer — and saying the latter would be a lie about the
      // provider as well as about the money.
      await _pumpEarnings(tester);

      expect(find.text(AppStrings.earningsNoRail), findsOneWidget);
      expect(find.text(AppStrings.earningsBalanceUnavailable), findsNothing);
      // Nor is an empty window drawn as a zero balance.
      expect(find.text('₦0.00'), findsNothing);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('a balance the provider could not report is said, not zeroed', (
      tester,
    ) async {
      await _pumpEarnings(
        tester,
        summary: {
          ..._emptySummary,
          'fundsByRail': [
            {
              'railId': 'rail-khaime',
              'paymentProvider': 'khaime',
              'custodyMode': 'provider_held',
              'settlementCurrency': 'NGN',
              'availability': 'not_available',
              'available': null,
            },
          ],
        },
      );

      expect(find.text(AppStrings.earningsBalanceUnavailable), findsWidgets);
      expect(find.text('₦0.00'), findsNothing);
    });

    testWidgets('a withdrawable rail offers the amount it actually has', (
      tester,
    ) async {
      await _pumpEarnings(
        tester,
        summary: {
          ..._emptySummary,
          'activeSettlementCurrency': 'NGN',
          'fundsByRail': [
            {
              'railId': 'rail-khaime',
              'paymentProvider': 'khaime',
              'custodyMode': 'provider_held',
              'settlementCurrency': 'NGN',
              'availability': 'withdrawable',
              'available': _money('NGN', 7500000, 75000),
              'held': _money('NGN', 2000000, 20000),
            },
          ],
        },
      );

      await tester.tap(find.byKey(const ValueKey('withdraw-rail-khaime')));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.earningsPayoutBody('₦75,000.00')),
        findsOneWidget,
      );
    });

    testWidgets('a payout is sent in minor units', (tester) async {
      final api = await _pumpEarnings(
        tester,
        summary: {
          ..._emptySummary,
          'activeSettlementCurrency': 'NGN',
          'fundsByRail': [
            {
              'railId': 'rail-khaime',
              'paymentProvider': 'khaime',
              'custodyMode': 'provider_held',
              'settlementCurrency': 'NGN',
              'availability': 'withdrawable',
              'available': _money('NGN', 7500000, 75000),
            },
          ],
        },
      );

      await tester.tap(find.byKey(const ValueKey('withdraw-rail-khaime')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payout-amount')),
        '9500',
      );
      await tester.tap(find.byKey(const ValueKey('giving-request-payout')));
      await tester.pumpAndSettle();

      final request = api.posted.firstWhere(
        (p) => p.$1 == '/v1/payment/earnings/payouts/request',
      );
      final body = request.$2! as Map<String, dynamic>;
      // The ratio comes from the balance itself, not a currency table.
      expect(body['amountMinor'], 950000);
      expect(body['currency'], 'NGN');
      expect(body['railId'], 'rail-khaime');
    });

    testWidgets('more than the balance is refused on the device', (
      tester,
    ) async {
      final api = await _pumpEarnings(
        tester,
        summary: {
          ..._emptySummary,
          'activeSettlementCurrency': 'NGN',
          'fundsByRail': [
            {
              'railId': 'rail-khaime',
              'paymentProvider': 'khaime',
              'custodyMode': 'provider_held',
              'settlementCurrency': 'NGN',
              'availability': 'withdrawable',
              'available': _money('NGN', 7500000, 75000),
            },
          ],
        },
      );

      await tester.tap(find.byKey(const ValueKey('withdraw-rail-khaime')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('payout-amount')),
        '90000',
      );
      await tester.tap(find.byKey(const ValueKey('giving-request-payout')));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.earningsPayoutTooMuch('₦75,000.00')),
        findsOneWidget,
      );
      expect(
        api.posted.map((p) => p.$1),
        isNot(contains('/v1/payment/earnings/payouts/request')),
      );
    });

    testWidgets('dismissing the fund filter keeps the fund', (tester) async {
      await _pumpEarnings(tester, funds: _defaultFunds);

      await tester.tap(find.byKey(const ValueKey('earnings-fund')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('General ministry support').last);
      await tester.pumpAndSettle();
      expect(find.text('General ministry support'), findsOneWidget);

      // Reopened and dismissed. "All funds" is a real choice, so a picker
      // that was simply closed must not read as having picked it.
      await tester.tap(find.byKey(const ValueKey('earnings-fund')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('General ministry support'), findsOneWidget);
      expect(find.text(AppStrings.earningsAllFunds), findsNothing);
    });

    testWidgets('refunds are found past a page that holds none', (
      tester,
    ) async {
      // Refunds have no route: they are transactions whose refund state has
      // moved. Stopping at the first page said "nothing here yet" to a
      // creator who had been refunded a week earlier.
      await _pumpEarnings(
        tester,
        transactionPages: [
          [
            {
              'id': 'g-1',
              'creatorNet': _money('NGN', 100000, 1000),
              'settlementStatus': 'finalized',
            },
          ],
          [
            {
              'id': 'g-2',
              'creatorNet': _money('NGN', 50000, 500),
              'settlementStatus': 'refunded',
              'donor': {'displayName': 'Ada Obi'},
            },
          ],
        ],
      );

      await _scrollTo(tester, find.text(AppStrings.earningsTabRefunds));
      await tester.tap(find.text(AppStrings.earningsTabRefunds));
      await tester.pumpAndSettle();

      expect(find.text('Ada Obi'), findsOneWidget);
      expect(find.text(AppStrings.earningsNoRows), findsNothing);
    });

    test('two settlement currencies are never summed', () {
      final summary = EarningsSummary.fromJson({
        ..._emptySummary,
        'activeSettlementCurrency': 'USD',
        'totalsByCurrency': [
          {
            'settlementCurrency': 'EUR',
            'gross': _money('EUR', 8000, 80),
            'creatorNet': _money('EUR', 7300, 73),
          },
          {
            'settlementCurrency': 'USD',
            'gross': _money('USD', 10000, 100),
            'creatorNet': _money('USD', 9100, 91),
          },
        ],
      });

      // The screen leads with the active settlement currency's bucket and
      // there is no way to ask for a figure spanning both.
      expect(summary.primary?.settlementCurrency, 'USD');
      expect(summary.primary?.gross.display, r'$100.00');
      expect(summary.totalsByCurrency, hasLength(2));
    });

    test('a release is labelled a release, not a payout', () {
      final record = GivingRecord.fromJson({
        'id': 'p-1',
        'automatic': false,
        'amount': _money('NGN', 2000000, 20000),
        'settlementStatus': 'finalized',
      });
      expect(record.automatic, isFalse);
    });

    test('a donor lookup that failed degrades to a neutral label', () {
      final record = GivingRecord.fromJson({
        'id': 'g-1',
        'amount': _money('NGN', 2000000, 20000),
      });
      expect(record.donorName, AppStrings.givingNeutralDonor);
    });
  });

  group('funds', () {
    testWidgets('a plan with no slot left does not open the dialog', (
      tester,
    ) async {
      final api = await _pumpFunds(tester);

      await tester.tap(find.byKey(const ValueKey('new-fund')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingFundLimitReached), findsOneWidget);
      expect(find.text(AppStrings.givingNewFundTitle), findsNothing);
      expect(api.posted, isEmpty);
    });

    testWidgets('a plan with a slot free creates the fund', (tester) async {
      final api = await _pumpFunds(
        tester,
        funds: {
          ..._defaultFunds,
          'limits': {'maxFunds': 5, 'currentFunds': 1, 'canCreate': true},
        },
      );

      await tester.tap(find.byKey(const ValueKey('new-fund')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('fund-name')),
        'Building Fund',
      );
      await tester.tap(find.byKey(const ValueKey('giving-save-fund')));
      await tester.pumpAndSettle();

      final created = api.posted.firstWhere(
        (p) => p.$1 == '/v1/payment/giving/funds',
      );
      final body = created.$2! as Map<String, dynamic>;
      expect(body['name'], 'Building Fund');
      // An empty purpose is left off rather than sent as an empty string.
      expect(body.containsKey('description'), isFalse);
    });

    testWidgets('a refused reporting read offers a retry', (tester) async {
      // Every reporting route answers "Giving application not found" until
      // an application exists, so the screen must not render as an empty
      // ministry that has simply raised nothing.
      await _pumpFunds(tester, reportingRefuses: true);

      expect(find.text(AppStrings.givingFailed), findsOneWidget);
      expect(find.text(AppStrings.givingFundsHeading), findsNothing);
    });

    test('the plan limit counts the reserved general fund', () {
      final list = GivingFundList.fromJson(_defaultFunds);
      expect(list.limits.maxFunds, 1);
      expect(list.limits.currentFunds, 1);
      expect(list.limits.canCreate, isFalse);
      expect(list.funds.single.isGeneral, isTrue);
    });

    test('one unreadable totals row does not take the fund list down', () {
      // Seen wrapped in `total` and flat. Anything else is skipped, because
      // a cast here used to throw out of the whole screen's load.
      final list = GivingFundList.fromJson({
        'funds': [
          {
            'id': 'f-1',
            'slug': 'general',
            'name': 'General',
            'totalsByCurrency': [
              {'total': 1234},
              {'currency': 'NGN', 'amountMinor': 500, 'amount': 5},
              'nonsense',
            ],
          },
        ],
        'limits': {'maxFunds': 1, 'currentFunds': 1, 'canCreate': false},
      });
      expect(list.funds.single.totalsByCurrency.single.display, '₦5.00');
    });

    test('a fund carries its own totals, bucketed', () {
      final fund = GivingFundList.fromJson(_defaultFunds).funds.single;
      expect(fund.giftCount, 8);
      expect(fund.donorCount, 3);
      expect(fund.totalsByCurrency.single.display, '₦100,000.00');
    });
  });

  group('one rail', () {
    testWidgets('a rail with no checklist can still be submitted', (
      tester,
    ) async {
      // Gating the button on "the creator has something outstanding" hid it
      // at the one moment it is wanted, and left a rail whose case lists
      // nothing with no way forward at all.
      await _pumpRail(
        tester,
        rail: {..._activeKhaimeRail, 'status': 'collecting_information'},
      );

      expect(find.text(AppStrings.givingSubmitForReview), findsOneWidget);
    });

    testWidgets('a rail already under review is not offered again', (
      tester,
    ) async {
      await _pumpRail(
        tester,
        rail: {..._activeKhaimeRail, 'status': 'platform_review'},
      );

      expect(find.text(AppStrings.givingSubmitForReview), findsNothing);
    });

    testWidgets('the settlement route names the country', (tester) async {
      await _pumpRail(tester);

      await _scrollTo(tester, find.text(AppStrings.givingRailSettlementRoute));
      expect(find.text('Nigeria · NGN'), findsOneWidget);
    });
  });

  group('the Khaime form', () {
    /// A case whose policy names no account ownership at all.
    ///
    /// `allowedAccountOwnership` arrives empty rather than absent, so the
    /// `??` fallback never fired and `_ownership` initialised off
    /// `[].first`. Being `late`, it threw on first read — which is inside
    /// submit, after the creator had filled the whole form.
    Map<String, dynamic> caseWithOwnership(List<String> allowed) => {
      'applicationId': 'app-1',
      'railId': 'rail-khaime',
      'policy': {
        'id': 'p',
        'code': 'NG',
        'version': 1,
        'allowedAccountOwnership': allowed,
      },
      'requirements': [
        {
          'code': 'identity',
          'label': 'Government-issued identity document',
          'owner': 'creator',
          'status': 'accepted',
          'evidenceType': 'identity_document',
          'fileId': 'file-1',
        },
      ],
    };

    Future<_FakeApi> pumpForm(
      WidgetTester tester,
      Map<String, dynamic> requirements,
    ) async {
      tester.view.physicalSize = const Size(390, 1600) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final api = _FakeApi();
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
            home: GivingKycScreen(
              creatorId: 'c-1',
              rail: GivingRail.fromJson(_activeKhaimeRail),
              application: GivingApplication.fromJson(_draftApplication),
              requirements: RailRequirements.fromJson(requirements),
              repo: GivingRepo(api: api),
              api: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> fill(WidgetTester tester) async {
      for (final (key, value) in const [
        ('kyc-first-name', 'James'),
        ('kyc-last-name', 'Nnamdi'),
        ('kyc-id-number', 'A1234567'),
        ('kyc-street', '14 Adeola Odeku'),
        ('kyc-city', 'Lagos'),
        ('kyc-state', 'Lagos'),
        ('kyc-account-number', '0123456789'),
        ('kyc-account-name', 'James Nnamdi'),
      ]) {
        await tester.enterText(find.byKey(ValueKey(key)), value);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a policy that allows no ownership can still submit', (
      tester,
    ) async {
      final api = await pumpForm(tester, caseWithOwnership(const []));
      await fill(tester);

      await _scrollTo(tester, find.byKey(const ValueKey('kyc-submit')));
      await tester.tap(find.byKey(const ValueKey('kyc-submit')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sent = api.posted.firstWhere(
        (call) => call.$1 == '/v1/payment/earnings/khaime/kyc',
      );
      expect(
        (sent.$2 as Map<String, dynamic>)['accountOwnership'],
        'legal_recipient',
      );
    });

    testWidgets('a missing document is not reported as a failed upload', (
      tester,
    ) async {
      // Nothing failed — nothing was chosen. "That file could not be
      // uploaded" sends a creator hunting a problem that does not exist.
      await pumpForm(tester, {
        ...caseWithOwnership(const ['legal_recipient']),
        'requirements': <Map<String, dynamic>>[],
      });
      await fill(tester);

      await _scrollTo(tester, find.byKey(const ValueKey('kyc-submit')));
      await tester.tap(find.byKey(const ValueKey('kyc-submit')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingDocumentRequired), findsOneWidget);
      expect(find.text(AppStrings.givingEvidenceFailed), findsNothing);
    });

    testWidgets('a half-filled address names the address', (tester) async {
      // Every one of these used to answer "Enter the legal recipient name."
      await pumpForm(tester, caseWithOwnership(const ['legal_recipient']));
      await fill(tester);
      await tester.enterText(find.byKey(const ValueKey('kyc-city')), '');
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const ValueKey('kyc-submit')));
      await tester.tap(find.byKey(const ValueKey('kyc-submit')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingKycAddressRequired), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('the tab holds at 320pt', (tester) async {
      await _pumpGiving(
        tester,
        application: _applicationWith([
          _activeKhaimeRail,
          _reviewingPaystackRail,
        ]),
        size: const Size(320, 568),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the not-started hero holds at 320pt', (tester) async {
      await _pumpGiving(tester, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
    });

    testWidgets('every screen holds at 320pt under long, large data', (
      tester,
    ) async {
      // A legal recipient can be a very long registered name and a total can
      // be ten figures, so the narrow case is exercised against both rather
      // than against the tidy fixtures above.
      const longName =
          'The Redeemed Evangelical Pentecostal Assembly of the Living God '
          'International Worldwide Incorporated';
      final big = _money('XAF', 98765432100, 987654321);
      final rail = {
        ..._activeKhaimeRail,
        'holdDays': 14,
        'settlementAccount': {
          'accountName': longName,
          'holderName': longName,
          'accountNumberLast4': '7029',
        },
      };
      final summary = {
        ..._emptySummary,
        'activeSettlementCurrency': 'XAF',
        'giftCount': 123456,
        'donorCount': 98765,
        'totalsByCurrency': [
          {
            'settlementCurrency': 'XAF',
            'gross': big,
            'processingFees': big,
            'platformFees': big,
            'creatorNet': big,
            'refunded': big,
            'disputed': big,
          },
        ],
        'fundsByRail': [
          {
            'railId': 'rail-khaime',
            'paymentProvider': 'khaime',
            'custodyMode': 'provider_held',
            'settlementCurrency': 'XAF',
            'availability': 'withdrawable',
            'available': big,
            'held': big,
            'released': big,
          },
        ],
      };
      final transactions = [
        for (var i = 0; i < 4; i++)
          {
            'id': 'g-$i',
            'creatorNet': big,
            'fund': {'name': longName},
            'donor': {'displayName': longName},
            'createdAt': '2026-10-26T18:29:00.000Z',
            'settlementStatus': 'pending_provider_truth',
          },
      ];

      tester.view.physicalSize = const Size(320, 568) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final screens = <Widget>[
        GivingEarningsScreen(
          creatorId: 'c-1',
          repo: GivingRepo(
            api: _FakeApi(summary: summary, transactions: transactions),
          ),
        ),
        GivingFundsScreen(
          creatorId: 'c-1',
          repo: GivingRepo(
            api: _FakeApi(summary: summary, transactions: transactions),
          ),
        ),
        GivingRailScreen(
          creatorId: 'c-1',
          rail: GivingRail.fromJson(rail),
          application: GivingApplication.fromJson(_applicationWith([rail])),
          repo: GivingRepo(api: _RequirementsApi(_noRequirements, rail)),
        ),
      ];

      for (final screen in screens) {
        await tester.pumpWidget(
          SizingBuilder(
            baseSize: const Size(390, 844),
            builder: (_) => MaterialApp(
              theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
              home: screen,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the two-column dialogs hold at 320pt', (tester) async {
      // "Settlement country *" overran half a 320pt dialog by about four
      // pixels — a red stripe on every small phone, in two dialogs.
      tester.view.physicalSize = const Size(320, 568) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final options = GivingOptions.fromJson({
        'termsVersion': '2026-07-15',
        'items': _defaultOptions,
      });

      for (final open in <Future<void> Function(BuildContext)>[
        (c) => RailSetupSheet.show(
          c,
          provider: PaymentProvider.khaime,
          options: options.items,
        ),
        (c) => UpdateSettlementSheet.show(
          c,
          rail: GivingRail.fromJson(_activeKhaimeRail),
          options: options.items,
          legalName: 'James Nnamdi',
          classification: LegalClassification.individual,
        ),
        (c) => TurnOnGivingSheet.show(c, options: options),
      ]) {
        late BuildContext captured;
        await tester.pumpWidget(
          SizingBuilder(
            baseSize: const Size(390, 844),
            builder: (_) => MaterialApp(
              home: Builder(
                builder: (context) {
                  captured = context;
                  return const Scaffold();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        open(captured).ignore();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }
    });
  });
}
