import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';

const _media = InteractionTargets.media;
const _id = 'm1';

/// Records what was posted and answers with whatever the test asks for.
class _Server {
  _Server({this.answer, this.fail = false});

  /// What the API says the interaction ended up as. Null echoes the request.
  bool? answer;
  bool fail;
  final calls = <String>[];

  Future<bool> toggle({
    required String targetType,
    required String targetId,
    required String interactionType,
  }) async {
    calls.add('$targetType:$targetId/$interactionType');
    if (fail) throw StateError('nope');
    return answer ?? true;
  }
}

EngagementStore _store(_Server server) => EngagementStore(
  toggle: server.toggle,
  setFollowing: (_, {required follow}) async {},
);

void main() {
  group('seeding', () {
    test('a payload fills in counts a card can show', () {
      final store = _store(_Server());
      store.seed(
        targetType: _media,
        targetId: _id,
        likes: 10,
        saves: 2,
        comments: 5,
      );

      final s = store.stateFor(_media, _id)!;
      expect(s.likes, 10);
      expect(s.saves, 2);
      expect(s.comments, 5);
      expect(s.liked, isFalse);
    });

    test('an unknown target reads from the caller\'s own payload', () {
      final store = _store(_Server());
      const fallback = EngagementState(likes: 7);
      expect(store.resolve(_media, 'never-seen', fallback).likes, 7);
    });

    test('a row that cannot be liked resolves to its fallback', () {
      // Creators and media series have no interaction target at all.
      final store = _store(_Server());
      const fallback = EngagementState(likes: 3);
      expect(store.resolve(null, _id, fallback).likes, 3);
    });

    test('the batch route\'s interaction types become the viewer flags', () {
      final store = _store(_Server());
      store.seedInteractions(_media, {
        _id: {InteractionTypes.like, InteractionTypes.favorite},
        'm2': {InteractionTypes.like},
      });

      expect(store.stateFor(_media, _id)!.liked, isTrue);
      expect(store.stateFor(_media, _id)!.saved, isTrue);
      expect(store.stateFor(_media, 'm2')!.saved, isFalse);
    });

    test('a later payload does not undo a like the viewer just made', () async {
      // The feed refetches constantly; its rows were assembled before the tap
      // reached the server, so trusting them blindly makes the like flicker off.
      final server = _Server();
      final store = _store(server);
      store.seed(targetType: _media, targetId: _id, likes: 10);
      await store.toggleLike(targetType: _media, targetId: _id);

      store.seed(targetType: _media, targetId: _id, likes: 10, liked: false);

      expect(store.stateFor(_media, _id)!.liked, isTrue);
      expect(store.stateFor(_media, _id)!.likes, 11);
    });

    test('a payload still updates fields the viewer has not touched', () async {
      final store = _store(_Server());
      store.seed(targetType: _media, targetId: _id, likes: 10, comments: 1);
      await store.toggleLike(targetType: _media, targetId: _id);

      store.seed(targetType: _media, targetId: _id, likes: 10, comments: 4);

      expect(store.stateFor(_media, _id)!.likes, 11, reason: 'owned');
      expect(store.stateFor(_media, _id)!.comments, 4, reason: 'not owned');
    });

    test('seeding what is already held wakes nobody', () {
      final store = _store(_Server());
      store.seed(targetType: _media, targetId: _id, likes: 10);

      var woke = 0;
      store.addListener(() => woke++);
      store.seed(targetType: _media, targetId: _id, likes: 10);

      expect(woke, 0);
    });
  });

  group('liking', () {
    test('a like shows before the server has answered', () {
      final store = _store(_Server());
      store.seed(targetType: _media, targetId: _id, likes: 4);

      store.toggleLike(targetType: _media, targetId: _id);

      expect(store.stateFor(_media, _id)!.likes, 5);
      expect(store.stateFor(_media, _id)!.liked, isTrue);
    });

    test('liking again takes it back off', () async {
      final server = _Server();
      final store = _store(server);
      store.seed(targetType: _media, targetId: _id, likes: 4);

      await store.toggleLike(targetType: _media, targetId: _id);
      server.answer = false;
      await store.toggleLike(targetType: _media, targetId: _id);

      expect(store.stateFor(_media, _id)!.likes, 4);
      expect(store.stateFor(_media, _id)!.liked, isFalse);
    });

    test('a refused like is rolled back', () async {
      final store = _store(_Server(fail: true));
      store.seed(targetType: _media, targetId: _id, likes: 4);

      await store.toggleLike(targetType: _media, targetId: _id);

      expect(store.stateFor(_media, _id)!.likes, 4);
      expect(store.stateFor(_media, _id)!.liked, isFalse);
    });

    test('the server wins when it lands the other way', () async {
      // The optimistic flip assumed "on"; the server says it is off — most
      // often because another device already liked it.
      final store = _store(_Server(answer: false));
      store.seed(targetType: _media, targetId: _id, likes: 4);

      await store.toggleLike(targetType: _media, targetId: _id);

      expect(store.stateFor(_media, _id)!.liked, isFalse);
      expect(store.stateFor(_media, _id)!.likes, 4);
    });

    test('a second tap while one is in flight is dropped', () async {
      final server = _Server();
      final store = _store(server);
      store.seed(targetType: _media, targetId: _id, likes: 4);

      await Future.wait([
        store.toggleLike(targetType: _media, targetId: _id),
        store.toggleLike(targetType: _media, targetId: _id),
      ]);

      expect(server.calls.length, 1);
      expect(store.stateFor(_media, _id)!.likes, 5);
    });

    test('likes and saves are separate targets', () async {
      final server = _Server();
      final store = _store(server);
      store.seed(targetType: _media, targetId: _id, likes: 4, saves: 1);

      await store.toggleLike(targetType: _media, targetId: _id);
      await store.toggleSave(targetType: _media, targetId: _id);

      expect(store.stateFor(_media, _id)!.likes, 5);
      expect(store.stateFor(_media, _id)!.saves, 2);
      expect(server.calls, ['media:m1/like', 'media:m1/favorite']);
    });

    test('a count the server disagrees with never goes negative', () async {
      final server = _Server(answer: false);
      final store = _store(server);
      // Nothing seeded: the store has never seen this row.
      await store.toggleSave(targetType: _media, targetId: _id);

      expect(store.stateFor(_media, _id)!.saves, 0);
    });

    test('the same id under two types does not collide', () async {
      final store = _store(_Server());
      store.seed(targetType: _media, targetId: _id, likes: 1);
      store.seed(targetType: InteractionTargets.post, targetId: _id, likes: 9);

      await store.toggleLike(targetType: _media, targetId: _id);

      expect(store.stateFor(_media, _id)!.likes, 2);
      expect(store.stateFor(InteractionTargets.post, _id)!.likes, 9);
    });

    test('an empty id is not posted anywhere', () async {
      final server = _Server();
      await _store(server).toggleLike(targetType: _media, targetId: '');
      expect(server.calls, isEmpty);
    });
  });

  group('comments', () {
    test('posting one moves the count every surface reads', () {
      final store = _store(_Server());
      store.seed(targetType: _media, targetId: _id, comments: 3);

      store.bumpComments(targetType: _media, targetId: _id);

      expect(store.stateFor(_media, _id)!.comments, 4);
    });

    test('a later payload does not undo it', () {
      final store = _store(_Server());
      store.seed(targetType: _media, targetId: _id, comments: 3);
      store.bumpComments(targetType: _media, targetId: _id);

      store.seed(targetType: _media, targetId: _id, comments: 3);

      expect(store.stateFor(_media, _id)!.comments, 4);
    });

    test('a target the store has not seen starts from the caller\'s count', () {
      final store = _store(_Server());
      store.bumpComments(targetType: _media, targetId: _id, fallbackCount: 8);
      expect(store.stateFor(_media, _id)!.comments, 9);
    });
  });

  group('following', () {
    test('a follow shows immediately and survives a later payload', () async {
      final store = EngagementStore(
        toggle: _Server().toggle,
        setFollowing: (_, {required follow}) async {},
      );
      store.seedFollowing('c1', false);

      await store.toggleFollow('c1');
      expect(store.isFollowing('c1'), isTrue);

      // A profile fetched afterwards can still say "not following".
      store.seedFollowing('c1', false);
      expect(store.isFollowing('c1'), isTrue);
    });

    test('a refused follow is rolled back', () async {
      final store = EngagementStore(
        toggle: _Server().toggle,
        setFollowing: (_, {required follow}) async => throw StateError('nope'),
      );

      await store.toggleFollow('c1');

      expect(store.isFollowing('c1'), isFalse);
    });

    test('an unknown creator reads the caller\'s own flag', () {
      final store = _store(_Server());
      expect(store.isFollowing('c9', fallback: true), isTrue);
    });
  });

  group('listeners', () {
    test('a change on one target wakes the surfaces showing it', () async {
      final store = _store(_Server());
      var woke = 0;
      store.addListener(() => woke++);

      await store.toggleLike(targetType: _media, targetId: _id);

      expect(woke, greaterThan(0));
    });
  });
}
