import 'package:get_it/get_it.dart';

import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/models/discovery_models/content_detail.dart';
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
    List<String>? entityTypes,
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
      if (entityTypes != null && entityTypes.isNotEmpty)
        'entityTypes': entityTypes,
      if (liveOnly ?? false) 'liveOnly': true,
      if (useViewerCategoryPrefs ?? false) 'useViewerCategoryPrefs': true,
    };
    if (cursor != null) body['cursor'] = cursor;

    final response = await _api.post(ApiEndpoints.webFeed, data: body);
    return WebFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST /v1/search/public/query` — global discovery across every indexed
  /// entity, unauthenticated.
  ///
  /// Two things to know before calling it:
  ///
  /// - **Omit [q] for a browse.** An empty query with a `sort` is the
  ///   supported way to build a catalogue rail; a `"*"` wildcard is not and
  ///   will not behave.
  /// - **`sort: "trending"` is media-only** by contract — the gateway
  ///   rejects other entity types for it.
  ///
  /// [entityIds] narrows to exactly those rows, which is how a rail of bare
  /// references is hydrated in one round trip. Search ranks by relevance, so
  /// the caller must restore its own order afterwards.
  ///
  /// The route also takes `preferenceBoostCategorySlugs`, a soft relevance
  /// boost towards the viewer's own topics. Nothing in this app's design asks
  /// for it — `user-app` uses it for a "topics you follow" rail we do not
  /// have — so it is not plumbed through; add it here when a surface wants
  /// it.
  Future<WebFeedResponse> searchPublic({
    String? q,
    List<String>? entityTypes,
    List<String>? categorySlugs,
    List<String>? entityIds,
    bool? liveOnly,
    String? mediaType,
    String sort = 'relevance',
    int size = 10,
    String? cursor,
  }) async {
    final filters = <Map<String, dynamic>>[
      if (categorySlugs != null && categorySlugs.isNotEmpty)
        {'field': 'categorySlugs', 'values': categorySlugs},
      if (entityIds != null && entityIds.isNotEmpty)
        {'field': 'entityId', 'values': entityIds},
      if (liveOnly ?? false) {'field': 'media.isLiveNow', 'value': true},
      // Video and audio share the `media` entity type; this is what tells
      // them apart, and it is a server filter rather than a client sift.
      if (mediaType != null) {'field': 'media.mediaType', 'value': mediaType},
    ];
    final response = await _api.post(
      ApiEndpoints.publicSearch,
      data: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (entityTypes != null && entityTypes.isNotEmpty)
          'entityTypes': entityTypes,
        if (filters.isNotEmpty) 'filters': filters,
        'sort': sort,
        'size': size,
        'cursor': ?cursor,
      },
    );
    return WebFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Type-ahead over the same index.
  ///
  /// Returns real entities — `{entityType, entityId, title, subtitle}` — not
  /// query strings, so a suggestion can open the thing itself rather than
  /// running a search for its name. `size` is 1–20; anything outside that is
  /// refused by the gateway.
  ///
  /// **Undocumented**; see [ApiEndpoints.publicSearchAutocomplete].
  Future<List<WebFeedItem>> autocomplete(
    String q, {
    List<String>? entityTypes,
    int size = 8,
  }) async {
    if (q.trim().isEmpty) return const [];
    final response = await _api.get(
      ApiEndpoints.publicSearchAutocomplete,
      queryParameters: {
        'q': q.trim(),
        'size': size.clamp(1, 20),
        if (entityTypes != null && entityTypes.isNotEmpty)
          'entityTypes': entityTypes.join(','),
      },
    );
    return WebFeedResponse.fromJson(
      response.data as Map<String, dynamic>,
    ).items;
  }

  /// `GET /v1/analytics/viewer/continue-watching` — **bare references**, with
  /// no title and no thumbnail. Hydrate them with [searchPublic] and
  /// `entityIds`, then put them back in this order.
  ///
  /// Signed-in only; a rail built from it is hidden for anonymous readers
  /// rather than rendered empty.
  Future<List<ContinueWatchingRef>> fetchContinueWatching({
    int limit = 10,
  }) async {
    final response = await _api.get(
      ApiEndpoints.continueWatching,
      queryParameters: {'limit': limit},
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    final items = data is Map<String, dynamic> ? data['items'] : null;
    return [
      for (final row in items as List? ?? const [])
        if (row is Map<String, dynamic>) ContinueWatchingRef.fromJson(row),
    ];
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

  Future<CreatorProfile> fetchCreatorById(String creatorId) async {
    final response = await _api.get(ApiEndpoints.creatorById(creatorId));
    return CreatorProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CreatorProfile> fetchCreatorByHandle(String handle) async {
    final response = await _api.get(
      ApiEndpoints.creatorByHandle(handle.replaceFirst('@', '')),
    );
    return CreatorProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// The profile's Latest tab — same row shape as the home feed.
  Future<WebFeedResponse> fetchCreatorFeed(
    String creatorId, {
    String? cursor,
    int limit = 8,
  }) async {
    final response = await _api.get(
      ApiEndpoints.creatorFeed(creatorId),
      queryParameters: {'limit': limit, 'cursor': ?cursor},
    );
    return WebFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// One Library section. Valid sections are series, videos, music,
  /// devotionals, posts and events — the server rejects anything else.
  Future<WebFeedResponse> fetchCreatorLibrary(
    String creatorId,
    String section, {
    String? cursor,
    int limit = 16,
  }) async {
    final response = await _api.get(
      ApiEndpoints.creatorLibrary(creatorId, section),
      queryParameters: {'limit': limit, 'cursor': ?cursor},
    );
    return WebFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CreatorTestimony>> fetchCreatorTestimonies(
    String creatorId, {
    int limit = 20,
  }) async {
    final response = await _api.get(
      ApiEndpoints.publicTestimonies,
      queryParameters: {'creatorId': creatorId, 'limit': limit},
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    final items = data is Map<String, dynamic>
        ? data['items'] as List<dynamic>? ?? const []
        : const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CreatorTestimony.fromJson)
        .toList();
  }

  Future<ContentPost> fetchPost(String id) async {
    final response = await _api.get(ApiEndpoints.publicPost(id));
    return ContentPost.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DevotionalSeriesDetail> fetchDevotionalSeries(String id) async {
    final response = await _api.get(ApiEndpoints.publicDevotionalSeries(id));
    return DevotionalSeriesDetail.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Records a devotional day as read.
  ///
  /// The series detail carries `viewerProgress` but nothing wrote to it, so a
  /// reader's place was lost the moment they left the screen.
  Future<void> setDevotionalEntryProgress(
    String entryId, {
    String status = 'completed',
  }) async {
    await _api.post(
      ApiEndpoints.devotionalEntryProgress(entryId),
      data: {'status': status},
    );
  }

  Future<MediaSeriesDetail> fetchMediaSeries(String id) async {
    final response = await _api.get(ApiEndpoints.publicMediaSeries(id));
    return MediaSeriesDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<EventDetail> fetchEvent(String id) async {
    final response = await _api.get(ApiEndpoints.publicEvent(id));
    return EventDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// Paginates the "Up next" list beyond what the detail aggregate inlines.
  /// Only `popular` and `recent` are supported here — not `trending`.
  Future<WebFeedResponse> fetchContentSuggestions({
    required String targetType,
    required String targetId,
    String sort = 'popular',
    int limit = 10,
    String? cursor,
    List<String> excludeEntityIds = const [],
  }) async {
    final response = await _api.post(
      ApiEndpoints.contentSuggestions,
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'limit': limit,
        'sort': sort,
        'cursor': ?cursor,
        if (excludeEntityIds.isNotEmpty) 'excludeEntityIds': excludeEntityIds,
      },
    );
    return WebFeedResponse.fromJson(response.data as Map<String, dynamic>);
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
