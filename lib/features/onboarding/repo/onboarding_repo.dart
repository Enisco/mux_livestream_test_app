import 'dart:async';

import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/onboarding_models/onboarding_state.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

class OnboardingRepo {
  OnboardingRepo({ApiService? api})
    : _api = api ?? GetIt.instance<ApiService>();

  final ApiService _api;

  Future<void> updateViewerPreferences({
    List<String>? categorySlugs,
    String? discoverySource,
    String? discoveryDetail,
  }) async {
    final body = <String, dynamic>{
      'categorySlugs': ?categorySlugs,
      if (discoverySource != null && discoverySource.isNotEmpty)
        'registrationDiscoverySource': discoverySource,
      if (discoveryDetail != null && discoveryDetail.isNotEmpty)
        'registrationDiscoveryDetail': discoveryDetail,
    };
    if (body.isEmpty) return;
    await _api.patch(ApiEndpoints.viewerPreferences, data: body);
  }

  /// Records where the reader has got to in the funnel.
  Future<void> updateOnboardingState({
    OnboardingStatus? status,
    OnboardingIntentState? intent,
    OnboardingStep? step,
    OnboardingCreatorType? creatorType,
    String? creatorId,
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status.slug,
      if (intent != null) 'intent': intent.slug,
      if (step != null) 'step': step.slug,
      if (creatorType != null) 'creatorType': creatorType.slug,
      if (creatorId != null && creatorId.isNotEmpty) 'creatorId': creatorId,
    };
    if (body.isEmpty) return;
    try {
      await _api.patch(ApiEndpoints.onboardingState, data: body);
    } catch (e) {
      logger.w('Could not record onboarding state $body', error: e);
    }
  }
}

/// Records funnel state without ever getting in the way.
void recordOnboardingState({
  OnboardingStatus? status,
  OnboardingIntentState? intent,
  OnboardingStep? step,
  OnboardingCreatorType? creatorType,
  String? creatorId,
}) {
  try {
    unawaited(
      GetIt.instance<OnboardingRepo>().updateOnboardingState(
        status: status,
        intent: intent,
        step: step,
        creatorType: creatorType,
        creatorId: creatorId,
      ),
    );
  } catch (e) {
    logger.w('Onboarding state not recorded', error: e);
  }
}
