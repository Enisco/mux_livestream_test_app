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

/// The mobile→web subscription handoff. This repo never sees PSP credentials:
/// plan, provider and payment all happen on the web surface.
class MobileCheckoutRepo {
  MobileCheckoutRepo({ApiService? api})
    : _api = api ?? GetIt.instance<ApiService>();

  final ApiService _api;

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
  Future<MobileCheckoutHandoff> createSession({
    required String creatorId,
    required String storefrontCountry,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.mobileCheckouts,
        data: {
          'purpose': 'platform_subscription',
          'creatorId': creatorId,
          'platform': platform,
          'storefrontCountry': storefrontCountry,
          'idempotencyKey': idempotencyKey,
        },
      );
      return MobileCheckoutHandoff.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 409) rethrow;
      final body = e.response?.data;
      final details = body is Map ? body['details'] : null;
      throw CheckoutAlreadyActive(
        details is Map ? details['sessionId'] as String? : null,
      );
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
