import 'package:get_it/get_it.dart';

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
}
