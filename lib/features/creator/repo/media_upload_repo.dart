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

/// Getting a video or a piece of audio onto the platform.
///
/// Four calls, all exercised against staging:
///
///  1. `POST /v1/media/request-upload` `{creatorId, mediaType, filename,
///     mimeType, size, uploadTarget}` → `{uploadId, uploadUrl, method: PUT,
///     headers, expiresAt, resumable, maxChunkSizeBytes, constraints}`. The
///     URL is Mux's, lives an hour, and is single-use.
///  2. The bytes go to that URL as a **PUT** — a plain body, not a form, and
///     nothing of ours attached. This is *not* the S3 presigned POST the
///     images use.
///  3. Optionally `POST /v1/media/thumbnail/upload-url`, which *is* an S3
///     presigned POST, identical in shape to the avatar and banner tickets.
///  4. `POST /v1/media` with `sourceUploadId` (and `thumbnailFileId`), then
///     `POST /v1/media/{id}/publish` `{visibility}`.
///
/// Two things staging taught that the guide does not say:
///
///  * The row may be created, and even published, **before** the bytes
///    finish. The backend holds the publish until Mux reports ready. The
///    order here still uploads first, so that leaving the screen can never
///    strand a row in `processing` with no bytes coming.
///  * Scheduling lives on **create**, not on publish: `POST /v1/media`
///    accepts `scheduledAt`, the row sits at `status: scheduled`, and the
///    backend publishes it within about twenty seconds of that moment.
///    `POST /publish` refuses `scheduledAt` outright, and media has no
///    `scheduledTimezone` — that is a livestream field.
class MediaUploadRepo {
  MediaUploadRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? getIt<ApiService>();

  /// A bare client: the Mux leg must carry neither the app's Authorization
  /// header nor its base URL. The S3 leg goes through [S3PresignedUpload].
  static final _plain = Dio();

  /// Step 1. Throws [MediaUploadException] with the server's own sentence
  /// when the creator is out of monthly uploads.
  Future<MediaUploadTicket> requestUpload({
    required String creatorId,
    required MediaUploadKind kind,
    required PickedMediaFile file,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.mediaRequestUpload,
        data: {
          'creatorId': creatorId,
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

  /// Step 4a. Returns the new media id.
  ///
  /// `title` is required and capped at 180 characters, `description` at
  /// 5000, and `categorySlugs` at 8 — all three are the API's own limits.
  Future<String> createMedia({
    required String creatorId,
    required MediaUploadKind kind,
    required String uploadId,
    required String title,
    required MediaVisibility visibility,
    String? description,
    List<String> categorySlugs = const [],
    String? thumbnailFileId,
    DateTime? scheduledAt,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.createMedia,
        data: {
          'creatorId': creatorId,
          'type': kind.slug,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (categorySlugs.isNotEmpty) 'categorySlugs': categorySlugs,
          'visibility': visibility.slug,
          'sourceUploadId': uploadId,
          'thumbnailFileId': ?thumbnailFileId,
          if (scheduledAt != null)
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        },
      );
      final id = (response.data['data'] as Map<String, dynamic>?)?['id'];
      if (id is! String || id.isEmpty) {
        throw const MediaUploadException(MediaUploadFailure.rejected);
      }
      return id;
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
    if (lower.contains('sourceuploadid is invalid or expired')) {
      return const MediaUploadException(MediaUploadFailure.ticketExpired);
    }
    // `scheduledAt must be in the future` — the sheet guards against it, but
    // a slow upload can still carry a moment past its own deadline.
    if (lower.contains('scheduledat must be in the future')) {
      return const MediaUploadException(MediaUploadFailure.scheduleInPast);
    }
    return MediaUploadException(MediaUploadFailure.rejected, said);
  }

  static String? _sentence(dynamic payload) {
    if (payload is! Map) return null;
    final error = payload['error'];
    if (error is String && error.isNotEmpty) return error;
    if (error is List && error.isNotEmpty) return error.join('. ');
    return null;
  }
}
