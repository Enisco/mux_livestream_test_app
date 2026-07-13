import 'package:get_it/get_it.dart';

import '../../../core/logger.dart';
import '../../../services/api_service.dart';
import '../../../utils/api_endpoints.dart';
import '../models/engagement_models.dart';

class EngagementRepo {
  final ApiService _api = GetIt.instance<ApiService>();

  /// Returns true if the interaction was added, false if it was removed (toggle).
  Future<bool> toggleInteraction({
    required String targetType,
    required String targetId,
    required String interactionType,
  }) async {
    final response = await _api.post(
      ApiEndpoints.interactions,
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'interactionType': interactionType,
      },
    );
    final body = response.data;
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is Map<String, dynamic>) {
      return data['added'] as bool? ?? true;
    }
    logger.d('toggleInteraction: no "added" field in response, assuming added');
    return true;
  }

  Future<CommentsResponse> fetchComments({
    required String targetType,
    required String targetId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'targetType': targetType,
      'targetId': targetId,
      'limit': limit,
    };
    if (cursor != null) params['cursor'] = cursor;
    final response = await _api.get(
      ApiEndpoints.publicComments,
      queryParameters: params,
    );
    if (response.data is! Map<String, dynamic>) {
      return CommentsResponse(items: const []);
    }
    return CommentsResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
