import 'package:dio/dio.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/content_asset_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/models/creator_models/event_draft_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';

/// Filing a calendar event.
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

  /// What is already filed, so the editor can open it.
  Future<EditableEvent> load(String eventId) async {
    try {
      final response = await _api.get(ApiEndpoints.calendarEventById(eventId));
      final row = (response.data as Map?)?['data'];
      if (row is! Map<String, dynamic>) {
        throw const EventException(EventFailure.rejected);
      }
      return EditableEvent(
        draft: EventDraft.fromJson(row),
        coverKey: row['coverImageKey'] as String?,
        status: row['status'] as String? ?? '',
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Save an edit. `PATCH /v1/content/calendar/events/{id}`.
  Future<void> update({
    required String eventId,
    required EventDraft draft,
  }) async {
    try {
      await _api.patch(
        ApiEndpoints.calendarEventById(eventId),
        data: draft.toPatchJson(),
      );
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// `DELETE /v1/content/calendar/events/{id}`. RSVPs go with it.
  Future<void> delete(String eventId) async {
    try {
      await _api.delete(ApiEndpoints.calendarEventById(eventId));
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Step 3. Publish now, or schedule the listing for later.
  Future<void> publish(String eventId, {DateTime? scheduledAt}) async {
    try {
      await _api.post(
        ApiEndpoints.publishCalendarEvent(eventId),
        data: {'scheduledAt': ?scheduledAt?.toUtc().toIso8601String()},
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
    return switch (e.response?.statusCode) {
      404 => const EventException(EventFailure.notFound),
      401 || 403 => const EventException(EventFailure.notAllowed),
      _ => EventException(EventFailure.rejected, said),
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

/// An event as the editor needs it: the fields a write takes, plus where
/// the cover picture is and what state the event is in.
class EditableEvent {
  const EditableEvent({required this.draft, this.coverKey, this.status = ''});

  final EventDraft draft;

  /// `coverImageKey` — a CDN key, not a file id.
  final String? coverKey;

  /// `draft`, `scheduled`, `published`, `cancelled` or `completed`.
  final String status;

  bool get isPublished => status == 'published';
}

/// Why an event could not be filed, in terms the screen can explain.
enum EventFailure {
  needsDescription,
  needsAddress,
  needsMeetingUrl,

  /// "Invalid schedule" — an end before a start, or a timezone the API
  /// does not know.
  badSchedule,

  /// 404. Already gone — removed from the web studio, or by someone else.
  notFound,

  /// 401 or 403. The member's role does not reach this route, or the
  /// session has expired.
  notAllowed,

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
