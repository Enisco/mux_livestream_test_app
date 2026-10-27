import 'package:get_it/get_it.dart';

import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The creator's side of Giving: who gets paid, through what, and what came
/// in.
///
/// Three things about these routes shape every method here, all of them
/// probed against staging on 2026-10-26 rather than assumed:
///
/// - **The reporting routes refuse before an application exists.** `summary`,
///   `transactions`, `settlements` and `payouts` all answer *"Giving
///   application not found"* until one is created, so the screen reads the
///   application first and only then asks for figures.
/// - **`GET funds` has a side effect.** It creates the reserved `general`
///   fund idempotently, which is why the list is never empty and why a free
///   plan reports `canCreate: false` the moment it is first read.
/// - **Enrolment and every configuration change are step-up gated.** The
///   grant minted by [verifyStepUp] expires in five minutes and is consumed
///   by the very next call, so it is passed straight through and never
///   stored.
class GivingRepo {
  GivingRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  // ---- The application ---------------------------------------------------

  /// `GET /v1/payment/earnings/application` — null before anything has been
  /// applied for.
  ///
  /// `{application: null}` is **not requested**, which is a different screen
  /// from an application sitting in `draft` with no rails on it.
  Future<GivingApplication?> fetchApplication(String creatorId) async {
    final response = await _api.get(
      ApiEndpoints.givingApplication,
      queryParameters: {'creatorId': creatorId},
    );
    final application = _data(response.data)['application'];
    return application is Map<String, dynamic>
        ? GivingApplication.fromJson(application)
        : null;
  }

  /// `GET .../application/options` — what policy allows right now.
  ///
  /// Re-read before every enrolment. The guide is explicit that this is not
  /// permanent provider capability and must not be cached as such.
  Future<GivingOptions> fetchOptions(String creatorId) async {
    final response = await _api.get(
      ApiEndpoints.givingApplicationOptions,
      queryParameters: {'creatorId': creatorId},
    );
    return GivingOptions.fromJson(_data(response.data));
  }

  /// `POST .../application` — the legal recipient and the terms.
  ///
  /// No step-up here; the grant is spent at rail enrolment. `termsVersion`
  /// must be the one `options` just returned — a version the client made up
  /// is rejected, which is how a creator is kept from accepting stale terms.
  Future<GivingApplication> createApplication({
    required String creatorId,
    required LegalClassification classification,
    required String legalRecipientName,
    required String countryCode,
    required String termsVersion,
  }) async {
    final response = await _api.post(
      ApiEndpoints.givingApplication,
      data: {
        'creatorId': creatorId,
        'legalClassification': classification.wire,
        'legalRecipientName': legalRecipientName,
        'countryCode': countryCode,
        'termsVersion': termsVersion,
        'acceptTerms': true,
      },
    );
    return GivingApplication.fromJson(
      _data(response.data)['application'] as Map<String, dynamic>? ?? const {},
    );
  }

  // ---- Rails -------------------------------------------------------------

  /// `POST .../rails` — enrol one provider, country and settlement currency.
  ///
  /// Consumes an `activate_givings` grant. A second rail for a provider
  /// already enrolled is refused with `CONFLICT`, so the picker hides those
  /// rather than offering a choice that cannot work.
  Future<GivingApplication> enrolRail({
    required String creatorId,
    required PaymentProvider provider,
    required String countryCode,
    required String settlementCurrency,
    required String grantToken,
  }) async {
    final response = await _api.post(
      ApiEndpoints.givingRails,
      data: {
        'creatorId': creatorId,
        'paymentProvider': provider.wire,
        'countryCode': countryCode,
        'settlementCurrency': settlementCurrency,
        'stepUpGrantToken': grantToken,
      },
    );
    return GivingApplication.fromJson(
      _data(response.data)['application'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// `PATCH .../rails/{id}` — take a rail out of donor routing, or break a
  /// tie between two that would pay the same.
  ///
  /// `enabled: false` does not touch verification; payments already in
  /// flight keep reconciling. Lower `priority` wins.
  Future<GivingApplication> updateRail(
    String railId, {
    required String creatorId,
    bool? enabled,
    int? priority,
  }) async {
    final response = await _api.patch(
      ApiEndpoints.givingRail(railId),
      data: {
        'creatorId': creatorId,
        'enabled': ?enabled,
        'priority': ?priority,
      },
    );
    return GivingApplication.fromJson(
      _data(response.data)['application'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// `GET .../application/requirements` — rail-scoped, and each row says
  /// whose move it is.
  Future<RailRequirements> fetchRequirements({
    required String creatorId,
    required String railId,
  }) async {
    final response = await _api.get(
      ApiEndpoints.givingApplicationRequirements,
      queryParameters: {'creatorId': creatorId, 'railId': railId},
    );
    return RailRequirements.fromJson(_data(response.data));
  }

  /// `POST .../application/submit` — hand the GospelTube track over.
  ///
  /// This marks only GospelTube's half as submitted. Provider onboarding is
  /// an independent track and may be done before or after, which is why the
  /// rail screen shows both and gates neither behind the other.
  Future<void> submitApplication({
    required String creatorId,
    required String railId,
  }) async {
    await _api.post(
      ApiEndpoints.givingApplicationSubmit,
      data: {'creatorId': creatorId, 'railId': railId},
    );
  }

  // ---- Step-up -----------------------------------------------------------

  /// `POST /v1/auth/step-up/challenges` — emails a code.
  ///
  /// The response never carries the code itself; it says only where it went
  /// and when another may be asked for.
  Future<StepUpChallenge> createStepUp({
    required String creatorId,
    required String operation,
    String purpose = 'giving_recipient',
  }) async {
    final response = await _api.post(
      ApiEndpoints.stepUpChallenges,
      data: {
        'purpose': purpose,
        'resourceId': creatorId,
        'operation': operation,
      },
    );
    return StepUpChallenge.fromJson(_data(response.data));
  }

  /// `POST .../challenges/{id}/verify` — the one-time grant.
  ///
  /// Five minutes, one use. Returned rather than held so the caller spends
  /// it on the next line and nothing persists it.
  Future<String> verifyStepUp({
    required String challengeId,
    required String code,
  }) async {
    final response = await _api.post(
      ApiEndpoints.stepUpVerify(challengeId),
      data: {'code': code},
    );
    return _data(response.data)['grantToken'] as String? ?? '';
  }

  Future<void> resendStepUp(String challengeId) async {
    await _api.post(ApiEndpoints.stepUpResend(challengeId));
  }

  /// `POST .../change-requests` — a versioned change to a live rail.
  ///
  /// The old configuration keeps taking gifts through review and a 48-hour
  /// cooling period; activation switches new quotes over atomically.
  /// Changing *provider* is not this — that is another rail.
  Future<String> requestConfigurationChange({
    required String creatorId,
    required String railId,
    required String operation,
    required String countryCode,
    required String settlementCurrency,
    required LegalClassification classification,
    required String legalRecipientName,
    required String grantToken,
  }) async {
    final response = await _api.post(
      ApiEndpoints.givingChangeRequests,
      data: {
        'creatorId': creatorId,
        'railId': railId,
        'operation': operation,
        'countryCode': countryCode,
        'settlementCurrency': settlementCurrency,
        'legalClassification': classification.wire,
        'legalRecipientName': legalRecipientName,
        'stepUpGrantToken': grantToken,
      },
    );
    final change = _data(response.data)['changeRequest'];
    return change is Map<String, dynamic> ? change['id'] as String? ?? '' : '';
  }

  Future<void> cancelConfigurationChange({
    required String creatorId,
    required String changeRequestId,
  }) async {
    await _api.post(
      ApiEndpoints.givingChangeRequestCancel(changeRequestId),
      data: {'creatorId': creatorId},
    );
  }

  // ---- Provider onboarding ----------------------------------------------

  /// `GET .../khaime/banks` — payout banks for the rail's currency.
  ///
  /// Refuses with *"This creator has not enrolled a khaime rail"* before
  /// enrolment, so it is only ever called from the rail's own screen.
  Future<List<PayoutBank>> fetchKhaimeBanks({
    required String creatorId,
    String? railId,
    String? currency,
  }) async {
    final response = await _api.get(
      ApiEndpoints.khaimeBanks,
      queryParameters: {
        'creatorId': creatorId,
        'railId': ?railId,
        'currency': ?currency,
      },
    );
    return _list(
      _data(response.data)['banks'],
    ).map(PayoutBank.fromJson).toList();
  }

  /// `POST .../khaime/kyc` — identity and bank, forwarded to Khaime.
  ///
  /// Every file id in the payload must already be accepted evidence on this
  /// rail's case; anything else is refused before the request leaves
  /// GospelTube. Identity numbers and the full account number are forwarded
  /// and never stored here, which is why nothing in this app caches them.
  Future<void> submitKhaimeKyc({
    required String creatorId,
    required String railId,
    required String accountOwnership,
    required String accountType,
    required Map<String, dynamic> owner,
    required Map<String, dynamic> bankAccount,
    Map<String, dynamic>? business,
    bool resubmit = false,
  }) async {
    await _api.post(
      resubmit ? ApiEndpoints.khaimeKycResubmit : ApiEndpoints.khaimeKyc,
      data: {
        'creatorId': creatorId,
        'railId': railId,
        'accountOwnership': accountOwnership,
        'accountType': accountType,
        'owner': owner,
        'bankAccount': bankAccount,
        'business': ?business,
      },
    );
  }

  Future<List<PayoutBank>> fetchPaystackBanks({
    required String creatorId,
    String? railId,
  }) async {
    final response = await _api.get(
      ApiEndpoints.paystackBanks,
      queryParameters: {'creatorId': creatorId, 'railId': ?railId},
    );
    final data = _data(response.data);
    final rows = data['banks'] ?? data['items'];
    return _list(rows).map(PayoutBank.fromJson).toList();
  }

  /// `GET .../paystack/bank-account` — resolve a number to a name.
  ///
  /// Shown for explicit confirmation before the subaccount is created; the
  /// server keeps only the last four digits afterwards.
  Future<String?> resolvePaystackAccount({
    required String creatorId,
    required String bankCode,
    required String accountNumber,
    String? railId,
  }) async {
    final response = await _api.get(
      ApiEndpoints.paystackBankAccount,
      queryParameters: {
        'creatorId': creatorId,
        'bankCode': bankCode,
        'accountNumber': accountNumber,
        'railId': ?railId,
      },
    );
    return _data(response.data)['accountName'] as String?;
  }

  Future<void> createPaystackSubaccount({
    required String creatorId,
    required String railId,
    required String accountOwnership,
    required String settlementBankCode,
    required String accountNumber,
  }) async {
    await _api.post(
      ApiEndpoints.paystackSubaccount,
      data: {
        'creatorId': creatorId,
        'railId': railId,
        'accountOwnership': accountOwnership,
        'settlementBankCode': settlementBankCode,
        'accountNumber': accountNumber,
      },
    );
  }

  /// `POST .../stripe/onboarding-link` — the hosted flow's URL.
  ///
  /// GospelTube collects none of Stripe's identity or bank details itself,
  /// so this is a handoff to the browser and back.
  Future<String?> stripeOnboardingLink({
    required String creatorId,
    required String railId,
    required String accountOwnership,
    required String returnUrl,
    required String refreshUrl,
  }) async {
    final response = await _api.post(
      ApiEndpoints.stripeOnboardingLink,
      data: {
        'creatorId': creatorId,
        'railId': railId,
        'accountOwnership': accountOwnership,
        'returnUrl': returnUrl,
        'refreshUrl': refreshUrl,
      },
    );
    final data = _data(response.data);
    return data['url'] as String? ?? data['onboardingUrl'] as String?;
  }

  // ---- Funds -------------------------------------------------------------

  /// `GET /v1/payment/giving/funds` — the purposes, and the plan's ceiling.
  ///
  /// Creates the reserved `general` fund on first read, so this never comes
  /// back empty for a creator who has one.
  Future<GivingFundList> fetchFunds(
    String creatorId, {
    bool includeInactive = true,
  }) async {
    final response = await _api.get(
      ApiEndpoints.givingFunds,
      queryParameters: {
        'creatorId': creatorId,
        'includeInactive': includeInactive,
      },
    );
    return GivingFundList.fromJson(_data(response.data));
  }

  /// `POST .../funds` — refused over the plan's limit with
  /// *"Giving fund limit reached (N funds on current plan)."*
  ///
  /// The screen checks `limits.canCreate` first, but still handles the
  /// refusal: a slot can go between the read and the write.
  Future<GivingFund> createFund({
    required String creatorId,
    required String name,
    String? description,
  }) async {
    final response = await _api.post(
      ApiEndpoints.givingFunds,
      data: {'creatorId': creatorId, 'name': name, 'description': ?description},
    );
    return GivingFund.fromJson(
      _data(response.data)['fund'] as Map<String, dynamic>? ?? const {},
    );
  }

  /// `PATCH .../funds/{id}` — rename, redescribe, deactivate, reactivate.
  ///
  /// The slug never changes, so links shared earlier keep working. The
  /// `general` fund refuses `active: false`.
  Future<GivingFund> updateFund(
    String fundId, {
    String? name,
    String? description,
    bool? active,
  }) async {
    final response = await _api.patch(
      ApiEndpoints.givingFund(fundId),
      data: {'name': ?name, 'description': ?description, 'active': ?active},
    );
    return GivingFund.fromJson(
      _data(response.data)['fund'] as Map<String, dynamic>? ?? const {},
    );
  }

  // ---- Reporting ---------------------------------------------------------

  /// `GET .../summary` — provider-reported totals, bucketed by currency.
  Future<EarningsSummary> fetchSummary(
    String creatorId, {
    DateTime? from,
    DateTime? to,
    String? fundId,
    String? railId,
  }) async {
    final response = await _api.get(
      ApiEndpoints.earningsSummary,
      queryParameters: _range(creatorId, from, to, fundId, railId),
    );
    return EarningsSummary.fromJson(_data(response.data));
  }

  Future<GivingRecordPage> fetchTransactions(
    String creatorId, {
    DateTime? from,
    DateTime? to,
    String? fundId,
    String? railId,
    String? cursor,
    int limit = 20,
  }) => _records(
    ApiEndpoints.earningsTransactions,
    creatorId,
    from: from,
    to: to,
    fundId: fundId,
    railId: railId,
    cursor: cursor,
    limit: limit,
  );

  Future<GivingRecordPage> fetchSettlements(
    String creatorId, {
    DateTime? from,
    DateTime? to,
    String? fundId,
    String? railId,
    String? cursor,
    int limit = 20,
  }) => _records(
    ApiEndpoints.earningsSettlements,
    creatorId,
    from: from,
    to: to,
    fundId: fundId,
    railId: railId,
    cursor: cursor,
    limit: limit,
  );

  /// `GET .../payouts` — automatic PSP payouts and completed releases.
  ///
  /// `automatic: false` is a release on a provider-held rail, not a pending
  /// request; the row is labelled accordingly.
  Future<GivingRecordPage> fetchPayouts(
    String creatorId, {
    DateTime? from,
    DateTime? to,
    String? fundId,
    String? railId,
    String? cursor,
    int limit = 20,
  }) => _records(
    ApiEndpoints.earningsPayouts,
    creatorId,
    from: from,
    to: to,
    fundId: fundId,
    railId: railId,
    cursor: cursor,
    limit: limit,
  );

  /// `POST .../payouts/request` — withdraw from a provider-held balance.
  ///
  /// Refused while a request is already in flight, which is why the caller
  /// checks `pendingPayout` and disables the action rather than letting a
  /// creator submit and fail. The balance afterwards is re-read from the
  /// summary rather than worked out here.
  Future<void> requestPayout({
    required String creatorId,
    required int amountMinor,
    String? railId,
    String? currency,
  }) async {
    await _api.post(
      ApiEndpoints.earningsPayoutRequest,
      data: {
        'creatorId': creatorId,
        'amountMinor': amountMinor,
        'railId': ?railId,
        'currency': ?currency,
      },
    );
  }

  Future<GivingRecordPage> _records(
    String path,
    String creatorId, {
    DateTime? from,
    DateTime? to,
    String? fundId,
    String? railId,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _api.get(
      path,
      queryParameters: {
        ..._range(creatorId, from, to, fundId, railId),
        'cursor': ?cursor,
        'limit': limit,
      },
    );
    return GivingRecordPage.fromJson(_data(response.data));
  }

  /// The window every reporting route shares.
  ///
  /// `from` is inclusive and `to` exclusive; a reversed range is rejected
  /// server-side rather than silently emptied.
  static Map<String, dynamic> _range(
    String creatorId,
    DateTime? from,
    DateTime? to,
    String? fundId,
    String? railId,
  ) => {
    'creatorId': creatorId,
    'from': ?from?.toUtc().toIso8601String(),
    'to': ?to?.toUtc().toIso8601String(),
    'fundId': ?fundId,
    'railId': ?railId,
  };

  // ---- Envelope helpers --------------------------------------------------

  /// The `{data: ...}` envelope, or nothing.
  ///
  /// Tested rather than cast: a gateway error page or a bare list would make
  /// a cast throw a `TypeError` out of a screen that is already handling a
  /// failure, and an empty map reads the same as an empty answer.
  static Map<String, dynamic> _data(Object? body) {
    final data = body is Map<String, dynamic> ? body['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  static List<Map<String, dynamic>> _list(Object? rows) => [
    for (final row in rows is List ? rows : const [])
      if (row is Map<String, dynamic>) row,
  ];
}
