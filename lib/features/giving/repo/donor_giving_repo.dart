import 'package:get_it/get_it.dart';

import 'package:test_app/models/library_models/give_flow_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The two reads a Give button needs before it can be drawn or tapped.
class DonorGivingRepo {
  DonorGivingRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  /// The batch route's own ceiling. Asking for more is a 400, so a longer
  /// list is split rather than truncated.
  static const batchLimit = 50;

  /// Whether one ministry can accept gifts.
  Future<bool> fetchCapability(String creatorId) async {
    final response = await _api.get(ApiEndpoints.givingCapability(creatorId));
    return _data(response.data)['available'] as bool? ?? false;
  }

  /// The same question for a list, in batches of [batchLimit].
  Future<Map<String, bool>> fetchCapabilities(List<String> creatorIds) async {
    final ids = {
      for (final id in creatorIds)
        if (id.isNotEmpty) id,
    }.toList();
    final out = <String, bool>{};
    for (var i = 0; i < ids.length; i += batchLimit) {
      final chunk = ids.sublist(
        i,
        i + batchLimit > ids.length ? ids.length : i + batchLimit,
      );
      final response = await _api.post(
        ApiEndpoints.givingCapabilities,
        data: {'creatorIds': chunk},
      );
      for (final row in _data(response.data)['items'] as List? ?? const []) {
        if (row is! Map<String, dynamic>) continue;
        final id = row['creatorId'] as String?;
        if (id != null && id.isNotEmpty) {
          out[id] = row['available'] as bool? ?? false;
        }
      }
    }
    return out;
  }

  /// The purposes this ministry offers, active ones only.
  Future<List<GivingFundOption>> fetchFunds(String creatorId) async {
    final response = await _api.get(ApiEndpoints.givingCreatorFunds(creatorId));
    return [
      for (final row in _data(response.data)['funds'] as List? ?? const [])
        if (row is Map<String, dynamic>) GivingFundOption.fromJson(row),
    ];
  }

  static Map<String, dynamic> _data(Object? body) {
    final data = (body as Map<String, dynamic>?)?['data'];
    return data is Map<String, dynamic> ? data : const {};
  }
}
