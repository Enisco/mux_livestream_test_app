import 'package:flutter/widgets.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/views/comments_sheet.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';

/// The like/save wiring every surface that shows feed cards needs.
///
/// Home, search and a creator's profile all render the same card and all need
/// the same three steps — resolve the row's interaction target, check for an
/// account, tell the store. Writing that out per screen is how the buttons
/// ended up working on none of them, so it lives here once.
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
  ///
  /// No account check: reading a thread is public, and the sheet gates its own
  /// composer. Null for a row the comments API has no target for.
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
