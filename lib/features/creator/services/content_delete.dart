import 'package:test_app/features/creator/repo/event_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/repo/post_repo.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';

/// What came of asking for a piece of content to be removed.
enum ContentDeleteOutcome {
  done,

  /// The member's role does not reach the route. `DELETE /v1/media/:id` is
  /// owners and admins only, so an editor who may upload and edit is still
  /// refused here.
  notAllowed,

  /// Already gone — removed from the web studio, or by another member,
  /// while this screen held the row. Nothing left to do.
  gone,

  network,
  refused,
}

/// Removing a piece of content, whichever of the three services holds it.
///
/// One entry point because the studio's list is one list: media, written
/// posts and calendar events each have their own route, their own exception
/// and their own failure words, and a screen that is showing a row should
/// not have to know which of the three it drew.
abstract final class ContentDelete {
  static Future<ContentDeleteOutcome> run(
    StudioContentItem item, {
    MediaUploadRepo? media,
    PostRepo? posts,
    EventRepo? events,
  }) async {
    try {
      switch (item.kind) {
        case StudioContentKind.video:
        case StudioContentKind.audio:
        case StudioContentKind.livestream:
          await (media ?? MediaUploadRepo()).deleteMedia(item.id);
        case StudioContentKind.post:
          await (posts ?? PostRepo()).delete(item.id);
        case StudioContentKind.event:
          await (events ?? EventRepo()).delete(item.id);
      }
      return ContentDeleteOutcome.done;
    } on MediaUploadException catch (e) {
      return switch (e.failure) {
        MediaUploadFailure.notAllowed => ContentDeleteOutcome.notAllowed,
        MediaUploadFailure.notFound => ContentDeleteOutcome.gone,
        MediaUploadFailure.network => ContentDeleteOutcome.network,
        _ => ContentDeleteOutcome.refused,
      };
    } on PostException catch (e) {
      return switch (e.failure) {
        PostFailure.notAllowed => ContentDeleteOutcome.notAllowed,
        PostFailure.notFound => ContentDeleteOutcome.gone,
        PostFailure.network => ContentDeleteOutcome.network,
        _ => ContentDeleteOutcome.refused,
      };
    } on EventException catch (e) {
      return switch (e.failure) {
        EventFailure.notAllowed => ContentDeleteOutcome.notAllowed,
        EventFailure.notFound => ContentDeleteOutcome.gone,
        EventFailure.network => ContentDeleteOutcome.network,
        _ => ContentDeleteOutcome.refused,
      };
    }
  }
}
