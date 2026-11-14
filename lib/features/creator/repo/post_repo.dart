import 'package:dio/dio.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/content_asset_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/models/creator_models/post_draft_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Filing an article.
///
/// Four calls, all exercised against staging:
///
///  1. `POST /v1/content/assets/upload-url` — the cover, and every inline
///     image. See [ContentAssetRepo].
///  2. `POST /v1/content/posts` → the post, at `status: draft`.
///  3. `PATCH /v1/content/posts/{id}` — the only place `scheduledAt` is
///     taken, which flips the status to `scheduled`.
///  4. `POST /v1/content/posts/{id}/publish` (no body) → `published`.
///
/// What staging taught that the guide does not say:
///
///  * **`title` is required to create at all**, 1–500 characters. The
///    design calls the headline optional; the API does not.
///  * `body` may be empty on a draft, but publishing refuses it: *"Add
///    post content before publishing this post"*.
///  * `scheduledAt` is **refused on create** and accepted only on PATCH,
///    and must be in the future — the same guard media has.
///  * An inline image resolves to `available: false, reason: not_uploaded`
///    until a saved post names it. That is an unsaved draft, not an error.
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
  ///
  /// `GET /v1/content/posts/{id}` answers the full `ContentPost`. The
  /// cover arrives as a *pair*: `coverThumbnailFileId` is what a write
  /// takes, `coverThumbnailKey` is where the picture is. [PostDraft] holds
  /// the id; the key comes back beside it here so the screen can show what
  /// the creator already chose instead of an empty cover slot.
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
  ///
  /// Publishing state is left alone: a creator correcting a typo in a
  /// published post expects it to stay published, and one fixing a draft
  /// expects it to stay a draft.
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
    return PostException(PostFailure.rejected, said);
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
enum PostFailure { needsTitle, needsBody, scheduleInPast, network, rejected }

class PostException implements Exception {
  const PostException(this.failure, [this.message]);

  final PostFailure failure;
  final String? message;

  @override
  String toString() => 'PostException($failure, $message)';
}
