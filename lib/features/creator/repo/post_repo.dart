import 'package:dio/dio.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/content_asset_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/models/creator_models/post_draft_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Filing an article.
class PostRepo {
  PostRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? getIt<ApiService>();

  late final _assets = ContentAssetRepo(_injected);

  static const coverMaxBytes = ContentAssetRepo.maxBytes;

  /// Step 1. `kind` is the cover or an inline body image.
  Future<String> uploadImage({
    required String creatorId,
    required ContentAssetKind kind,
    required PickedImage image,
  }) async {
    try {
      final fileId = await _assets.upload(
        creatorId: creatorId,
        kind: kind,
        image: image,
      );
      if (fileId == null) throw const PostException(PostFailure.rejected);
      return fileId;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 2. Returns the new post's id.
  Future<String> create({
    required String creatorId,
    required PostDraft draft,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.contentPosts,
        data: draft.toJson(creatorId),
      );
      final id = (response.data['data'] as Map<String, dynamic>?)?['id'];
      if (id is! String || id.isEmpty) {
        throw const PostException(PostFailure.rejected);
      }
      return id;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// What is already filed, so the editor can open it.
  Future<EditablePost> load(String postId) async {
    try {
      final response = await _api.get(ApiEndpoints.contentPostById(postId));
      final row = (response.data as Map?)?['data'];
      if (row is! Map<String, dynamic>) {
        throw const PostException(PostFailure.rejected);
      }
      return EditablePost(
        draft: PostDraft.fromJson(row),
        coverKey: row['coverThumbnailKey'] as String?,
        status: row['status'] as String? ?? '',
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Save an edit. `PATCH /v1/content/posts/{id}`.
  Future<void> update({
    required String postId,
    required PostDraft draft,
  }) async {
    try {
      await _api.patch(
        ApiEndpoints.contentPostById(postId),
        data: draft.toPatchJson(),
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 3. The post publishes itself at [at]; nothing else is needed.
  Future<void> schedule({required String postId, required DateTime at}) async {
    try {
      await _api.patch(
        ApiEndpoints.contentPostById(postId),
        data: {'scheduledAt': at.toUtc().toIso8601String()},
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// `DELETE /v1/content/posts/{id}`. Any cover image goes with it.
  Future<void> delete(String postId) async {
    try {
      await _api.delete(ApiEndpoints.contentPostById(postId));
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 4.
  Future<void> publish(String postId) async {
    try {
      await _api.post(
        ApiEndpoints.publishContentPost(postId),
        data: const <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// What each `![alt](file:{id})` in [body] currently resolves to, so the
  /// preview can show the picture rather than the token.
  Future<List<BodyEmbed>> resolveEmbeds({
    required String creatorId,
    required String body,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.contentPostBodyEmbeds,
        data: {'creatorId': creatorId, 'body': body},
      );
      final rows =
          (response.data['data'] as Map<String, dynamic>?)?['bodyEmbeds'];
      return [
        if (rows is List)
          for (final row in rows)
            if (row is Map<String, dynamic>) BodyEmbed.fromJson(row),
      ];
    } catch (e) {
      // A preview that cannot resolve its pictures still shows its words.
      logger.w('Could not resolve body embeds', error: e);
      return const [];
    }
  }

  static PostException _translate(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const PostException(PostFailure.network);
    }

    final said = _sentence(e.response?.data);
    logger.w('Post refused: $said', error: e);
    final lower = said?.toLowerCase() ?? '';
    if (lower.contains('add post content')) {
      return const PostException(PostFailure.needsBody);
    }
    if (lower.contains('title must be')) {
      return const PostException(PostFailure.needsTitle);
    }
    if (lower.contains('scheduledat must be in the future')) {
      return const PostException(PostFailure.scheduleInPast);
    }
    return switch (e.response?.statusCode) {
      404 => const PostException(PostFailure.notFound),
      401 || 403 => const PostException(PostFailure.notAllowed),
      _ => PostException(PostFailure.rejected, said),
    };
  }

  static String? _sentence(dynamic payload) {
    if (payload is! Map) return null;
    final error = payload['error'];
    if (error is String && error.isNotEmpty) return error;
    if (error is List && error.isNotEmpty) return error.join('. ');
    return null;
  }
}

/// A post as the editor needs it: the fields a write takes, plus the two
/// read-only things the screen shows — where the cover picture is, and
/// whether this is still a draft.
class EditablePost {
  const EditablePost({required this.draft, this.coverKey, this.status = ''});

  final PostDraft draft;

  /// `coverThumbnailKey` — a CDN key, not a file id.
  final String? coverKey;

  /// `draft`, `scheduled`, `published` or `archived`.
  final String status;

  bool get isPublished => status == 'published';
}

/// Why an article could not be filed, in terms the screen can explain.
enum PostFailure {
  needsTitle,
  needsBody,
  scheduleInPast,

  /// 404. Already gone — removed from the web studio, or by someone else.
  notFound,

  /// 401 or 403. The member's role does not reach this route, or the
  /// session has expired.
  notAllowed,

  network,
  rejected,
}

class PostException implements Exception {
  const PostException(this.failure, [this.message]);

  final PostFailure failure;
  final String? message;

  @override
  String toString() => 'PostException($failure, $message)';
}
