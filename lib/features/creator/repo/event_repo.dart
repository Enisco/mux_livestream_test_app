import 'package:dio/dio.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/content_asset_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/models/creator_models/event_draft_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Filing a calendar event.
///
/// Three calls, all exercised against staging:
///
///  1. `POST /v1/content/assets/upload-url` `{creatorId, category, filename,
///     mimeType, size}` → an S3 presigned **POST** ticket, the same shape
///     the channel photo and banner use. `category` is `cover` or
///     `body_image`; the image must be JPEG, PNG or WebP and **8 MB** or
///     less.
///  2. `POST /v1/content/calendar/events` → the event, at `status: draft`.
///  3. `POST /v1/content/calendar/events/{id}/publish` → `status:
///     published`.
///
/// What staging taught that the guide does not say:
///
///  * `venueType` is **`physical` | `virtual` | `hybrid`**. `in_person` is
///    refused, though that is what the design's first card is called.
///  * Creating needs only `creatorId`, `title`, `venueType` and
///    `schedule{startAt, timezone}`. **Publishing** needs more, and says
///    which: a description always, a street address and city for anything
///    physical, a meeting link for anything virtual.
///  * `schedule.timezone` is required and validated as an IANA name —
///    `Mars/Olympus` and an empty string are both "Invalid schedule".
///  * There is **no scheduled publish**. `publishAt` and `scheduledAt` are
///    refused on create and on PATCH, and the publish route quietly ignores
///    any body it is given, so passing one would look like it worked
///    (OPEN_ISSUES 29).
///  * `recurrence.mode` accepts only `none`, and there is no series field
///    of any name (OPEN_ISSUES 28).
class EventRepo {
  EventRepo([ApiService? api]) : _injected = api;

  final ApiService? _injected;

  ApiService get _api => _injected ?? getIt<ApiService>();

  /// What the cover ticket will take, which it states rather than carrying
  /// a `constraints` block the way the media routes do.
  static const coverMaxBytes = ContentAssetRepo.maxBytes;

  late final _assets = ContentAssetRepo(_injected);

  /// Step 1. Returns the `fileId` to name on the event.
  Future<String> uploadCover({
    required String creatorId,
    required PickedImage image,
  }) async {
    try {
      final fileId = await _assets.upload(
        creatorId: creatorId,
        kind: ContentAssetKind.cover,
        image: image,
      );
      if (fileId == null) throw const EventException(EventFailure.rejected);
      return fileId;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 2. Returns the new event's id.
  Future<String> create({
    required String creatorId,
    required EventDraft draft,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.calendarEvents,
        data: draft.toJson(creatorId),
      );
      final id = (response.data['data'] as Map<String, dynamic>?)?['id'];
      if (id is! String || id.isEmpty) {
        throw const EventException(EventFailure.rejected);
      }
      return id;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 3. Takes no body worth sending — anything passed is ignored.
  Future<void> publish(String eventId) async {
    try {
      await _api.post(
        ApiEndpoints.publishCalendarEvent(eventId),
        data: const <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  static EventException _translate(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const EventException(EventFailure.network);
    }

    final said = _sentence(e.response?.data);
    logger.w('Event refused: $said', error: e);
    final lower = said?.toLowerCase() ?? '';
    // The publish check names what is missing; the screen guards against
    // all three beforehand, so reaching one of these means something was
    // changed elsewhere between the check and the call.
    if (lower.contains('description is required')) {
      return const EventException(EventFailure.needsDescription);
    }
    if (lower.contains('street address and city')) {
      return const EventException(EventFailure.needsAddress);
    }
    if (lower.contains('virtual meeting link')) {
      return const EventException(EventFailure.needsMeetingUrl);
    }
    if (lower.contains('invalid schedule')) {
      return const EventException(EventFailure.badSchedule);
    }
    return EventException(EventFailure.rejected, said);
  }

  static String? _sentence(dynamic payload) {
    if (payload is! Map) return null;
    final error = payload['error'];
    if (error is String && error.isNotEmpty) return error;
    if (error is List && error.isNotEmpty) return error.join('. ');
    return null;
  }
}

/// Why an event could not be filed, in terms the screen can explain.
enum EventFailure {
  needsDescription,
  needsAddress,
  needsMeetingUrl,

  /// "Invalid schedule" — an end before a start, or a timezone the API
  /// does not know.
  badSchedule,

  network,
  rejected,
}

class EventException implements Exception {
  const EventException(this.failure, [this.message]);

  final EventFailure failure;
  final String? message;

  @override
  String toString() => 'EventException($failure, $message)';
}
