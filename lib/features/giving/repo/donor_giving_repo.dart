import 'package:get_it/get_it.dart';

import 'package:test_app/models/library_models/give_flow_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// The two reads a Give button needs before it can be drawn or tapped.
///
/// Neither moves money. Capability decides whether the action exists at all;
/// funds decide whether the giver is asked what the gift is for. Everything
/// after that happens on the web surface — see [CheckoutHandoffService].
class DonorGivingRepo {
  DonorGivingRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  /// The batch route's own ceiling. Asking for more is a 400, so a longer
  /// list is split rather than truncated.
  static const batchLimit = 50;

  /// Whether one ministry can accept gifts.
  ///
  /// Public, so this answers for a signed-out reader too — which is the point:
  /// the button has to be right before anyone signs in. An ineligible creator
  /// is `200 {available: false}`, never an error, and the response carries no
  /// reason because the client is forbidden to show one.
  Future<bool> fetchCapability(String creatorId) async {
    final response = await _api.get(ApiEndpoints.givingCapability(creatorId));
    return _data(response.data)['available'] as bool? ?? false;
  }

  /// The same question for a list, in batches of [batchLimit].
  ///
  /// The route preserves input order, but matching on position would make a
  /// dropped row shift every answer after it onto the wrong creator — and a
  /// wrongly-drawn Give button sends a giver at a ministry that cannot be
  /// paid. Each row names its own creator, so the answers are keyed by that.
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
  ///
  /// Reading this *creates* the reserved `general` fund if the ministry has
  /// never had one, so an empty list means the read failed rather than that
  /// there is nothing to give to.
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
