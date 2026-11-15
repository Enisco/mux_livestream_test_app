import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// What the server said went wrong, when it said anything a creator can use.
String? givingProblem(Object error) {
  if (error is! DioException) return null;
  final message = switch (error.response?.data) {
    final Map body => body['error'],
    _ => null,
  };
  if (message is String) {
    final text = message.trim();
    return text.isEmpty ? null : text;
  }
  if (message is List) {
    final lines = [
      for (final line in message)
        if ('$line'.trim().isNotEmpty) '$line'.trim(),
    ];
    if (lines.isNotEmpty) return lines.join('\n');
  }
  return null;
}

/// Raised when another code is asked for inside the resend cooldown.
class StepUpResendTooSoon implements Exception {
  const StepUpResendTooSoon(this.availableAt);

  final DateTime? availableAt;

  @override
  String toString() => 'StepUpResendTooSoon($availableAt)';
}

/// Raised when the server will not take a step-up code.
class StepUpRefused implements Exception {
  const StepUpRefused({this.attemptsExhausted = false});

  final bool attemptsExhausted;

  @override
  String toString() => 'StepUpRefused($attemptsExhausted)';
}

/// The creator's side of Giving: who gets paid, through what, and what came
/// in.
class GivingRepo {
  GivingRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  // ---- The application ---------------------------------------------------

  /// `GET /v1/payment/earnings/application` — null before anything has been
  /// applied for.
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
  Future<GivingOptions> fetchOptions(String creatorId) async {
    final response = await _api.get(
      ApiEndpoints.givingApplicationOptions,
      queryParameters: {'creatorId': creatorId},
    );
    return GivingOptions.fromJson(_data(response.data));
  }

  /// `POST .../application` — the legal recipient and the terms.
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
  Future<String> verifyStepUp({
    required String challengeId,
    required String code,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.stepUpVerify(challengeId),
        data: {'code': code},
      );
      return _data(response.data)['grantToken'] as String? ?? '';
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != 400 && status != 401) rethrow;
      final body = e.response?.data;
      final reason = body is Map ? '${body['error']}' : '';
      // Matched on the server's own words because the refusal carries no
      // code of its own: both cases are a bare 401.
      throw StepUpRefused(
        attemptsExhausted: reason.toLowerCase().contains('attempts'),
      );
    }
  }

  /// Rotates the code and sends it again, returning the refreshed challenge.
  Future<StepUpChallenge> resendStepUp(String challengeId) async {
    try {
      final response = await _api.post(ApiEndpoints.stepUpResend(challengeId));
      return StepUpChallenge.fromJson(_data(response.data));
    } on DioException catch (e) {
      final body = e.response?.data;
      final details = body is Map ? body['details'] : null;
      final at = details is Map ? details['resendAvailableAt'] : null;
      if (at == null) rethrow;
      throw StepUpResendTooSoon(DateTime.tryParse(at.toString())?.toLocal());
    }
  }

  /// `POST .../change-requests` — a versioned change to a live rail.
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
  static Map<String, dynamic> _data(Object? body) {
    final data = body is Map<String, dynamic> ? body['data'] : null;
    return data is Map<String, dynamic> ? data : const {};
  }

  static List<Map<String, dynamic>> _list(Object? rows) => [
    for (final row in rows is List ? rows : const [])
      if (row is Map<String, dynamic>) row,
  ];
}
