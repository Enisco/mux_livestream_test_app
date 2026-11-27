import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/data/feed_card_actions.dart';
import 'package:test_app/features/engagement/data/leave_when_hidden.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';

/// A store with no network behind it.
EngagementStore _store() => EngagementStore(
  toggle:
      ({
        required String targetType,
        required String targetId,
        required String interactionType,
      }) async => true,
  setFollowing: (String creatorId, {required bool follow}) async {},
);

WebFeedItem _row({
  required String id,
  String creatorId = 'c1',
  String entityType = 'media',
}) => WebFeedItem(
  entityType: entityType,
  entityId: id,
  title: 'Sunday Worship',
  creator: WebFeedCreator(
    creatorId: creatorId,
    displayName: 'Grace Chapel',
    handle: 'grace',
  ),
  meta: const WebFeedItemMeta(),
);

List<String> _idsOf(List<WebFeedItem> rows) =>
    rows.map((r) => r.entityId).toList();

void main() {
  /// Blocking a ministry, muting one, hiding a row or reporting one has to
  /// take it off the list the reader is looking at. The backend drops it
  /// from the *next* page, which is the durable half and no help at all to
  /// the page already on screen.
  group('a row the reader has done something about', () {
    test('a blocked ministry leaves at once, with all of its work', () {
      final store = _store();
      final rows = [
        _row(id: 'm1'),
        _row(id: 'm2', creatorId: 'c2'),
        _row(id: 'm3'),
      ];
      expect(_idsOf(FeedCardActions.visibleRows(store, rows)), [
        'm1',
        'm2',
        'm3',
      ]);

      store.setBlocked('c1', true);

      expect(_idsOf(FeedCardActions.visibleRows(store, rows)), ['m2']);
    });

    test('and comes back if the block is lifted', () {
      final store = _store()..setBlocked('c1', true);
      final rows = [_row(id: 'm1')];
      expect(FeedCardActions.visibleRows(store, rows), isEmpty);

      store.setBlocked('c1', false);

      expect(_idsOf(FeedCardActions.visibleRows(store, rows)), ['m1']);
    });

    test('a muted ministry goes too', () {
      final store = _store()..setMuted('c1', true);
      expect(FeedCardActions.visibleRows(store, [_row(id: 'm1')]), isEmpty);
    });

    test('so does one row marked Not interested, and only that row', () {
      final store = _store()..setNotInterested('m2', true);
      final rows = [_row(id: 'm1'), _row(id: 'm2'), _row(id: 'm3')];
      expect(_idsOf(FeedCardActions.visibleRows(store, rows)), ['m1', 'm3']);
    });

    test('and a reported one, even though nothing suppressed it', () {
      // Reporting posts no suppression — a moderator decides that, and
      // the backend goes on serving the row. Scrolling back past what you
      // just objected to is its own insult.
      final store = _store()..setReported('m1');
      expect(FeedCardActions.visibleRows(store, [_row(id: 'm1')]), isEmpty);
    });

    test('but reporting is not hiding, so the sheet does not claim it is', () {
      // The two look the same on the list and are not the same thing:
      // only one is a stored preference the reader can undo.
      final store = _store()..setReported('m1');
      expect(store.isNotInterested('m1'), isFalse);
      expect(store.isReported('m1'), isTrue);
    });

    test('a blocked ministry own channel row goes as well', () {
      // A creator row's `entityId` is the creator, so blocking takes the
      // channel card out of search and the rails too.
      final store = _store()..setBlocked('c9', true);
      final rows = [_row(id: 'c9', creatorId: 'c9', entityType: 'creator')];
      expect(FeedCardActions.visibleRows(store, rows), isEmpty);
    });

    test('and an empty id is never matched against an empty flag', () {
      final store = _store();
      expect(store.hidesRow(creatorId: '', targetId: ''), isFalse);
      expect(store.hidesRow(), isFalse);
    });
  });

  /// Filtering a list is useless if the list does not redraw when a flag
  /// moves — each card watches the store for its own counts, but a row
  /// *leaving* is a change of membership, which only the list can act on.
  group('and the lists that have to notice', () {
    const surfaces = <String, String>{
      'lib/features/home/views/home_feed_screen.dart': 'the home feed',
      'lib/features/discovery/views/search_screen.dart': 'search results',
      'lib/features/explore/views/explore_screen.dart': 'the Explore rails',
    };

    for (final entry in surfaces.entries) {
      test('${entry.value} filters and watches the store', () {
        final source = File(entry.key).readAsStringSync();
        expect(
          source,
          anyOf(contains('visibleRows('), contains('_visible(')),
          reason: '${entry.value} draws rows it was told to drop',
        );
        expect(
          source,
          contains('hiddenChanges'),
          reason:
              '${entry.value} either will not redraw when a flag moves, or '
              'watches the whole store and rebuilds every card on each like',
        );
      });
    }

    /// A list filtering itself is only half of it: the page in front,
    /// where the block button actually is, went on showing the thing.
    test('and the page the reader is on leaves too', () {
      const hosts = <String, String>{
        'lib/features/creator/views/creator_profile_screen.dart':
            'a blocked ministry own profile',
        'lib/features/discovery/views/media_detail_screen.dart':
            'a reported video page',
        'lib/features/discovery/views/content_detail_screen.dart':
            'a reported blog or devotional page',
      };
      for (final entry in hosts.entries) {
        final source = File(entry.key).readAsStringSync();
        expect(
          source,
          contains('LeaveWhenHidden'),
          reason:
              '${entry.value} stays open under the reader, with the button '
              'that hid it sitting there looking inert',
        );
      }
    });

    testWidgets('and it leaves without needing a frame to come', (
      tester,
    ) async {
      // A microtask, deliberately, not `addPostFrameCallback`:
      // registering one of those does not schedule a frame, so an idle
      // app can sit on it indefinitely.
      await tester.pumpWidget(const SizedBox());
      final store = _store();
      var left = 0;
      final watcher = LeaveWhenHidden(
        store: store,
        isHidden: () => store.hidesRow(creatorId: 'c1'),
        leave: () => left++,
      )..attach();
      addTearDown(watcher.detach);

      store.setBlocked('c1', true);
      // Not inside the store's own dispatch: it is still handing the
      // change to its other listeners.
      expect(left, 0);

      await tester.idle();
      expect(left, 1);
    });

    testWidgets('and stays put for something it is not showing', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final store = _store();
      var left = 0;
      final watcher = LeaveWhenHidden(
        store: store,
        isHidden: () => store.hidesRow(creatorId: 'c1'),
        leave: () => left++,
      )..attach();
      addTearDown(watcher.detach);

      store.setBlocked('c2', true);
      await tester.idle();

      expect(left, 0);
    });

    test('and a like does not wake them', () {
      // The store wakes its own listeners a dozen times a scroll. A list
      // subscribed to all of that would rebuild every card in it to
      // answer a question whose answer had not changed.
      final store = _store();
      var hiddenWoke = 0;
      store.hiddenChanges.addListener(() => hiddenWoke++);

      store.toggleLike(targetType: 'media', targetId: 'm1');
      store.toggleSave(targetType: 'media', targetId: 'm1');
      store.bumpComments(targetType: 'media', targetId: 'm1');
      store.seedFollowing('c1', true);

      expect(hiddenWoke, 0);

      store.setBlocked('c1', true);

      expect(hiddenWoke, 1);
    });

    test('and the store notifies when one does', () {
      final store = _store();
      var woken = 0;
      store.addListener(() => woken++);

      store.setBlocked('c1', true);
      store.setMuted('c2', true);
      store.setNotInterested('m1', true);
      store.setReported('m2');

      expect(woken, 4);

      // Saying again what is already held wakes nobody.
      store.setBlocked('c1', true);
      expect(woken, 4);
    });
  });
}
