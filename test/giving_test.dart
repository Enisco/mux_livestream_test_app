import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/views/giving_earnings_screen.dart';
import 'package:test_app/features/creator/views/giving_funds_screen.dart';
import 'package:test_app/features/creator/views/giving_kyc_screen.dart';
import 'package:test_app/features/creator/views/giving_paystack_screen.dart';
import 'package:test_app/features/creator/views/giving_rail_screen.dart';
import 'package:test_app/features/creator/views/giving_screen.dart';
import 'package:test_app/features/creator/views/giving_stripe_screen.dart';
import 'package:test_app/features/creator/views/studio_shell.dart';
import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/web_app_origin.dart';
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
    this.verifyRefuses = false,
    this.verifyExhausted = false,
    this.resendTooSoon = false,
    this.challengeExpired = false,
    this.hold,
    this.holdWrite,
    this.holdBanks,
    this.submitRefusal,
    this.resolvedAccountName = 'FOOD FOR THOUGHT',
    this.onboardingUrl = 'https://connect.stripe.com/setup/s/ONE_TIME',
  });

  /// What `application/submit` refuses with. Captured from a device on
  /// 2026-11-02: a 400 whose `error` is a **list**, one line per document
  /// the review is still waiting on.
  final List<String>? submitRefusal;

  /// The step-up code is refused, as a mistyped or stale one is.
  final bool verifyRefuses;

  /// The challenge has no tries left. Captured from a device on 2026-11-02:
  /// a bare 401 whose only distinguishing mark is the message.
  final bool verifyExhausted;

  /// Another code asked for inside the cooldown. Probed on 2026-11-02: the
  /// route answers a refusal carrying `details.resendAvailableAt`.
  final bool resendTooSoon;

  /// Completed by a test to release the verify call, so the wait between
  /// tapping Verify and the answer can be looked at.
  final Completer<void>? hold;

  /// A challenge whose code has already run out.
  final bool challengeExpired;

  /// Completed by a test to release a write, so the gap between a sheet
  /// closing and the page changing can be looked at.
  final Completer<void>? holdWrite;

  /// Holds the bank list, which the Khaime form fetches in the background
  /// while the creator fills everything above it in.
  final Completer<void>? holdBanks;

  /// What the bank gives back for a resolved number, or null for one it
  /// does not know.
  final String? resolvedAccountName;

  /// Stripe's one-time hosted onboarding URL, or null for the refusal that
  /// comes back without one.
  final String? onboardingUrl;

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
    if (path.endsWith('/khaime/banks') && holdBanks != null) {
      await holdBanks!.future;
    }
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
    if (path == '/v1/payment/earnings/paystack/banks') {
      return _ok(path, {
        'banks': [
          {'id': 'b-1', 'name': 'Guaranty Trust Bank', 'code': '058'},
          {'id': 'b-2', 'name': 'Access Bank', 'code': '044'},
        ],
      });
    }
    if (path == '/v1/payment/earnings/paystack/bank-account') {
      return _ok(path, {'accountName': resolvedAccountName});
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
    if (path.endsWith('/application/submit') && submitRefusal != null) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 400,
          data: {'success': false, 'data': null, 'error': submitRefusal},
        ),
      );
    }
    if (path.endsWith('/verify') && hold != null) await hold!.future;
    if (holdWrite != null &&
        (path == '/v1/payment/earnings/application' ||
            path == '/v1/payment/giving/funds')) {
      await holdWrite!.future;
    }
    if (path.endsWith('/resend') && resendTooSoon) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 400,
          data: {
            'success': false,
            'error': 'Please wait before requesting another verification code.',
            'details': {'resendAvailableAt': '2026-11-02T06:45:30.202Z'},
          },
        ),
      );
    }
    if (path.endsWith('/verify') && verifyExhausted) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 401,
          data: {'success': false, 'error': 'Maximum OTP attempts exceeded'},
        ),
      );
    }
    if (path.endsWith('/verify') && verifyRefuses) {
      throw _boom(path, status: 400);
    }
    if (path == '/v1/auth/step-up/challenges') {
      return _ok(path, {
        'challengeId': 'ch-1',
        'expiresAt': challengeExpired
            ? '2020-01-01T00:00:00.000Z'
            : DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 10))
                  .toIso8601String(),
        'delivery': 'email',
      });
    }
    if (path.endsWith('/verify')) return _ok(path, {'grantToken': 'grant-1'});
    if (path == '/v1/payment/earnings/stripe/onboarding-link') {
      return _ok(path, {'onboardingUrl': ?onboardingUrl});
    }
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

const _onboardingPaystackRail = {
  'id': 'rail-paystack',
  'paymentProvider': 'paystack',
  'custodyMode': 'direct',
  'countryCode': 'NG',
  'settlementCurrency': 'NGN',
  'status': 'provider_onboarding',
  'enabled': true,
  'priority': 10,
  'provider': {
    'management': {'mode': 'paystack_bank'},
  },
};

/// A Stripe rail partway through hosted onboarding: an account exists but
/// Stripe is still asking for things, which is exactly when section 7 says
/// to keep offering "Continue Stripe setup".
const _onboardingStripeRail = {
  'id': 'rail-stripe',
  'paymentProvider': 'stripe',
  'custodyMode': 'direct',
  'countryCode': 'US',
  'settlementCurrency': 'USD',
  'status': 'provider_onboarding',
  'enabled': true,
  'priority': 5,
  'provider': {
    'detailsSubmitted': false,
    'requirementsCurrentlyDue': ['identity_document'],
    'management': {'mode': 'stripe_embedded'},
  },
};

const _providerOwnedRequirements = {
  'applicationId': 'app-1',
  'railId': 'rail-paystack',
  'requirements': [
    {
      'code': 'identity_and_bank',
      'label': 'Identity and bank verification',
      'owner': 'provider',
      'status': 'pending',
    },
  ],
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
  bool verifyRefuses = false,
  bool verifyExhausted = false,
  bool resendTooSoon = false,
  bool challengeExpired = false,
  Completer<void>? hold,
  Completer<void>? holdWrite,
  VoidCallback? onLeaveStudio,
  Size size = const Size(390, 844),
}) async {
  final api = _FakeApi(
    application: application,
    optionItems: optionItems,
    failReads: failReads,
    verifyRefuses: verifyRefuses,
    verifyExhausted: verifyExhausted,
    resendTooSoon: resendTooSoon,
    challengeExpired: challengeExpired,
    hold: hold,
    holdWrite: holdWrite,
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
          onLeaveStudio: onLeaveStudio,
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
  Completer<void>? holdWrite,
}) async {
  final api = _FakeApi(
    summary: _emptySummary,
    funds: funds,
    reportingRefuses: reportingRefuses,
    holdWrite: holdWrite,
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

Future<_FakeApi> _pumpRail(
  WidgetTester tester, {
  Map<String, dynamic> rail = _activeKhaimeRail,
  Map<String, dynamic> requirements = _noRequirements,
  List<String>? submitRefusal,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = _RequirementsApi(
    requirements,
    rail,
    submitRefusal: submitRefusal,
  );
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
          api: api,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// The Stripe handoff on its own, with the browser and the web origin
/// injected so no test reaches a plugin or a `.env`.
Future<_FakeApi> _pumpStripe(
  WidgetTester tester, {
  String? onboardingUrl = 'https://connect.stripe.com/setup/s/ONE_TIME',
  List<Uri>? opened,
  bool opens = true,
  Map<String, dynamic>? requirements,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = _FakeApi(onboardingUrl: onboardingUrl);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: GivingStripeScreen(
          creatorId: 'c-1',
          rail: GivingRail.fromJson(_onboardingStripeRail),
          requirements: requirements == null
              ? null
              : RailRequirements.fromJson(requirements),
          repo: GivingRepo(api: api),
          origin: 'https://app.staging.gospeltube.tv',
          launcher: (uri) async {
            opened?.add(uri);
            return opens;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// Answers the rail screen's two reads and nothing else.
class _RequirementsApi extends _FakeApi {
  _RequirementsApi(
    this.requirements,
    Map<String, dynamic> rail, {
    super.submitRefusal,
  }) : super(application: _applicationWith([rail]));

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

    testWidgets('a refused code keeps the sheet open and says so', (
      tester,
    ) async {
      // Reported from the device on 2026-11-02: verifying closed the sheet
      // and left the page exactly as it was, with no message anywhere. The
      // screen used to own this call, so a refusal arrived after the sheet
      // it belonged to had gone.
      final api = await _pumpGiving(
        tester,
        application: _draftApplication,
        verifyRefuses: true,
      );

      await tester.tap(find.byKey(const ValueKey('setup-khaime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-connect-securely')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('giving-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('giving-verify')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('giving-code')), findsOneWidget);
      expect(find.text(AppStrings.givingCodeWrong), findsOneWidget);
      // And nothing was enrolled on the strength of a code the server
      // would not take.
      expect(
        api.posted.map((p) => p.$1),
        isNot(contains('/v1/payment/earnings/rails')),
      );
    });

    testWidgets('a write says it is working once its sheet has gone', (
      tester,
    ) async {
      // Reported from the device on 2026-11-02: the sheet closed on the CTA
      // and the page simply sat there until it changed. Every write here is
      // reached from a sheet, so by the time one runs there is no button
      // left under the finger to carry a spinner.
      final hold = Completer<void>();
      await _pumpGiving(tester, holdWrite: hold);

      await tester.tap(find.byKey(const ValueKey('giving-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-accept-terms')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-save-recipient')));
      await tester.pump();

      expect(find.text(AppStrings.givingWorking), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.givingWorking), findsNothing);
    });

    testWidgets('a spent challenge stops asking for the same code', (
      tester,
    ) async {
      // Once the tries are used up no code will ever work on that
      // challenge, so offering Verify again is offering a dead end.
      await _pumpGiving(
        tester,
        application: _draftApplication,
        verifyExhausted: true,
      );

      await tester.tap(find.byKey(const ValueKey('setup-khaime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-connect-securely')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('giving-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('giving-verify')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingCodeAttemptsUsed), findsOneWidget);
      final button = tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('giving-verify')),
      );
      expect(button.enabled, isFalse, reason: 'Resend is the only way on');
    });

    testWidgets('an expired code is not called a typo', (tester) async {
      // The guide warns against reporting a step-up refusal as a wrong code
      // without ruling expiry out: a creator who copied it correctly from an
      // email they opened late would be told they cannot read.
      await _pumpGiving(
        tester,
        application: _draftApplication,
        verifyRefuses: true,
        challengeExpired: true,
      );

      await tester.tap(find.byKey(const ValueKey('setup-khaime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-connect-securely')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('giving-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('giving-verify')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingCodeExpired), findsOneWidget);
      expect(find.text(AppStrings.givingCodeWrong), findsNothing);
    });

    testWidgets('verifying shows the wait on the button that was tapped', (
      tester,
    ) async {
      final hold = Completer<void>();
      await _pumpGiving(tester, application: _draftApplication, hold: hold);

      await tester.tap(find.byKey(const ValueKey('setup-khaime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-connect-securely')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('giving-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('giving-verify')));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('giving-verify')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('asking again too soon is not reported as a breakage', (
      tester,
    ) async {
      // Probed on 2026-11-02: the resend route refuses inside its cooldown
      // with `details.resendAvailableAt`. Read as a generic write failure it
      // says "that did not go through", which sends a creator round again
      // instead of waiting half a minute.
      await _pumpGiving(
        tester,
        application: _draftApplication,
        resendTooSoon: true,
      );

      await tester.tap(find.byKey(const ValueKey('setup-khaime')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-connect-securely')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('giving-resend')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingCodeResendTooSoon), findsOneWidget);
      expect(find.text(AppStrings.givingWriteFailed), findsNothing);
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

  group('the switcher, from a tab that is not Studio', () {
    testWidgets('back to watching leaves from the Giving tab too', (
      tester,
    ) async {
      // Found on a device on 2026-11-03. Three of the four tabs that open
      // this sheet handled only `switchTo`, so the row worked from the
      // Studio tab and nowhere else.
      var left = false;
      await _pumpGiving(
        tester,
        application: _draftApplication,
        onLeaveStudio: () => left = true,
      );

      await tester.tap(find.byType(StudioPill));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('back-to-watching')));
      await tester.pumpAndSettle();

      expect(left, isTrue);
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

    testWidgets('creating one says it is working while it does', (
      tester,
    ) async {
      // The same gap as the Giving tab's: the dialog closes on Save and the
      // list cannot change until the round trip lands.
      final hold = Completer<void>();
      await _pumpFunds(
        tester,
        holdWrite: hold,
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
      await tester.pump();

      expect(find.text(AppStrings.givingWorking), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.givingWorking), findsNothing);
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

    /// A case waiting on the two documents the creator has to supply.
    ///
    /// This is the shape that produced the bug: both are `creator`-owned, so
    /// the GospelTube track lists them, and neither could be attached from
    /// anywhere on this screen.
    const owedByCreator = {
      'applicationId': 'app-1',
      'railId': 'rail-khaime',
      'requirements': [
        {
          'code': 'identity',
          'label': 'Government-issued identity document',
          'owner': 'creator',
          'status': 'pending',
          'evidenceType': 'identity_document',
        },
        {
          'code': 'selfie',
          'label': 'Selfie holding the identity document',
          'owner': 'creator',
          'status': 'pending',
          'evidenceType': 'selfie',
        },
        {
          'code': 'khaime_review',
          'label': 'Khaime identity and bank review',
          'owner': 'provider',
          'status': 'pending',
        },
      ],
    };

    testWidgets('a document the creator still owes takes the submit\'s place', (
      tester,
    ) async {
      // The whole bug in one assertion. The track listed two documents the
      // creator had to supply and offered only "Submit for review", whose
      // one possible outcome was a 400 naming those same two documents —
      // the upload lived behind the *other* track's button.
      await _pumpRail(
        tester,
        rail: {..._activeKhaimeRail, 'status': 'collecting_information'},
        requirements: owedByCreator,
      );

      expect(find.text(AppStrings.givingUploadDocuments), findsOneWidget);
      expect(find.text(AppStrings.givingSubmitForReview), findsNothing);
    });

    testWidgets('submit comes back once the documents are uploaded', (
      tester,
    ) async {
      // `submitted` with a file on it is what an attach leaves behind, and
      // it is the state the creator sits in waiting for the review. It is
      // still *uploadable* — a file may be replaced right up until it is
      // accepted — so reading "the creator can act on this" as "this is
      // missing" would hold the submit back forever.
      await _pumpRail(
        tester,
        rail: {..._activeKhaimeRail, 'status': 'collecting_information'},
        requirements: {
          ...owedByCreator,
          'requirements': [
            for (final requirement
                in owedByCreator['requirements']! as List<Map<String, dynamic>>)
              requirement['owner'] == 'creator'
                  ? {...requirement, 'status': 'submitted', 'fileId': 'file-1'}
                  : requirement,
          ],
        },
      );

      expect(find.text(AppStrings.givingSubmitForReview), findsOneWidget);
      expect(find.text(AppStrings.givingUploadDocuments), findsNothing);
    });

    testWidgets('a rejected document blocks the submit again', (tester) async {
      // A rejection reopens the requirement: there is a file on it, and it
      // is not one the review will take.
      await _pumpRail(
        tester,
        rail: {..._activeKhaimeRail, 'status': 'collecting_information'},
        requirements: {
          ...owedByCreator,
          'requirements': [
            {
              'code': 'identity',
              'label': 'Government-issued identity document',
              'owner': 'creator',
              'status': 'rejected',
              'evidenceType': 'identity_document',
              'fileId': 'file-1',
              'rejectionReason': 'The photograph is too dark to read.',
            },
          ],
        },
      );

      expect(find.text(AppStrings.givingUploadDocuments), findsOneWidget);
      expect(find.text(AppStrings.givingSubmitForReview), findsNothing);
    });

    testWidgets('the checklist offers an upload only on the creator\'s rows', (
      tester,
    ) async {
      await _pumpRail(
        tester,
        rail: {..._activeKhaimeRail, 'status': 'collecting_information'},
        requirements: owedByCreator,
      );

      await _scrollTo(tester, find.text(AppStrings.givingReviewChecklist));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      // One per creator-owned row, and none against the provider's own
      // review — nothing the creator uploads can satisfy that one.
      expect(find.text(AppStrings.givingUploadDocument), findsNWidgets(2));
    });

    testWidgets('a finished track stops offering its own setup', (
      tester,
    ) async {
      // Found on a device on 2026-11-02: "Provider verification ·
      // Completed" with a live "Continue Setup Khaime" under it. The
      // action was gated on the *rail* being active, and the rail was not
      // — GospelTube's half was still outstanding — so a track that had
      // nothing left to do kept offering to reopen the identity form the
      // provider had already approved.
      await _pumpRail(
        tester,
        rail: {..._activeKhaimeRail, 'status': 'collecting_information'},
        requirements: {
          'applicationId': 'app-1',
          'railId': 'rail-khaime',
          'requirements': [
            {
              'code': 'identity',
              'label': 'Government-issued identity document',
              'owner': 'creator',
              'status': 'pending',
              'evidenceType': 'identity_document',
            },
            {
              'code': 'khaime_review',
              'label': 'Khaime identity and bank review',
              'owner': 'provider',
              'status': 'accepted',
            },
          ],
        },
      );

      expect(find.text(AppStrings.givingTrackCompleted), findsOneWidget);
      expect(
        find.text(AppStrings.givingContinueProvider('Khaime')),
        findsNothing,
      );
      // The other track is not finished, so its own action stays.
      expect(find.text(AppStrings.givingUploadDocuments), findsOneWidget);
    });

    testWidgets('a provider still working is still offered its setup', (
      tester,
    ) async {
      // `kycStatus` comes down with the fixture as `verified`, which is
      // the opposite of what this case is about: section 2's machine runs
      // `not_started -> in_progress -> submitted`, and a rail whose form
      // is half-filled is `in_progress`.
      await _pumpRail(
        tester,
        rail: {
          ..._activeKhaimeRail,
          'status': 'collecting_information',
          'kycStatus': 'in_progress',
        },
        requirements: owedByCreator,
      );

      expect(
        find.text(AppStrings.givingContinueProvider('Khaime')),
        findsOneWidget,
      );
    });

    testWidgets('continue setup opens the Paystack form, not a snackbar', (
      tester,
    ) async {
      // Found on a device on 2026-11-02: the button answered with
      // "finish verification securely on the provider" and went nowhere.
      // Paystack has no hosted page — section 8 is three ordinary routes —
      // so that copy was both a dead end and untrue for this provider.
      await _pumpRail(
        tester,
        rail: _onboardingPaystackRail,
        requirements: {
          'applicationId': 'app-1',
          'railId': 'rail-paystack',
          'requirements': [
            {
              'code': 'identity_and_bank',
              'label': 'Identity and bank verification',
              'owner': 'provider',
              'status': 'pending',
            },
          ],
        },
      );

      await tester.tap(
        find.text(AppStrings.givingContinueProvider('Paystack')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GivingPaystackScreen), findsOneWidget);
      expect(find.text(AppStrings.givingProviderFormBody), findsNothing);
    });

    testWidgets('a provider already holding the details stops offering it', (
      tester,
    ) async {
      // Found on a device on 2026-11-03. The subaccount had been created —
      // the rail read "Under review" — and the provider card still offered
      // "Continue Setup Paystack", which reopens the settlement-account
      // form. Changing the destination once it is recorded is a versioned
      // recipient change, not a resubmission.
      await _pumpRail(
        tester,
        rail: {
          ..._onboardingPaystackRail,
          'status': 'platform_review',
          'settlementAccount': {
            'accountName': 'Guaranty Trust Bank',
            'accountNumberLast4': '6789',
          },
        },
        requirements: _providerOwnedRequirements,
      );

      expect(
        find.text(AppStrings.givingContinueProvider('Paystack')),
        findsNothing,
      );
      // And says why, rather than leaving an outstanding row above a card
      // with no way on.
      expect(
        find.text(AppStrings.givingProviderWaiting('Paystack')),
        findsOneWidget,
      );
    });

    testWidgets('the tab card agrees with the screen behind it', (
      tester,
    ) async {
      // Two places name the same move, and a tab offering "Continue Setup
      // Paystack" over a screen asking for a correction is the kind of
      // disagreement a creator reads as the app being broken.
      await _pumpGiving(
        tester,
        application: _applicationWith([
          {..._onboardingPaystackRail, 'status': 'more_information_required'},
        ]),
      );

      expect(find.text(AppStrings.givingProviderUpdate), findsOneWidget);
      expect(
        find.text(AppStrings.givingContinueProvider('Paystack')),
        findsNothing,
      );
    });

    /// What the provider track says, for each of the four places the
    /// provider half can be.
    ///
    /// Reported from a device on 2026-11-03 against Stripe: the hosted
    /// onboarding had been completed and the card still offered "Continue
    /// Setup Stripe". The deeper fault was that the card only ever asked
    /// one yes/no question, so *waiting on a decision* and *the decision
    /// came back and said no* were the same answer — and the second one
    /// left a creator no way to put anything right.
    group('the provider track, state by state', () {
      Map<String, dynamic> stripeRail({
        bool detailsSubmitted = true,
        List<String> due = const [],
        bool? approved,
        String status = 'provider_onboarding',
      }) => {
        ..._onboardingStripeRail,
        'status': status,
        'provider': {
          'detailsSubmitted': detailsSubmitted,
          'requirementsCurrentlyDue': due,
          'management': {'mode': 'stripe_embedded'},
          if (approved != null) 'stripeAccountControls': {'approved': approved},
        },
      };

      testWidgets('Stripe stops offering setup once the form is done', (
        tester,
      ) async {
        // The report itself: `detailsSubmitted` with nothing currently
        // due is Stripe verifying, not Stripe waiting on the creator.
        await _pumpRail(
          tester,
          rail: stripeRail(approved: false),
          requirements: _providerOwnedRequirements,
        );

        expect(
          find.text(AppStrings.givingContinueProvider('Stripe')),
          findsNothing,
        );
        expect(find.text(AppStrings.givingProviderUpdate), findsNothing);
      });

      testWidgets('and says who is being waited on, in Stripe\'s words', (
        tester,
      ) async {
        // Section 7 allows exactly this one neutral state while
        // `approved=false`, and nothing stronger.
        await _pumpRail(
          tester,
          rail: stripeRail(approved: false),
          requirements: _providerOwnedRequirements,
        );

        expect(
          find.text(AppStrings.givingProviderVerifying('Stripe')),
          findsOneWidget,
        );
      });

      testWidgets('an approved Stripe account finishes the track', (
        tester,
      ) async {
        // `stripeAccountControls.approved` is Stripe's own verdict and was
        // not read at all before.
        await _pumpRail(
          tester,
          rail: stripeRail(approved: true),
          requirements: _providerOwnedRequirements,
        );

        expect(find.text(AppStrings.givingTrackCompleted), findsNWidgets(1));
        expect(
          find.text(AppStrings.givingContinueProvider('Stripe')),
          findsNothing,
        );
      });

      testWidgets('an unfinished Stripe form still gets its setup', (
        tester,
      ) async {
        await _pumpRail(
          tester,
          rail: stripeRail(detailsSubmitted: false),
          requirements: _providerOwnedRequirements,
        );

        expect(
          find.text(AppStrings.givingContinueProvider('Stripe')),
          findsOneWidget,
        );
      });

      for (final (provider, rail, screen)
          in <(String, Map<String, dynamic>, Type)>[
            ('Stripe', _onboardingStripeRail, GivingStripeScreen),
            ('Paystack', _onboardingPaystackRail, GivingPaystackScreen),
            ('Khaime', _activeKhaimeRail, GivingKycScreen),
          ]) {
        testWidgets('$provider offers a way to put a refusal right', (
          tester,
        ) async {
          // The state with no UI at all before this: the rail came back
          // needing something changed and the card said nothing to do.
          await _pumpRail(
            tester,
            rail: {...rail, 'status': 'more_information_required'},
            requirements: _providerOwnedRequirements,
          );

          expect(find.text(AppStrings.givingProviderUpdate), findsOneWidget);
          expect(
            find.text(AppStrings.givingContinueProvider(provider)),
            findsNothing,
          );

          await tester.tap(find.text(AppStrings.givingProviderUpdate));
          await tester.pumpAndSettle();

          expect(find.byType(screen), findsOneWidget);
        });
      }

      testWidgets('a rejected rail does too', (tester) async {
        await _pumpRail(
          tester,
          rail: {..._onboardingPaystackRail, 'status': 'rejected'},
          requirements: _providerOwnedRequirements,
        );

        expect(find.text(AppStrings.givingProviderUpdate), findsOneWidget);
      });

      testWidgets('and so does a rejected provider KYC', (tester) async {
        // Khaime has `kyc/resubmit` for precisely this.
        await _pumpRail(
          tester,
          rail: {
            ..._activeKhaimeRail,
            'status': 'provider_onboarding',
            'kycStatus': 'rejected',
          },
          requirements: _providerOwnedRequirements,
        );

        expect(find.text(AppStrings.givingProviderUpdate), findsOneWidget);
      });

      testWidgets('the provider\'s own reason stands in for the stock line', (
        tester,
      ) async {
        await _pumpRail(
          tester,
          rail: {..._onboardingPaystackRail, 'status': 'rejected'},
          requirements: {
            'applicationId': 'app-1',
            'railId': 'rail-paystack',
            'requirements': [
              {
                'code': 'bank_account_name_review',
                'label': 'Bank account name review',
                'owner': 'provider',
                'status': 'rejected',
                'rejectionReason':
                    'The account name does not match the legal recipient.',
              },
            ],
          },
        );

        expect(
          find.text('The account name does not match the legal recipient.'),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.givingProviderUpdateNote('Paystack')),
          findsNothing,
        );
      });

      /// The payload from the device on 2026-11-03, trimmed to the
      /// fields that decide anything: `status: provider_onboarding`,
      /// `kycStatus: submitted`, a submitted `review`, and a provider
      /// block whose Stripe mirror had not caught up.
      Map<String, dynamic> reportedRail({
        String kycStatus = 'submitted',
        bool detailsSubmitted = false,
        List<String> due = const [],
      }) => {
        ..._onboardingStripeRail,
        'kycStatus': kycStatus,
        'review': {
          'status': 'submitted',
          'submittedAt': '2026-11-03T07:00:38.075Z',
          'reviewedAt': null,
          'reason': null,
        },
        'provider': {
          'detailsSubmitted': detailsSubmitted,
          'requirementsCurrentlyDue': due,
          'management': {'mode': 'stripe_embedded'},
        },
      };

      Finder inProvider(String text) => find.descendant(
        of: find.byKey(const ValueKey('track-provider')),
        matching: find.text(text),
      );

      testWidgets('a rail waiting on a decision offers nothing to change', (
        tester,
      ) async {
        await _pumpRail(
          tester,
          rail: {
            ..._onboardingPaystackRail,
            'status': 'platform_review',
            'settlementAccount': {'accountNumberLast4': '6789'},
          },
          requirements: _providerOwnedRequirements,
        );

        expect(find.text(AppStrings.givingProviderUpdate), findsNothing);
        expect(
          find.text(AppStrings.givingProviderWaiting('Paystack')),
          findsOneWidget,
        );
      });

      testWidgets('a submitted KYC is never called "Not started"', (
        tester,
      ) async {
        // The report: "the screen says that I've not started Stripe
        // provider verification even though I have submitted it and the
        // data also says so". `kycStatus: submitted` is the data saying
        // so, and it outranks the provider's asynchronous mirror of it.
        await _pumpRail(
          tester,
          rail: reportedRail(),
          requirements: _providerOwnedRequirements,
        );

        expect(inProvider(AppStrings.givingTrackNotStarted), findsNothing);
        expect(
          find.text(AppStrings.givingContinueProvider('Stripe')),
          findsNothing,
        );
        expect(inProvider(AppStrings.givingTrackWaiting), findsOneWidget);
      });

      testWidgets('but a rail Stripe is still asking of keeps its setup', (
        tester,
      ) async {
        // `currently_due` is the one thing that outranks the KYC state:
        // Stripe is asking today, whatever was handed over yesterday.
        await _pumpRail(
          tester,
          rail: reportedRail(due: ['individual.verification.document']),
          requirements: _providerOwnedRequirements,
        );

        expect(
          find.text(AppStrings.givingContinueProvider('Stripe')),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.givingProviderWants('Stripe')),
          findsOneWidget,
        );
      });

      testWidgets('and says so differently from a half-finished form', (
        tester,
      ) async {
        // Same button, two different reasons. Reopening the flow helps
        // with one of them and cannot help with the other.
        await _pumpRail(
          tester,
          rail: {
            ...reportedRail(kycStatus: 'in_progress'),
            'status': 'collecting_information',
          },
          requirements: _providerOwnedRequirements,
        );

        expect(
          find.text(AppStrings.givingProviderUnfinished('Stripe')),
          findsOneWidget,
        );
        expect(inProvider(AppStrings.givingTrackActionNeeded), findsOneWidget);
      });

      testWidgets('a rail nobody has touched still says so', (tester) async {
        await _pumpRail(
          tester,
          rail: {
            ...reportedRail(kycStatus: 'not_started'),
            'status': 'collecting_information',
            'review': <String, dynamic>{},
          },
          requirements: _providerOwnedRequirements,
        );

        expect(inProvider(AppStrings.givingTrackNotStarted), findsOneWidget);
      });

      testWidgets('a verified KYC finishes the provider track', (tester) async {
        await _pumpRail(
          tester,
          rail: reportedRail(kycStatus: 'verified'),
          requirements: _providerOwnedRequirements,
        );

        expect(inProvider(AppStrings.givingTrackCompleted), findsOneWidget);
      });

      testWidgets('a reopened case is the creator\'s move again', (
        tester,
      ) async {
        // A rail sent back keeps the KYC it had, so `verified` survives
        // alongside a status that says otherwise. The status is newer.
        await _pumpRail(
          tester,
          rail: {
            ...reportedRail(kycStatus: 'verified'),
            'status': 'more_information_required',
          },
          requirements: _providerOwnedRequirements,
        );

        expect(find.text(AppStrings.givingProviderUpdate), findsOneWidget);
      });
    });

    /// GospelTube's own half, which could only ever say "Under review"
    /// because it read the requirement list instead of the decision the
    /// rail carries in `review`.
    group('the GospelTube track reads its own verdict', () {
      Finder inTrack(String text) => find.descendant(
        of: find.byKey(const ValueKey('track-gospeltube')),
        matching: find.text(text),
      );

      Map<String, dynamic> reviewed(Map<String, dynamic> review) => {
        ..._onboardingStripeRail,
        'kycStatus': 'submitted',
        'review': review,
      };

      testWidgets('a refusal says so, in the reviewer\'s own words', (
        tester,
      ) async {
        await _pumpRail(
          tester,
          rail: reviewed({
            'status': 'rejected',
            'reason': 'The registration does not name the legal recipient.',
          }),
          requirements: _providerOwnedRequirements,
        );

        expect(inTrack(AppStrings.givingTrackActionNeeded), findsOneWidget);
        expect(
          find.text('The registration does not name the legal recipient.'),
          findsOneWidget,
        );
      });

      testWidgets('an information request does too', (tester) async {
        await _pumpRail(
          tester,
          rail: reviewed({'status': 'information_requested', 'reason': null}),
          requirements: _providerOwnedRequirements,
        );

        expect(inTrack(AppStrings.givingTrackActionNeeded), findsOneWidget);
        expect(find.text(AppStrings.givingReviewNeedsMore), findsOneWidget);
      });

      testWidgets('an approval finishes the track', (tester) async {
        await _pumpRail(
          tester,
          rail: reviewed({
            'status': 'approved',
            'reviewedAt': '2026-11-03T09:00:00.000Z',
          }),
          requirements: _providerOwnedRequirements,
        );

        expect(inTrack(AppStrings.givingTrackCompleted), findsOneWidget);
      });

      testWidgets('and a submitted one is still under review', (tester) async {
        await _pumpRail(
          tester,
          rail: reviewed({'status': 'submitted'}),
          requirements: _providerOwnedRequirements,
        );

        expect(inTrack(AppStrings.givingTrackUnderReview), findsOneWidget);
      });

      testWidgets('a rail with no decision keeps the old reading', (
        tester,
      ) async {
        // An absent block says nothing, and nothing is not a verdict.
        await _pumpRail(
          tester,
          rail: {..._onboardingStripeRail, 'review': <String, dynamic>{}},
          requirements: _providerOwnedRequirements,
        );

        expect(inTrack(AppStrings.givingTrackActionNeeded), findsNothing);
      });
    });

    testWidgets('details already at the provider count on their own', (
      tester,
    ) async {
      // `detailsSubmitted` is the provider's own word for "the creator's
      // details reached us", and it is the half of the answer that does
      // not depend on GospelTube having recorded a destination yet.
      await _pumpRail(
        tester,
        rail: {
          ..._onboardingPaystackRail,
          'provider': {
            'detailsSubmitted': true,
            'management': {'mode': 'paystack_bank'},
          },
        },
        requirements: _providerOwnedRequirements,
      );

      expect(
        find.text(AppStrings.givingContinueProvider('Paystack')),
        findsNothing,
      );
    });

    testWidgets('Stripe keeps its setup while requirements remain', (
      tester,
    ) async {
      // Section 7: "While initial onboarding requirements remain, render
      // Continue Stripe setup." Its hosted flow can be abandoned halfway,
      // so the way back has to stay.
      await _pumpRail(
        tester,
        rail: _onboardingStripeRail,
        requirements: _providerOwnedRequirements,
      );

      await tester.tap(find.text(AppStrings.givingContinueProvider('Stripe')));
      await tester.pumpAndSettle();

      expect(find.byType(GivingStripeScreen), findsOneWidget);
      // The snackbar it used to answer with belongs to a provider none of
      // the three forms match.
      expect(find.text(AppStrings.givingProviderFormBody), findsNothing);
    });

    testWidgets('Stripe keeps it even once its account exists', (tester) async {
      // The clause that separates Stripe from the other two. Stripe can
      // ask for more after `detailsSubmitted` — a document, an owner —
      // and those are the creator's to answer on Stripe's own pages. The
      // Paystack rule, "the provider has the details, so there is nothing
      // left to send", would close the only door.
      await _pumpRail(
        tester,
        rail: {
          ..._onboardingStripeRail,
          'provider': {
            'detailsSubmitted': true,
            'requirementsCurrentlyDue': ['individual.verification.document'],
            'management': {'mode': 'stripe_embedded'},
          },
          'settlementAccount': {'accountNumberLast4': '4242'},
        },
        requirements: _providerOwnedRequirements,
      );

      expect(
        find.text(AppStrings.givingContinueProvider('Stripe')),
        findsOneWidget,
      );
    });

    testWidgets('a refused submit says which documents are missing', (
      tester,
    ) async {
      // Verbatim from the device on 2026-11-02. Reported as "that did not
      // go through", it told a creator nothing about what to do next.
      const refusal = [
        'Missing required information: Government-issued identity document, '
            'Selfie holding the identity document',
      ];
      await _pumpRail(
        tester,
        rail: {..._activeKhaimeRail, 'status': 'collecting_information'},
        submitRefusal: refusal,
      );

      await tester.tap(find.text(AppStrings.givingSubmitForReview));
      await tester.pumpAndSettle();

      expect(find.text(refusal.single), findsOneWidget);
      expect(find.text(AppStrings.givingWriteFailed), findsNothing);
    });
  });

  group('the Paystack form', () {
    Future<_FakeApi> pumpPaystack(
      WidgetTester tester, {
      String? resolvedAccountName = 'FOOD FOR THOUGHT',
    }) async {
      tester.view.physicalSize = const Size(390, 1200) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final api = _FakeApi(resolvedAccountName: resolvedAccountName);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
            home: GivingPaystackScreen(
              creatorId: 'c-1',
              rail: GivingRail.fromJson(_onboardingPaystackRail),
              application: GivingApplication.fromJson(_draftApplication),
              requirements: RailRequirements.fromJson(const {
                'applicationId': 'app-1',
                'railId': 'rail-paystack',
                'requirements': <Map<String, dynamic>>[],
                'policy': {
                  'id': 'p-1',
                  'code': 'ng-individual',
                  'version': 3,
                  'allowedAccountOwnership': ['legal_recipient'],
                },
              }),
              repo: GivingRepo(api: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> chooseBank(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('paystack-bank')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guaranty Trust Bank').last);
      await tester.pumpAndSettle();
    }

    testWidgets('the number is resolved and the name shown before anything '
        'is created', (tester) async {
      // "Show the returned account name for explicit confirmation." The
      // subaccount is the thing that cannot be taken back, so it does not
      // happen until the creator has seen whose account this is.
      final api = await pumpPaystack(tester);
      await chooseBank(tester);
      await tester.enterText(
        find.byKey(const ValueKey('paystack-account-number')),
        '0123456789',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paystack-check')));
      await tester.pumpAndSettle();

      expect(find.text('FOOD FOR THOUGHT'), findsOneWidget);
      expect(
        api.posted.where(
          (call) => call.$1 == '/v1/payment/earnings/paystack/subaccount',
        ),
        isEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('paystack-connect')));
      await tester.pumpAndSettle();

      final sent = api.posted.firstWhere(
        (call) => call.$1 == '/v1/payment/earnings/paystack/subaccount',
      );
      final body = sent.$2! as Map;
      expect(body['settlementBankCode'], '058');
      expect(body['accountNumber'], '0123456789');
      expect(body['accountOwnership'], 'legal_recipient');
      expect(body['railId'], 'rail-paystack');
    });

    testWidgets('an unchecked account cannot be connected', (tester) async {
      // Resolution is the confirmation step the guide asks for, not a
      // convenience, so there is no path past it.
      final api = await pumpPaystack(tester);
      await chooseBank(tester);
      await tester.enterText(
        find.byKey(const ValueKey('paystack-account-number')),
        '0123456789',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paystack-connect')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingPaystackUnresolved), findsOneWidget);
      expect(
        api.posted.where(
          (call) => call.$1 == '/v1/payment/earnings/paystack/subaccount',
        ),
        isEmpty,
      );
    });

    testWidgets('editing the number forgets the name it resolved to', (
      tester,
    ) async {
      // Otherwise the old name sits under a number it does not belong to,
      // and connecting it would send gifts to a different account than the
      // one confirmed.
      await pumpPaystack(tester);
      await chooseBank(tester);
      await tester.enterText(
        find.byKey(const ValueKey('paystack-account-number')),
        '0123456789',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paystack-check')));
      await tester.pumpAndSettle();
      expect(find.text('FOOD FOR THOUGHT'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('paystack-account-number')),
        '0123456788',
      );
      await tester.pumpAndSettle();

      expect(find.text('FOOD FOR THOUGHT'), findsNothing);
    });

    testWidgets('changing the bank forgets it too', (tester) async {
      await pumpPaystack(tester);
      await chooseBank(tester);
      await tester.enterText(
        find.byKey(const ValueKey('paystack-account-number')),
        '0123456789',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paystack-check')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paystack-bank')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Access Bank').last);
      await tester.pumpAndSettle();

      expect(find.text('FOOD FOR THOUGHT'), findsNothing);
    });

    testWidgets('a number the bank does not know says so', (tester) async {
      await pumpPaystack(tester, resolvedAccountName: null);
      await chooseBank(tester);
      await tester.enterText(
        find.byKey(const ValueKey('paystack-account-number')),
        '0000000000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paystack-check')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingPaystackResolveFailed), findsOneWidget);
    });

    testWidgets('it says the provider step is not the review', (tester) async {
      // `detailsSubmitted=true` means the bank details reached Paystack,
      // not that the owner was verified — and Paystack recipient review is
      // mandatory for everyone.
      await pumpPaystack(tester);
      expect(find.text(AppStrings.givingPaystackReviewNote), findsOneWidget);
    });
  });

  group('the Stripe handoff', () {
    testWidgets('the browser is handed Stripe\'s own link', (tester) async {
      final opened = <Uri>[];
      final api = await _pumpStripe(tester, opened: opened);

      await tester.tap(find.byKey(const ValueKey('stripe-open')));
      await tester.pumpAndSettle();

      // Stripe's URL, untouched: it is one-time and already authenticated.
      expect(opened, [
        Uri.parse('https://connect.stripe.com/setup/s/ONE_TIME'),
      ]);
      final body =
          api.posted
                  .firstWhere(
                    (call) => call.$1.endsWith('/stripe/onboarding-link'),
                  )
                  .$2
              as Map<String, dynamic>;
      // Both callbacks are web pages on the app domain. The native app is
      // not in this loop and never takes a Stripe callback as proof.
      expect(
        body['returnUrl'],
        'https://app.staging.gospeltube.tv/earnings/onboarding/return',
      );
      expect(
        body['refreshUrl'],
        'https://app.staging.gospeltube.tv/earnings/onboarding/refresh',
      );
    });

    testWidgets('a link that never arrived is said, not opened', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pumpStripe(tester, onboardingUrl: null, opened: opened);

      await tester.tap(find.byKey(const ValueKey('stripe-open')));
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('stripe-problem'))).data,
        AppStrings.givingStripeLinkFailed,
      );
    });

    testWidgets('once the browser is open, a fresh link and a way back', (
      tester,
    ) async {
      // Stripe's onboarding links are single-use and expire, which is what
      // its own refreshUrl is for — so a creator who comes back to a dead
      // page needs another one rather than a dead end.
      await _pumpStripe(tester);

      await tester.tap(find.byKey(const ValueKey('stripe-open')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('stripe-open')), findsNothing);
      expect(find.byKey(const ValueKey('stripe-reopen')), findsOneWidget);
      expect(find.byKey(const ValueKey('stripe-done')), findsOneWidget);
    });

    testWidgets('a browser that would not open is not treated as open', (
      tester,
    ) async {
      await _pumpStripe(tester, opens: false);

      await tester.tap(find.byKey(const ValueKey('stripe-open')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('stripe-open')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('stripe-problem'))).data,
        AppStrings.givingStripeOpenFailed,
      );
    });

    testWidgets('the ownership comes from the policy', (tester) async {
      // "accountOwnership must be one of the current case policy's
      // allowedAccountOwnership values" — never inferred from the
      // classification.
      final api = await _pumpStripe(
        tester,
        requirements: {
          'applicationId': 'app-1',
          'railId': 'rail-stripe',
          'requirements': const [],
          'policy': {
            'id': 'pol-1',
            'code': 'US_INDIVIDUAL',
            'version': 3,
            'allowedAccountOwnership': ['legal_entity', 'legal_recipient'],
          },
        },
      );

      await tester.tap(find.byKey(const ValueKey('stripe-open')));
      await tester.pumpAndSettle();

      final body =
          api.posted
                  .firstWhere(
                    (call) => call.$1.endsWith('/stripe/onboarding-link'),
                  )
                  .$2
              as Map<String, dynamic>;
      expect(body['accountOwnership'], 'legal_entity');
    });

    test('the web origin is the API host with its first label swapped', () {
      // One setting, not two: `.env` names the API and nothing else, and
      // the app-link entries in AndroidManifest.xml and
      // Runner.entitlements verify exactly this host.
      expect(
        webAppOrigin(apiBase: 'https://api.staging.gospeltube.tv'),
        'https://app.staging.gospeltube.tv',
      );
      expect(
        webAppOrigin(apiBase: 'https://api.gospeltube.tv'),
        'https://app.gospeltube.tv',
      );
    });

    test('a host that is not api.* is left as it is', () {
      // A wrong origin is worse than the one we were handed.
      expect(
        webAppOrigin(apiBase: 'http://localhost:4000'),
        'http://localhost:4000',
      );
      expect(webAppOrigin(apiBase: '  '), isNull);
    });
  });

  group('a refusal', () {
    DioException refusing(Object? error) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 400,
        data: {'success': false, 'data': null, 'error': error},
      ),
    );

    test('a list of missing documents comes back a line each', () {
      expect(
        givingProblem(refusing(['Missing A', 'Missing B'])),
        'Missing A\nMissing B',
      );
    });

    test('a single sentence comes back as itself', () {
      expect(
        givingProblem(refusing('Bank not supported')),
        'Bank not supported',
      );
    });

    test('nothing usable is nothing, so the caller keeps its own wording', () {
      expect(givingProblem(refusing('   ')), isNull);
      expect(givingProblem(refusing(const <String>[])), isNull);
      expect(givingProblem(refusing(null)), isNull);
      expect(givingProblem(StateError('not from the wire')), isNull);
    });

    test('a gateway page that is not a map does not throw', () {
      expect(
        givingProblem(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: 502,
              data: '<html>Bad Gateway</html>',
            ),
          ),
        ),
        isNull,
      );
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

    testWidgets('the bank list says it is loading, not that there is none', (
      tester,
    ) async {
      // An empty list before the fetch lands is "not here yet", and the tap
      // handler used to answer it with "no banks available" — a creator
      // hunting a problem that was about to solve itself.
      final hold = Completer<void>();
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final api = _FakeApi(holdBanks: hold);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
            home: GivingKycScreen(
              creatorId: 'c-1',
              rail: GivingRail.fromJson(_activeKhaimeRail),
              application: GivingApplication.fromJson(_draftApplication),
              requirements: RailRequirements.fromJson(
                caseWithOwnership(const []),
              ),
              repo: GivingRepo(api: api),
              api: api,
            ),
          ),
        ),
      );
      await tester.pump();

      // Not _scrollTo: that settles, and a held spinner never settles.
      final field = find.byKey(const ValueKey('kyc-bank'));
      final sheet = find.byType(Scrollable).first;
      for (var i = 0; i < 20 && field.evaluate().isEmpty; i++) {
        await tester.drag(sheet, const Offset(0, -240));
        await tester.pump();
      }
      expect(
        find.descendant(
          of: field,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.tap(field);
      await tester.pump();
      expect(find.text(AppStrings.givingBanksUnavailable), findsNothing);

      hold.complete();
      await tester.pumpAndSettle();
    });

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

    testWidgets('the date of birth is chosen, not typed', (tester) async {
      // A free text field had to carry "YYYY-MM-DD" underneath it and still
      // accepted anything at all. The wheel can only produce the one shape
      // the route documents.
      final api = await pumpForm(
        tester,
        caseWithOwnership(const ['legal_recipient']),
      );
      await fill(tester);

      await tester.tap(find.byKey(const ValueKey('kyc-dob')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.newMediaDone));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const ValueKey('kyc-submit')));
      await tester.tap(find.byKey(const ValueKey('kyc-submit')));
      await tester.pumpAndSettle();

      final sent = api.posted.firstWhere(
        (call) => call.$1 == '/v1/payment/earnings/khaime/kyc',
      );
      final owner =
          ((sent.$2 as Map)['owner'] as Map)['dateOfBirth'] as String?;
      // The wheel opens thirty years back, and Done takes what it shows.
      final expected = DateTime(DateTime.now().year - 30);
      expect(owner, isNotNull);
      expect(owner, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(owner!.startsWith('${expected.year}-'), isTrue);
    });

    testWidgets('a date of birth nobody set is left out, not sent empty', (
      tester,
    ) async {
      final api = await pumpForm(
        tester,
        caseWithOwnership(const ['legal_recipient']),
      );
      await fill(tester);

      await _scrollTo(tester, find.byKey(const ValueKey('kyc-submit')));
      await tester.tap(find.byKey(const ValueKey('kyc-submit')));
      await tester.pumpAndSettle();

      final sent = api.posted.firstWhere(
        (call) => call.$1 == '/v1/payment/earnings/khaime/kyc',
      );
      expect(
        ((sent.$2 as Map)['owner'] as Map).containsKey('dateOfBirth'),
        isFalse,
      );
    });

    testWidgets('the phone number goes out with its country on it', (
      tester,
    ) async {
      // "09032242379" tells a provider nothing about which country it is
      // in. The rail settles to NG, so that is the dial code the field
      // opens on, and the number leaves in E.164.
      final api = await pumpForm(
        tester,
        caseWithOwnership(const ['legal_recipient']),
      );
      await fill(tester);
      await tester.enterText(
        find.byKey(const ValueKey('kyc-phone')),
        '09032242379',
      );
      await tester.pumpAndSettle();

      expect(find.text('+234'), findsOneWidget);

      await _scrollTo(tester, find.byKey(const ValueKey('kyc-submit')));
      await tester.tap(find.byKey(const ValueKey('kyc-submit')));
      await tester.pumpAndSettle();

      final sent = api.posted.firstWhere(
        (call) => call.$1 == '/v1/payment/earnings/khaime/kyc',
      );
      expect(
        ((sent.$2 as Map)['owner'] as Map)['phoneNumber'],
        '+2349032242379',
      );
    });

    testWidgets('a number too short to dial is caught here', (tester) async {
      await pumpForm(tester, caseWithOwnership(const ['legal_recipient']));
      await fill(tester);
      await tester.enterText(find.byKey(const ValueKey('kyc-phone')), '12');
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.byKey(const ValueKey('kyc-submit')));
      await tester.tap(find.byKey(const ValueKey('kyc-submit')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.givingKycPhoneInvalid), findsOneWidget);
    });

    testWidgets('the dial code and the number fit a 320pt phone', (
      tester,
    ) async {
      // A fixed-width box beside an Expanded field is the exact shape that
      // put a red stripe across the settlement dialogs, and the dial button
      // is one: flag, "+234" and a chevron that do not shrink.
      tester.view.physicalSize = const Size(320, 1600) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
            home: GivingKycScreen(
              creatorId: 'c-1',
              rail: GivingRail.fromJson(_activeKhaimeRail),
              application: GivingApplication.fromJson(_draftApplication),
              requirements: RailRequirements.fromJson(
                caseWithOwnership(const ['legal_recipient']),
              ),
              repo: GivingRepo(api: _FakeApi()),
              api: _FakeApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the studio nav bar', () {
    testWidgets('a tab\'s snackbar clears it', (tester) async {
      // The Giving tab's Scaffold sits *under* the shell's floating nav bar
      // in a Stack, so a snackbar at the default offset is painted behind
      // it — shown, and never seen. That is how a step-up refusal used to
      // disappear. This pins the clearance to the bar's real height.
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: StudioNavBar(
                  index: 3,
                  impactBadge: 0,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Plus the padding the shell puts under it.
      final bar = tester.getSize(find.byType(StudioNavBar)).height + 12;
      expect(
        studioNavClearance,
        greaterThanOrEqualTo(bar),
        reason:
            'a snackbar at $studioNavClearance would sit behind a '
            '${bar}pt bar',
      );
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
