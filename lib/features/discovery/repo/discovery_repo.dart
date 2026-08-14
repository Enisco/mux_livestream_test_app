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
    List<String>? categorySlugs,
    bool? liveOnly,
    bool? useViewerCategoryPrefs,
  }) async {
    final body = <String, dynamic>{
      'limit': limit,
      'mode': mode,
      'sort': sort,
      'excludeEntityIds': <String>[],
      if (categorySlugs != null && categorySlugs.isNotEmpty)
        'categorySlugs': categorySlugs,
      if (liveOnly ?? false) 'liveOnly': true,
      if (useViewerCategoryPrefs ?? false) 'useViewerCategoryPrefs': true,
    };
    if (cursor != null) body['cursor'] = cursor;

    final response = await _api.post(ApiEndpoints.webFeed, data: body);
    return WebFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Suggestions for the empty Following tab.
  Future<List<RecommendedCreator>> fetchRecommendedCreators({
    int limit = 10,
  }) async {
    final response = await _api.get(
      ApiEndpoints.recommendedCreators,
      queryParameters: {'limit': limit},
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    final items = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? const []
        : const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(RecommendedCreator.fromJson)
        .toList();
  }

  /// "Here's what's coming up" on the empty Live tab.
  Future<List<WebFeedItem>> fetchUpcomingEvents({int limit = 10}) async {
    final response = await _api.get(
      ApiEndpoints.upcomingEvents,
      queryParameters: {'limit': limit},
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    final items = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? const []
        : const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(WebFeedItem.fromJson)
        .toList();
  }

  /// Follow / unfollow a ministry.
  Future<void> setFollowing(String creatorId, {required bool follow}) async {
    final path = ApiEndpoints.creatorSubscribe(creatorId);
    if (follow) {
      await _api.post(path);
    } else {
      await _api.delete(path);
    }
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
