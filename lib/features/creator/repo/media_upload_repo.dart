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
///
/// The order the media guide documents and Creator Studio itself uses:
///
///  1. `POST /v1/media/drafts` `{creatorId, type, visibility}` → the row,
///     at `status: draft`. It exists before a single byte moves, which is
///     what lets the details save while the file uploads and what leaves
///     an interrupted upload as something the creator can come back to.
///  2. `POST /v1/media/request-upload` `{creatorId, mediaId,
///     expectedMediaUpdatedAt, mediaType, filename, mimeType, size,
///     uploadTarget}` → `{uploadId, uploadUrl, method: PUT, headers,
///     expiresAt, resumable, maxChunkSizeBytes, constraints}`. The URL is
///     Mux's, lives an hour, and is single-use. The ticket is **bound to
///     the row**, and the row's `updatedAt` has to be quoted back.
///  3. The bytes go to that URL as a **PUT** — a plain body, not a form,
///     and nothing of ours attached. This is *not* the S3 presigned POST
///     the images use.
///  4. Optionally `POST /v1/media/thumbnail/upload-url`, which *is* an S3
///     presigned POST, identical in shape to the avatar and banner
///     tickets.
///  5. `PATCH /v1/media/{id}` with the details — title, description,
///     categories, visibility, `thumbnailFileId`, `scheduledAt` — then
///     `POST /v1/media/{id}/publish` `{visibility}` for "publish now".
///
/// `POST /v1/media` (create from a loose `sourceUploadId`) was the older
/// way here. The guide now lists it under "Routes not covered here", with
/// no shipped client and an unconfirmed contract, so it is gone.
///
/// Three things worth keeping in mind:
///
///  * The row may be published **before** the bytes finish. The backend
///    holds the publish until Mux reports ready and sets
///    `publishRequestedAt` meanwhile. The order here still uploads first,
///    so that leaving the screen can never strand a row half-filed.
///  * **Scheduling moved.** It used to ride on create; on this flow it is
///    a `PATCH` field. The guide adds that it is refused for anything that
///    has ever been published, even if unpublished since. Unverified
///    against staging: these routes need a signed-in creator and could not
///    be probed from here.
///  * Two `409`s are the route's own flow control rather than failures:
///    the draft moved on since it was read, and the draft already holds a
///    source. [requestUpload] answers both the way the guide says to, and
///    retries once.
class MediaUploadRepo {
  MediaUploadRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? getIt<ApiService>();

  /// A bare client: the Mux leg must carry neither the app's Authorization
  /// header nor its base URL. The S3 leg goes through [S3PresignedUpload].
  static final _plain = Dio();

  /// Step 1. The row, before anything is uploaded into it.
  ///
  /// Created `private`: nothing is on the channel until publish, and the
  /// creator's real choice is sent with the details in [updateMedia].
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
      // The ticket has to quote `updatedAt` back. Create normally answers
      // the whole row, but the guide's own words are "read the draft, then
      // ask for an upload URL", so a response without one is read again
      // rather than guessed at.
      return draft.updatedAt == null ? await readMedia(draft.id) : draft;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// The row as its creator sees it — `GET /v1/media/{id}`.
  ///
  /// Two callers. The upload wants the `updatedAt` a ticket has to carry,
  /// and a fresh one to recover from a stale one. The **editor** wants the
  /// whole row, which is what this route answers either way.
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
  ///
  /// Both of the route's `409`s are answered here rather than thrown at a
  /// screen, because both have one documented remedy and neither is
  /// anything a creator can act on:
  ///
  ///  * *the draft changed* — read it again and ask again;
  ///  * *already processing an uploaded asset* — drop that source first.
  ///
  /// One retry. A second refusal is a real one.
  ///
  /// Throws [MediaUploadException] with the server's own sentence when the
  /// creator is out of monthly uploads.
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
  ///
  /// `title` is capped at 180 characters, `description` at 5000, and
  /// `categorySlugs` at 8 — all three are the API's own limits. Empty
  /// fields are left out rather than sent blank: this is a draft being
  /// filled in for the first time, so an absent key and an empty one mean
  /// the same thing, and the absent one cannot trip a validator.
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
  ///
  /// The same `PATCH /v1/media/{id}`, with the opposite rule about empties.
  /// [updateMedia] fills a fresh draft in, where an absent key and an empty
  /// one mean the same thing; here an absent key *keeps the old value*, so
  /// a field the creator cleared has to be sent cleared or the change is
  /// silently dropped. Exactly the split between a post's `toJson` and its
  /// `toPatchJson`.
  ///
  /// Two deliberate asymmetries:
  ///
  ///  * **`description` is nullable here, and null means leave it alone.**
  ///    The caller passes it only when it is worth sending — which is
  ///    whenever it changed, an empty string included, because on an edit
  ///    an emptied field is the creator clearing it. The one case left out
  ///    is a row that had no description and still has none: sending `''`
  ///    there would risk a validator refusal to no purpose. If `''` ever
  ///    *is* refused, the creator is told, which beats dropping the change
  ///    in silence. [categorySlugs] is always sent, because the form lets
  ///    the last category be removed and `@ArrayMaxSize` has no quarrel
  ///    with `[]`.
  ///  * **`thumbnailFileId` is sent only when there is a new one.** Passing
  ///    `null` through would *drop* the custom thumbnail, which the guide
  ///    documents and no control on the form asks for.
  ///  * **`visibility` is nullable, and null leaves it alone.** The one
  ///    case is a row whose own `visibility` this client could not read —
  ///    see [FiledMedia.visibility]. Sending a guess there would take a
  ///    public video off the channel on the save that fixed its title.
  ///
  /// [scheduledAt] is tri-state and has to be: set it to schedule, pass
  /// `clearSchedule` to unschedule (an explicit JSON `null`), and leave
  /// both alone to not touch it. Refused outright by the API for anything
  /// that has ever been published, so the caller checks
  /// [FiledMedia.canBeScheduled] first.
  ///
  /// Answers the saved row when the response carries one. A **200 is the
  /// success**, though: a body this client cannot parse is not a reason to
  /// tell a creator their edit failed when it did not, so the answer is
  /// nullable rather than a refusal.
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
      // that stays on the screen can reseed from. Nothing is thrown when
      // it does not: the write already happened, and turning a saved edit
      // into "something went wrong" over a field nobody reads would send
      // a creator back to redo work that is done.
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
    // Codes come last, on purpose. The refusals above are matched on the
    // sentence because the gateway's codes for them are not all known —
    // the quota one may well be a 403 — and a code read first would
    // swallow the message that is worth repeating.
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
