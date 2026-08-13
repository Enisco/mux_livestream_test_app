import 'package:get_it/get_it.dart';

import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Writes the answers collected during onboarding back to the user record.
class OnboardingRepo {
  final ApiService _api = GetIt.instance<ApiService>();

  /// `PATCH /v1/user/me/viewer-preferences`. All fields optional;
  /// `categorySlugs` come from `GET /v1/user/categories`.
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
}
