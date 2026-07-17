import 'package:get_it/get_it.dart';

import '../../../services/api_service.dart';
import '../../../utils/api_endpoints.dart';
import '../models/media_detail.dart';
import '../models/vertical_feed_item.dart';
import '../models/web_feed_item.dart';

class DiscoveryRepo {
  final ApiService _api = GetIt.instance<ApiService>();

  Future<WebFeedResponse> fetchWebFeed({
    String? cursor,
    int limit = 20,
    String mode = 'mixed',
    String sort = 'recent',
  }) async {
    final body = <String, dynamic>{
      'limit': limit,
      'mode': mode,
      'sort': sort,
      'excludeEntityIds': <String>[],
    };
    if (cursor != null) body['cursor'] = cursor;

    final response = await _api.post(ApiEndpoints.webFeed, data: body);
    return WebFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MediaDetailData> fetchMediaDetail(
    String mediaId, {
    String? clientSessionId,
    bool includeSuggestions = true,
  }) async {
    final params = <String, dynamic>{
      'includeSuggestions': includeSuggestions,
      if (includeSuggestions) 'suggestionsLimit': 10,
    };
    if (clientSessionId != null) params['clientSessionId'] = clientSessionId;

    final response = await _api.get(
      ApiEndpoints.mediaDetail(mediaId),
      queryParameters: params,
    );
    return MediaDetailData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VerticalFeedResponse> fetchVerticalFeed({
    String? cursor,
    int limit = 15,
    String mode = 'mixed',
    List<String> excludeMediaIds = const [],
  }) async {
    final body = <String, dynamic>{
      'limit': limit,
      'mode': mode,
      'excludeMediaIds': excludeMediaIds,
    };
    if (cursor != null) body['cursor'] = cursor;

    final response = await _api.post(ApiEndpoints.verticalFeed, data: body);
    return VerticalFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PlaybackInfo?> fetchPlaybackInfo(
    String mediaId, {
    String? clientSessionId,
    bool usePublicRoute = false,
  }) async {
    final params = <String, dynamic>{};
    if (clientSessionId != null) params['clientSessionId'] = clientSessionId;

    final endpoint = usePublicRoute
        ? ApiEndpoints.publicMediaPlaybackInfo(mediaId)
        : ApiEndpoints.mediaPlaybackInfo(mediaId);

    final response = await _api.get(
      endpoint,
      queryParameters: params.isEmpty ? null : params,
    );
    final body = response.data as Map<String, dynamic>?;
    final data = body?['data'];
    if (data is! Map<String, dynamic>) return null;
    return PlaybackInfo.fromJson(data);
  }
}
