import 'package:get_it/get_it.dart';

import 'package:test_app/models/discovery_models/media_detail.dart';
import 'package:test_app/models/discovery_models/vertical_feed_item.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

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
    String? shareToken,
  }) async {
    final params = <String, dynamic>{
      'includeSuggestions': includeSuggestions,
      if (includeSuggestions) 'suggestionsLimit': 10,
    };
    if (clientSessionId != null) params['clientSessionId'] = clientSessionId;
    // Required for unlisted media opened from a share link.
    if (shareToken != null) params['shareToken'] = shareToken;

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
    String? anchorMediaId,
    String? anchorCreatorId,
    List<String> prioritizeMediaIds = const [],
    bool includeServerContinueWatching = false,
  }) async {
    final body = <String, dynamic>{
      // Contract: 10–20, defaults to 15.
      'limit': limit.clamp(10, 20),
      'mode': mode,
      'excludeMediaIds': excludeMediaIds,
    };
    if (cursor != null) body['cursor'] = cursor;
    if (anchorMediaId != null) body['anchorMediaId'] = anchorMediaId;
    if (anchorCreatorId != null) body['anchorCreatorId'] = anchorCreatorId;
    if (prioritizeMediaIds.isNotEmpty) {
      body['prioritizeMediaIds'] = prioritizeMediaIds;
    }
    if (includeServerContinueWatching) {
      body['includeServerContinueWatching'] = true;
    }

    final response = await _api.post(ApiEndpoints.verticalFeed, data: body);
    return VerticalFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PlaybackInfo?> fetchPlaybackInfo(
    String mediaId, {
    String? clientSessionId,
    bool usePublicRoute = false,
    String? shareToken,
  }) async {
    final params = <String, dynamic>{};
    if (clientSessionId != null) params['clientSessionId'] = clientSessionId;
    if (shareToken != null) params['shareToken'] = shareToken;

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
