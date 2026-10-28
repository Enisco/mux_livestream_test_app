import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/data/vertical_feed_actions.dart';
import 'package:test_app/models/discovery_models/vertical_feed_item.dart';

/// The feed's right-hand rail, which shipped inert.
///
/// Every button there called an auth guard that returned true for a
/// signed-in reader and then did nothing — so for everyone with an account,
/// liking, following and commenting on a video in the feed were no-ops. What
/// these pin down is that each one now reaches the shared store, that the
/// counts come from it rather than from the row, and that the guard still
/// stops a signed-out reader before anything is posted.
class _Recorder {
  final List<(String, String, String)> interactions = [];
  final List<(String, bool)> follows = [];

  bool refuse = false;

  Future<bool> toggle({
    required String targetType,
    required String targetId,
    required String interactionType,
  }) async {
    if (refuse) throw StateError('refused');
    interactions.add((targetType, targetId, interactionType));
    // The server is the authority on which way it landed; it lands on.
    return true;
  }

  Future<void> setFollowing(String creatorId, {required bool follow}) async {
    if (refuse) throw StateError('refused');
    follows.add((creatorId, follow));
  }
}

({EngagementStore store, _Recorder api}) _store() {
  final api = _Recorder();
  return (
    store: EngagementStore(toggle: api.toggle, setFollowing: api.setFollowing),
    api: api,
  );
}

VerticalFeedItem _item({
  String mediaId = 'm1',
  String creatorId = 'c1',
  int? likes = 12,
  int? comments = 3,
}) => VerticalFeedItem(
  mediaId: mediaId,
  creatorId: creatorId,
  title: 'Sunday Service',
  type: 'video',
  isLiveNow: false,
  likeCount: likes,
  commentCount: comments,
);

void main() {
  group('a signed-in reader', () {
    test('liking posts a media interaction', () {
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );

      actions.like(_item());

      expect(api.interactions, [('media', 'm1', 'like')]);
    });

    test('the heart fills and the count moves before the server answers', () {
      // Optimistic on purpose: the round trip is not instant and a count
      // that moves a beat later reads as a tap that missed.
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );
      final item = _item();

      expect(actions.stateOf(item).liked, isFalse);
      expect(actions.stateOf(item).likes, 12);

      actions.like(item);

      expect(actions.stateOf(item).liked, isTrue);
      expect(actions.stateOf(item).likes, 13);
    });

    test('a refused like puts the heart back', () async {
      final (:store, :api) = _store();
      api.refuse = true;
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );
      final item = _item();

      actions.like(item);
      await Future<void>.delayed(Duration.zero);

      expect(actions.stateOf(item).liked, isFalse);
      expect(actions.stateOf(item).likes, 12);
    });

    test('following posts against the creator, not the video', () {
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );

      actions.follow(_item());

      expect(api.follows, [('c1', true)]);
      expect(api.interactions, isEmpty);
    });

    test('a second tap unfollows rather than following twice', () async {
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );
      final item = _item();

      actions.follow(item);
      await Future<void>.delayed(Duration.zero);
      expect(actions.isFollowing(item), isTrue);

      actions.follow(item);
      await Future<void>.delayed(Duration.zero);

      expect(api.follows, [('c1', true), ('c1', false)]);
    });

    test('a double tap does not post two toggles that cancel out', () {
      // Both land inside one frame, so the second is dropped rather than
      // immediately undoing the first — which is what the reader sees.
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );
      final item = _item();

      actions.follow(item);
      actions.follow(item);

      expect(actions.isFollowing(item), isTrue);
    });

    test('and neither does a double-tapped like', () {
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );
      final item = _item();

      actions.like(item);
      actions.like(item);

      expect(actions.stateOf(item).liked, isTrue);
      expect(actions.stateOf(item).likes, 13);
    });

    test('a known follow is not flipped the wrong way by the first tap', () {
      // The badge used to be drawn from nothing, so a reader who already
      // followed saw a + and the tap unfollowed them.
      final (:store, :api) = _store();
      store.seedFollowing('c1', true);
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );
      final item = _item();

      expect(actions.isFollowing(item), isTrue);
      actions.follow(item);

      expect(api.follows, [('c1', false)]);
    });
  });

  group('a signed-out reader', () {
    test('is stopped before anything is posted', () {
      final (:store, :api) = _store();
      final asked = <String>[];
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (feature) {
          asked.add(feature);
          return false;
        },
      );

      actions.like(_item());
      actions.follow(_item());

      expect(api.interactions, isEmpty);
      expect(api.follows, isEmpty);
      // And is told what the sheet is for, rather than seeing a bare prompt.
      expect(asked, ['like this video', 'follow this creator']);
    });
  });

  group('the counts', () {
    test('start from what the row carried', () {
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );

      final state = actions.stateOf(_item(likes: 940, comments: 17));
      expect(state.likes, 940);
      expect(state.comments, 17);
    });

    test('a row that carried none reads as zero, not as null', () {
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );

      final state = actions.stateOf(_item(likes: null, comments: null));
      expect(state.likes, 0);
      expect(state.comments, 0);
    });

    test('seeding a page makes them readable before anything is tapped', () {
      final (:store, :api) = _store();
      VerticalFeedActions.seedRows(store, [
        _item(mediaId: 'a', likes: 5),
        _item(mediaId: 'b', likes: 7),
      ]);

      expect(store.stateFor('media', 'a')?.likes, 5);
      expect(store.stateFor('media', 'b')?.likes, 7);
    });

    test('seeding never overwrites a like the reader just made', () {
      // A feed page fetched after the tap was assembled before it, so taking
      // the server's older answer would undo what the reader did.
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );
      final item = _item(mediaId: 'a', likes: 5);

      actions.like(item);
      expect(actions.stateOf(item).likes, 6);

      VerticalFeedActions.seedRows(store, [_item(mediaId: 'a', likes: 5)]);

      expect(actions.stateOf(item).liked, isTrue);
      expect(actions.stateOf(item).likes, 6);
    });

    test('a row with no id is not seeded under an empty key', () {
      final (:store, :api) = _store();
      VerticalFeedActions.seedRows(store, [_item(mediaId: '')]);

      expect(store.stateFor('media', ''), isNull);
    });
  });

  group('the shared store', () {
    test('knows the difference between "not following" and "not asked"', () {
      // The feed fetches real follow state once per ministry and needs to
      // tell those two apart, or it refetches on every rebuild.
      final (:store, :api) = _store();

      expect(store.knowsFollowing('c1'), isFalse);
      store.seedFollowing('c1', false);
      expect(store.knowsFollowing('c1'), isTrue);
      expect(store.isFollowing('c1'), isFalse);
    });

    test('a like made in the feed is the like every other surface shows', () {
      // One store for the whole session, so the detail screen and the home
      // card cannot disagree with the feed.
      final (:store, :api) = _store();
      final actions = VerticalFeedActions(
        store: store,
        requireAccount: (_) => true,
      );

      actions.like(_item(mediaId: 'm9', likes: 2));

      expect(store.stateFor('media', 'm9')?.liked, isTrue);
      expect(store.stateFor('media', 'm9')?.likes, 3);
    });
  });
}
