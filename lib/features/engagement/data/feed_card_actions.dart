import 'package:flutter/widgets.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/views/comments_sheet.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';

/// The like/save wiring every surface that shows feed cards needs.
class FeedCardActions {
  const FeedCardActions({required this.store, required this.requireAccount});

  final EngagementStore store;

  /// Returns whether the viewer may act, showing the sign-in sheet if not.
  final bool Function(String feature) requireAccount;

  /// Null for a row that cannot carry interactions — a creator or a media
  /// series — so its buttons stay inert rather than posting a rejected call.
  VoidCallback? like(WebFeedItem item) => _action(item, 'like this', (t) {
    store.toggleLike(
      targetType: t,
      targetId: item.entityId,
      fallback: baselineOf(item),
    );
  });

  VoidCallback? save(WebFeedItem item) => _action(item, 'save this', (t) {
    store.toggleSave(
      targetType: t,
      targetId: item.entityId,
      fallback: baselineOf(item),
    );
  });

  /// Follows or unfollows the creator behind a row.
  VoidCallback? follow(WebFeedItem item) {
    final creatorId = item.profileCreatorId;
    if (creatorId == null || creatorId.isEmpty) return null;
    return () {
      if (!requireAccount('follow creators')) return;
      store.toggleFollow(creatorId, fallback: item.isFollowingCreator);
    };
  }

  /// Opens the row's thread over the surface it was tapped on.
  VoidCallback? comment(BuildContext context, WebFeedItem item) {
    final target = InteractionTargets.fromEntityType(item.entityType);
    if (target == null || item.entityId.isEmpty) return null;
    return () => openComments(
      context,
      targetType: target,
      targetId: item.entityId,
      initialCount: store
          .resolve(target, item.entityId, baselineOf(item))
          .comments,
    );
  }

  VoidCallback? _action(
    WebFeedItem item,
    String feature,
    void Function(String targetType) run,
  ) {
    final target = InteractionTargets.fromEntityType(item.entityType);
    if (target == null || item.entityId.isEmpty) return null;
    return () {
      if (!requireAccount(feature)) return;
      run(target);
    };
  }

  /// The counts the row itself carries, used when the store has never seen it.
  static EngagementState baselineOf(WebFeedItem item) => EngagementState(
    likes: item.facets.likes,
    saves: item.facets.favorites,
    comments: item.facets.comments,
  );

  /// The rows still worth drawing. A creator blocked or muted, and a row
  /// hidden or reported, leave every list the moment the reader says so —
  /// the page on screen was fetched before they acted, and the backend's
  /// own suppression only reaches the *next* page.
  ///
  /// Call this inside a `ListenableBuilder` on the store, or the list will
  /// not redraw when one of those flags moves.
  static List<WebFeedItem> visibleRows(
    EngagementStore store,
    List<WebFeedItem> rows,
  ) => rows
      .where(
        (row) => !store.hidesRow(
          creatorId: row.profileCreatorId,
          targetId: row.entityId,
        ),
      )
      .toList(growable: false);

  /// Records what a page of rows says, so cards show real counts before anyone
  /// touches them.
  static void seedRows(EngagementStore store, List<WebFeedItem> rows) {
    for (final row in rows) {
      store.seed(
        targetType: InteractionTargets.fromEntityType(row.entityType),
        targetId: row.entityId,
        likes: row.facets.likes,
        saves: row.facets.favorites,
        comments: row.facets.comments,
      );
    }
  }
}
