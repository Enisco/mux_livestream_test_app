import 'dart:io';

import 'package:dio/dio.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/services/creator_media_picker.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Getting a video or a piece of audio onto the platform, **draft-first**,
/// and editing one that is already there.
class MediaUploadRepo {
  MediaUploadRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? getIt<ApiService>();

  /// A bare client: the Mux leg must carry neither the app's Authorization
  /// header nor its base URL. The S3 leg goes through [S3PresignedUpload].
  static final _plain = Dio();

  /// Step 1. The row, before anything is uploaded into it.
  Future<FiledMedia> createDraft({
    required String creatorId,
    required MediaUploadKind kind,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.mediaDrafts,
        data: {
          'creatorId': creatorId,
          'type': kind.slug,
          'visibility': MediaVisibility.private.slug,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final draft = data == null ? null : FiledMedia.fromJson(data);
      if (draft == null || !draft.isUsable) {
        throw const MediaUploadException(MediaUploadFailure.rejected);
      }
      // The ticket has to quote `updatedAt` back.
      return draft.updatedAt == null ? await readMedia(draft.id) : draft;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// The row as its creator sees it — `GET /v1/media/{id}`.
  Future<FiledMedia> readMedia(String mediaId) async {
    try {
      final response = await _api.get(ApiEndpoints.mediaById(mediaId));
      final data = response.data['data'] as Map<String, dynamic>?;
      final row = data == null ? null : FiledMedia.fromJson(data);
      if (row == null || !row.isUsable) {
        throw const MediaUploadException(MediaUploadFailure.rejected);
      }
      return row;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Removes the row and the Mux asset with it, or cancels an upload still
  /// processing. **Owners and admins only** — an editor who may create and
  /// edit media is refused here, which reaches a screen as `notAllowed`.
  Future<void> deleteMedia(String mediaId) async {
    try {
      await _api.delete(ApiEndpoints.mediaById(mediaId));
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Drops the uploaded file and keeps the details, putting the row back
  /// to `draft`. How a file is replaced; **409** for anything published.
  Future<void> removeSource(String mediaId) async {
    try {
      await _api.delete(ApiEndpoints.mediaSource(mediaId));
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 2. A Mux ticket bound to [draft].
  Future<MediaUploadTicket> requestUpload({
    required String creatorId,
    required MediaUploadKind kind,
    required PickedMediaFile file,
    required FiledMedia draft,
  }) async {
    try {
      return await _ticket(
        creatorId: creatorId,
        kind: kind,
        file: file,
        draft: draft,
      );
    } on MediaUploadException catch (e) {
      if (e.failure != MediaUploadFailure.draftChanged &&
          e.failure != MediaUploadFailure.sourceAlreadyUploaded) {
        rethrow;
      }
      if (e.failure == MediaUploadFailure.sourceAlreadyUploaded) {
        await removeSource(draft.id);
      }
      return _ticket(
        creatorId: creatorId,
        kind: kind,
        file: file,
        draft: await readMedia(draft.id),
      );
    }
  }

  Future<MediaUploadTicket> _ticket({
    required String creatorId,
    required MediaUploadKind kind,
    required PickedMediaFile file,
    required FiledMedia draft,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.mediaRequestUpload,
        data: {
          'creatorId': creatorId,
          'mediaId': draft.id,
          'expectedMediaUpdatedAt': ?draft.updatedAt?.toUtc().toIso8601String(),
          'mediaType': kind.slug,
          'filename': file.filename,
          'mimeType': file.mimeType,
          'size': file.size,
          'uploadTarget': CreatorMediaPicker.target.name,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final ticket = data == null ? null : MediaUploadTicket.fromJson(data);
      if (ticket == null || !ticket.isUsable) {
        throw const MediaUploadException(MediaUploadFailure.rejected);
      }
      // Honour the server's ceiling over the one compiled in.
      if (ticket.maxSizeBytes case final max? when file.size > max) {
        throw const MediaUploadException(MediaUploadFailure.tooLarge);
      }
      return ticket;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 2. Streams the file straight to Mux, reporting progress as it
  /// goes. Cancelling the token aborts it.
  Future<void> putFile({
    required MediaUploadTicket ticket,
    required PickedMediaFile file,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _plain.requestUri<void>(
        Uri.parse(ticket.uploadUrl),
        // The file is opened as a stream: it is never held in memory.
        data: File(file.path).openRead(),
        cancelToken: cancelToken,
        onSendProgress: onProgress,
        options: Options(
          method: ticket.method,
          headers: {
            ...ticket.headers,
            Headers.contentTypeHeader: file.mimeType,
            // Dio cannot measure a stream, and Mux will not take a chunked
            // body, so the length has to be declared.
            Headers.contentLengthHeader: file.size,
          },
          validateStatus: (code) => code != null && code < 400,
        ),
      );
      logger.i('Uploaded ${file.filename} (${file.size}B) to Mux');
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const MediaUploadException(MediaUploadFailure.cancelled);
      }
      throw _translate(e);
    }
  }

  /// Step 3. The same three-step S3 handshake the avatar and banner use:
  /// ticket, presigned **POST**, and nothing to confirm — naming the
  /// `fileId` on the media row is what promotes the key out of quarantine.
  Future<String> uploadThumbnail({
    required String creatorId,
    required PickedImage image,
  }) async {
    try {
      final ticket = await _api.post(
        ApiEndpoints.mediaThumbnailUploadUrl,
        data: {
          'creatorId': creatorId,
          'filename': image.filename,
          'mimeType': image.mimeType,
          'size': image.size,
        },
      );

      final data = ticket.data['data'] as Map<String, dynamic>?;
      final fileId = data?['fileId'] as String?;
      final uploadUrl = data?['uploadUrl'] as String?;
      final fields = (data?['fields'] as Map<String, dynamic>?) ?? const {};
      if (fileId == null || uploadUrl == null || fields.isEmpty) {
        throw const MediaUploadException(MediaUploadFailure.rejected);
      }

      await S3PresignedUpload.send(
        uploadUrl: uploadUrl,
        fields: fields,
        bytes: image.bytes,
        filename: image.filename,
      );
      return fileId;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 5. The details, onto the row that already holds the bytes.
  Future<void> updateMedia({
    required String mediaId,
    required String title,
    required MediaVisibility visibility,
    String? description,
    List<String> categorySlugs = const [],
    String? thumbnailFileId,
    DateTime? scheduledAt,
  }) async {
    try {
      await _api.patch(
        ApiEndpoints.mediaById(mediaId),
        data: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (categorySlugs.isNotEmpty) 'categorySlugs': categorySlugs,
          'visibility': visibility.slug,
          'thumbnailFileId': ?thumbnailFileId,
          if (scheduledAt != null)
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        },
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Saving an **edit** of a row that already exists.
  Future<FiledMedia?> saveEdits({
    required String mediaId,
    required String title,
    MediaVisibility? visibility,
    String? description,
    List<String> categorySlugs = const [],
    String? thumbnailFileId,
    DateTime? scheduledAt,
    bool clearSchedule = false,
  }) async {
    try {
      final response = await _api.patch(
        ApiEndpoints.mediaById(mediaId),
        data: {
          'title': title,
          'description': ?description,
          'categorySlugs': categorySlugs,
          'visibility': ?visibility?.slug,
          'thumbnailFileId': ?thumbnailFileId,
          if (clearSchedule)
            'scheduledAt': null
          else if (scheduledAt != null)
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        },
      );
      // Every one of these routes answers the whole row, which a caller
      // that stays on the screen can reseed from.
      final data = response.data['data'] as Map<String, dynamic>?;
      final row = data == null ? null : FiledMedia.fromJson(data);
      return row != null && row.isUsable ? row : null;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 4b. Only for "publish now" — a scheduled row publishes itself.
  Future<void> publish({
    required String mediaId,
    required MediaVisibility visibility,
  }) async {
    try {
      await _api.post(
        ApiEndpoints.publishMedia(mediaId),
        data: {'visibility': visibility.slug},
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// The gateway answers a list of sentences under `error`. The monthly
  /// quota is the one worth repeating verbatim: it names a number the
  /// dashboard context does not carry (OPEN_ISSUES 19).
  static MediaUploadException _translate(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const MediaUploadException(MediaUploadFailure.network);
    }

    final said = _sentence(e.response?.data);
    logger.w('Media upload rejected: $said', error: e);
    final lower = said?.toLowerCase() ?? '';
    if (lower.contains('upload limit')) {
      return MediaUploadException(MediaUploadFailure.quotaReached, said);
    }
    if (lower.contains('exceeds max allowed size')) {
      return const MediaUploadException(MediaUploadFailure.tooLarge);
    }
    if (lower.contains('unsupported mime type')) {
      return const MediaUploadException(MediaUploadFailure.unsupportedFormat);
    }
    // The route's own flow control; [requestUpload] answers both.
    if (lower.contains('draft changed')) {
      return const MediaUploadException(MediaUploadFailure.draftChanged);
    }
    if (lower.contains('already processing')) {
      return const MediaUploadException(
        MediaUploadFailure.sourceAlreadyUploaded,
      );
    }
    if (lower.contains('sourceuploadid is invalid or expired')) {
      return const MediaUploadException(MediaUploadFailure.ticketExpired);
    }
    // `scheduledAt must be in the future` — the sheet guards against it, but
    // a slow upload can still carry a moment past its own deadline.
    if (lower.contains('scheduledat must be in the future')) {
      return const MediaUploadException(MediaUploadFailure.scheduleInPast);
    }
    // Codes come last, on purpose.
    return switch (e.response?.statusCode) {
      404 => const MediaUploadException(MediaUploadFailure.notFound),
      401 || 403 => const MediaUploadException(MediaUploadFailure.notAllowed),
      _ => MediaUploadException(MediaUploadFailure.rejected, said),
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
