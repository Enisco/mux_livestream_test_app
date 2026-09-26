import 'package:get_it/get_it.dart';

import 'package:test_app/models/subscription_models/subscription_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Who the reader follows, and how loudly each may speak.
///
/// The Manage following screen ran on a hardcoded list for want of these
/// routes. It has them now:
///
///  * `GET /v1/discovery/following-creators` — the list, with `followedAt`,
///    `latestContentAt` and the four `notifyOn*` flags.
///  * `POST /v1/creator/{id}/subscribe` — **upserts**. Called with no body it
///    follows; called with the flags it rewrites them, which is the only way
///    to change a notification level (there is no PATCH).
///  * `DELETE /v1/creator/{id}/subscribe` — unfollows.
///
/// Live status is deliberately absent from the following payload, so it is
/// not guessed here — see [FollowingRepo.fetchLiveCreatorIds].
class FollowingRepo {
  FollowingRepo({ApiService? api}) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? GetIt.instance<ApiService>();

  Future<List<FollowedMinistry>> fetchFollowing({int limit = 100}) async {
    final response = await _api.get(
      ApiEndpoints.followingCreators,
      queryParameters: {'limit': limit},
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    final rows = data is Map<String, dynamic>
        ? (data['items'] as List? ?? const [])
        : const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) FollowedMinistry.fromJson(row),
    ];
  }

  /// The creators who are broadcasting right now.
  ///
  /// Nothing on the following payload says whether a ministry is live, and
  /// inventing it is how the screen ended up showing two ministries as
  /// permanently "Live now". This asks the feed the question it can actually
  /// answer — `liveOnly: true` — and takes the creator ids off the result.
  Future<Set<String>> fetchLiveCreatorIds() async {
    final response = await _api.post(
      ApiEndpoints.webFeed,
      data: {'limit': 50, 'mode': 'explore_only', 'liveOnly': true},
    );
    final data = (response.data as Map<String, dynamic>)['data'];
    final rows = data is Map<String, dynamic>
        ? (data['items'] as List? ?? const [])
        : const [];
    return {
      for (final row in rows)
        if (row is Map<String, dynamic>)
          ...[
            (row['creator'] as Map<String, dynamic>?)?['creatorId'] as String?,
            (row['meta'] as Map<String, dynamic>?)?['creatorId'] as String?,
          ].whereType<String>(),
    };
  }

  Future<void> unfollow(String creatorId) async {
    await _api.delete(ApiEndpoints.creatorSubscribe(creatorId));
  }

  /// Rewrites the notification flags. The route upserts, so this also
  /// re-follows if the subscription had lapsed.
  Future<void> setNotifyLevel(String creatorId, NotifyLevel level) async {
    await _api.post(
      ApiEndpoints.creatorSubscribe(creatorId),
      data: level.toFlags(),
    );
  }

  Future<void> follow(String creatorId) async {
    await _api.post(ApiEndpoints.creatorSubscribe(creatorId), data: const {});
  }
}
