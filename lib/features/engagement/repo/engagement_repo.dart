import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

class EngagementRepo {
  final ApiService _api = GetIt.instance<ApiService>();

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
      // The API answers `{"active": bool}`. `added` was never a field it sent,
      // so reading it made every un-like read back as a like.
      final active = data['active'] ?? data['added'];
      if (active is bool) return active;
    }
    logger.w('toggleInteraction: no "active" in response, assuming on');
    return true;
  }

  /// The viewer's own like/save state for a page of rows, in one call.
  ///
  /// Without this every card renders unliked until its detail is opened. The
  /// route is authenticated — guests have no state to fetch, so callers skip it.
  ///
  /// Returns interaction types keyed by target id, e.g. `{id: {'like'}}`.
  Future<Map<String, Set<String>>> fetchMyInteractions({
    required String targetType,
    required List<String> targetIds,
  }) async {
    final ids = targetIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};

    final result = <String, Set<String>>{};
    // `targetIds` is one comma-separated string; chunked so a long feed page
    // cannot produce an over-length URL.
    for (var i = 0; i < ids.length; i += _batchSize) {
      final chunk = ids.skip(i).take(_batchSize).toList();
      try {
        final response = await _api.get(
          ApiEndpoints.myInteractionsBatch,
          queryParameters: {
            'targetType': targetType,
            'targetIds': chunk.join(','),
          },
        );
        final body = response.data;
        final data = body is Map<String, dynamic> ? body['data'] : null;
        final map = data is Map<String, dynamic> ? data['interactions'] : null;
        if (map is! Map<String, dynamic>) continue;
        for (final entry in map.entries) {
          final types = entry.value;
          if (types is! List) continue;
          result[entry.key] = types.whereType<String>().toSet();
        }
      } catch (e) {
        // Engagement state is decoration: a failure must not blank the feed.
        logger.w('fetchMyInteractions($targetType) failed', error: e);
      }
    }
    return result;
  }

  static const _batchSize = 50;

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

  /// Replies to one comment.
  Future<CommentsResponse> fetchReplies({
    required String commentId,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _api.get(
      ApiEndpoints.publicCommentReplies(commentId),
      queryParameters: {'limit': limit, 'cursor': ?cursor},
    );
    if (response.data is! Map<String, dynamic>) {
      return CommentsResponse(items: const []);
    }
    return CommentsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Posts a comment, or a reply when [parentCommentId] is given.
  Future<MediaComment?> postComment({
    required String targetType,
    required String targetId,
    required String body,
    String? parentCommentId,
  }) async {
    final response = await _api.post(
      ApiEndpoints.comments,
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'body': body,
        'parentCommentId': ?parentCommentId,
      },
    );
    final data = response.data is Map<String, dynamic>
        ? (response.data as Map<String, dynamic>)['data']
        : null;
    if (data is! Map<String, dynamic>) return null;
    return MediaComment.fromJson(data);
  }

  /// Votes on a comment. Sending the vote already held clears it.
  Future<MediaComment?> voteComment({
    required String commentId,
    required CommentVote vote,
  }) async {
    final response = await _api.post(
      ApiEndpoints.commentVote(commentId),
      data: {'vote': vote.wire},
    );
    final data = response.data is Map<String, dynamic>
        ? (response.data as Map<String, dynamic>)['data']
        : null;
    if (data is! Map<String, dynamic>) return null;
    return MediaComment.fromJson(data);
  }

  Future<void> deleteComment(String commentId) async {
    await _api.delete(ApiEndpoints.comment(commentId));
  }
}
