import 'dart:async';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/models/discovery_models/vertical_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';

/// The like/follow wiring for one page of the vertical feed.
///
/// The same reason [FeedCardActions] exists, for the one surface it cannot
/// serve: that class speaks `WebFeedItem` and the feed's rows are
/// [VerticalFeedItem]s. Keeping the four steps here rather than inside a
/// screen that cannot be widget-tested — its pages build real media_kit
/// players — is what makes the behaviour testable at all, which matters
/// because these buttons shipped inert once already.
///
/// Every row in this feed is media, so the target type is never in question.
class VerticalFeedActions {
  const VerticalFeedActions({
    required this.store,
    required this.requireAccount,
  });

  final EngagementStore store;

  /// Returns whether the viewer may act, showing the sign-in sheet if not.
  final bool Function(String feature) requireAccount;

  /// The counts the row arrived with, used until the store knows better.
  static EngagementState baselineOf(VerticalFeedItem item) => EngagementState(
    likes: item.likeCount ?? 0,
    comments: item.commentCount ?? 0,
  );

  EngagementState stateOf(VerticalFeedItem item) =>
      store.resolve(InteractionTargets.media, item.mediaId, baselineOf(item));

  bool isFollowing(VerticalFeedItem item) => store.isFollowing(item.creatorId);

  void like(VerticalFeedItem item) {
    if (item.mediaId.isEmpty || !requireAccount('like this video')) return;
    unawaited(
      store.toggleLike(
        targetType: InteractionTargets.media,
        targetId: item.mediaId,
        fallback: baselineOf(item),
      ),
    );
  }

  void follow(VerticalFeedItem item) {
    if (item.creatorId.isEmpty || !requireAccount('follow this creator')) {
      return;
    }
    unawaited(store.toggleFollow(item.creatorId));
  }

  /// Record what a page of rows says, so the hearts carry real counts before
  /// anyone touches them.
  ///
  /// Only the counts: whether *this* viewer liked a row is a separate
  /// batched read the feed route does not answer.
  static void seedRows(EngagementStore store, List<VerticalFeedItem> rows) {
    for (final row in rows) {
      if (row.mediaId.isEmpty) continue;
      store.seed(
        targetType: InteractionTargets.media,
        targetId: row.mediaId,
        likes: row.likeCount,
        comments: row.commentCount,
      );
    }
  }
}
