import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Raised when the creator already has a live checkout attempt. The server
/// hands back the offending session so the app can resume it instead of
/// stranding the creator.
class CheckoutAlreadyActive implements Exception {
  const CheckoutAlreadyActive(this.sessionId);

  final String? sessionId;

  @override
  String toString() => 'CheckoutAlreadyActive($sessionId)';
}

/// Raised when the ministry cannot take a gift right now.
///
/// Shares a **409** with [CheckoutAlreadyActive], which is why the two are
/// told apart by the session id the body carries rather than by status. The
/// public capability projection normally keeps the app from getting here, but
/// it is cached and a rail can be paused between the check and the tap.
class GivingUnavailable implements Exception {
  const GivingUnavailable();

  @override
  String toString() => 'GivingUnavailable()';
}

/// Raised when the server will not attribute the gift to the content it was
/// offered from.
///
/// `sourceMediaId` is validated when the session is created, and the
/// permitted set is **narrower than "media the giver can watch"**: probing on
/// 2026-10-29 found a live session accepted while an ordinary video, a music
/// row and even the replay of that same livestream were all refused with
/// `403 "Giving source media is not accessible."`. Attribution is a nicety;
/// the gift is not, so the caller drops the source and offers it anyway.
class GivingSourceRejected implements Exception {
  const GivingSourceRejected();

  @override
  String toString() => 'GivingSourceRejected()';
}

/// The mobile→web checkout handoff, for both products that use it:
/// a creator's platform subscription and a reader's gift to a ministry.
///
/// This repo never sees PSP credentials. Plan, amount, currency, provider and
/// payment all happen on the web surface; the app's share is a durable session
/// and a short-lived ticket into a browser.
class MobileCheckoutRepo {
  MobileCheckoutRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  /// Resolved on use, not on construction — see [CreatorRepo].
  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  static const subscriptionPurpose = 'platform_subscription';
  static const givingPurpose = 'giving';

  static String get platform => Platform.isIOS ? 'ios' : 'android';

  Future<CheckoutCapabilities> fetchCapabilities({
    required String storefrontCountry,
  }) async {
    final response = await _api.get(
      ApiEndpoints.mobileCheckoutCapabilities,
      queryParameters: {
        'platform': platform,
        'storefrontCountry': storefrontCountry,
      },
    );
    return CheckoutCapabilities.fromJson(response.data as Map<String, dynamic>);
  }

  /// Creates the durable attempt. Replaying [idempotencyKey] returns the same
  /// session with a fresh launch ticket, which is how a resumed attempt works.
  ///
  /// [purpose] is fixed for the life of the session and is the only thing that
  /// distinguishes the two products on the wire. The three optional fields
  /// belong to giving alone: [preferredFundSlug] preselects a purpose on the
  /// web surface, and [sourceMediaId] attributes the gift to the content it
  /// was offered from.
  Future<MobileCheckoutHandoff> createSession({
    required String creatorId,
    required String storefrontCountry,
    required String idempotencyKey,
    String purpose = subscriptionPurpose,
    String? preferredFundSlug,
    String? sourceMediaId,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.mobileCheckouts,
        data: {
          'purpose': purpose,
          'creatorId': creatorId,
          'platform': platform,
          'storefrontCountry': storefrontCountry,
          'idempotencyKey': idempotencyKey,
          'preferredFundSlug': ?preferredFundSlug,
          'sourceMediaId': ?sourceMediaId,
        },
      );
      return MobileCheckoutHandoff.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final details = body is Map ? body['details'] : null;
      final sessionId = details is Map ? details['sessionId'] as String? : null;

      // Source media the server will not attribute to. Only giving sends one.
      if (status == 403 && sourceMediaId != null) {
        throw const GivingSourceRejected();
      }
      if (status != 409) rethrow;
      // Both products refuse with 409, meaning different things: a
      // subscription already has a live attempt (and names it), while a
      // ministry simply cannot be given to. Reading the giving refusal as a
      // live attempt would send the giver to resume a session that does not
      // exist.
      if (sessionId == null && purpose == givingPurpose) {
        throw const GivingUnavailable();
      }
      throw CheckoutAlreadyActive(sessionId);
    }
  }

  Future<MobileCheckoutSession> fetchSession(String id) async {
    final response = await _api.get(ApiEndpoints.mobileCheckout(id));
    return MobileCheckoutSession.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Mints a replacement launch ticket. Tickets live about a minute, so a
  /// resumed attempt always needs one.
  Future<MobileCheckoutLaunch> relaunch(String id) async {
    final response = await _api.post(ApiEndpoints.mobileCheckoutLaunch(id));
    return MobileCheckoutLaunch.fromJson(response.data as Map<String, dynamic>);
  }

  /// Abandons the browser attempt. This is not subscription cancellation, and
  /// a session whose PSP checkout already started stays `processing`.
  Future<MobileCheckoutSession> cancel(String id) async {
    final response = await _api.post(ApiEndpoints.mobileCheckoutCancel(id));
    return MobileCheckoutSession.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
