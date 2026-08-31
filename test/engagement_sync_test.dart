import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/data/feed_card_actions.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'helpers/load_app_fonts.dart';

const _mediaId = 'm-1';

/// A real feed row, shaped the way the discovery API sends one.
WebFeedItem _row({
  String entityType = 'media',
  int likes = 10,
  int saves = 4,
  int comments = 2,
}) => WebFeedItem.fromJson({
  'entityType': entityType,
  'entityId': _mediaId,
  'title': 'Sunday Service',
  'mediaType': 'video',
  'creator': {'creatorId': 'c-1', 'displayName': 'Petra CC'},
  'facets': {
    'engagementLikeCount': likes,
    'engagementFavoriteCount': saves,
    'engagementCommentCount': comments,
    'analyticsViews': 900,
  },
});

/// Stands in for the interactions route, which flips the stored state and
/// answers with whichever side it landed on.
EngagementStore _store({bool fail = false}) {
  final on = <String>{};
  return EngagementStore(
    toggle:
        ({
          required String targetType,
          required String targetId,
          required String interactionType,
        }) async {
          if (fail) throw StateError('nope');
          final key = '$targetType:$targetId/$interactionType';
          return on.add(key) ? true : (on.remove(key) ? false : false);
        },
    setFollowing: (_, {required follow}) async {},
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  WebFeedItem item,
  EngagementStore store, {
  VoidCallback? onLike,
  VoidCallback? onSave,
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Every screen seeds its rows after a load; without it the store starts a
  // like from zero rather than from what the row arrived with.
  FeedCardActions.seedRows(store, [item]);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(393, 852),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeedCard(
              data: FeedCardMapper.toCardData(item),
              engagement: store,
              onLike: onLike,
              onSave: onSave,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Which heart the card is drawing.
String _heart(WidgetTester tester) => tester
    .widgetList<DesignIcon>(find.byType(DesignIcon))
    .map((i) => i.asset)
    .firstWhere((a) => a.contains('heart'));

void main() {
  setUpAll(loadAppFonts);

  group('the like button', () {
    testWidgets('is an outline until the viewer likes it', (tester) async {
      await _pumpCard(tester, _row(), _store());
      expect(_heart(tester), AppAssets.iconFeedHeart);
    });

    testWidgets('fills in once liked', (tester) async {
      final store = _store();
      await _pumpCard(tester, _row(), store);

      await store.toggleLike(
        targetType: InteractionTargets.media,
        targetId: _mediaId,
      );
      await tester.pump();

      expect(_heart(tester), AppAssets.iconFeedHeartFilled);
    });

    testWidgets('empties again when the like is taken back', (tester) async {
      final store = _store();
      await _pumpCard(tester, _row(), store);

      await store.toggleLike(
        targetType: InteractionTargets.media,
        targetId: _mediaId,
      );
      await tester.pump();
      expect(_heart(tester), AppAssets.iconFeedHeartFilled);

      await store.toggleLike(
        targetType: InteractionTargets.media,
        targetId: _mediaId,
      );
      await tester.pump();

      expect(_heart(tester), AppAssets.iconFeedHeart);
    });

    testWidgets('arrives filled when the batch route says it is liked', (
      tester,
    ) async {
      // Opening a feed the viewer has already liked rows in.
      final store = _store();
      await _pumpCard(tester, _row(), store);
      store.seedInteractions(InteractionTargets.media, {
        _mediaId: {InteractionTypes.like},
      });
      await tester.pump();

      expect(_heart(tester), AppAssets.iconFeedHeartFilled);
    });

    testWidgets('a refused like leaves the outline', (tester) async {
      final store = _store(fail: true);
      await _pumpCard(tester, _row(), store);

      await store.toggleLike(
        targetType: InteractionTargets.media,
        targetId: _mediaId,
      );
      await tester.pump();

      expect(_heart(tester), AppAssets.iconFeedHeart);
    });
  });

  group('a card reads the shared store', () {
    testWidgets('an untouched row shows the counts it arrived with', (
      tester,
    ) async {
      await _pumpCard(tester, _row(), _store());

      expect(find.text('10'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('a like made elsewhere lands on the card without a refetch', (
      tester,
    ) async {
      // This is the reported behaviour: like on the detail screen, pop back,
      // and the card behind it must already show the new count.
      final store = _store();
      await _pumpCard(tester, _row(), store);
      expect(find.text('10'), findsOneWidget);

      await store.toggleLike(
        targetType: InteractionTargets.media,
        targetId: _mediaId,
      );
      await tester.pump();

      expect(find.text('11'), findsOneWidget);
      expect(find.text('10'), findsNothing);
    });

    testWidgets('a comment posted in the sheet moves the card\'s count', (
      tester,
    ) async {
      final store = _store();
      await _pumpCard(tester, _row(), store);

      store.bumpComments(
        targetType: InteractionTargets.media,
        targetId: _mediaId,
        fallbackCount: 2,
      );
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the batch route\'s state lights the icons up', (tester) async {
      final store = _store();
      await _pumpCard(tester, _row(), store);

      store.seedInteractions(InteractionTargets.media, {
        _mediaId: {InteractionTypes.like},
      });
      await tester.pump();

      // The count is unchanged — only the viewer's own flag arrived.
      expect(find.text('10'), findsOneWidget);
      expect(store.stateFor(InteractionTargets.media, _mediaId)!.liked, isTrue);
    });

    testWidgets('a card for another row is left alone', (tester) async {
      final store = _store();
      await _pumpCard(tester, _row(), store);

      await store.toggleLike(
        targetType: InteractionTargets.media,
        targetId: 'some-other-media',
      );
      await tester.pump();

      expect(find.text('10'), findsOneWidget);
    });
  });

  group('tapping a card action', () {
    testWidgets('the like button actually fires', (tester) async {
      // It used to call an auth guard that returned true and did nothing else,
      // so for a signed-in viewer the button was inert.
      var taps = 0;
      await _pumpCard(tester, _row(), _store(), onLike: () => taps++);

      await tester.tap(find.text('10'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('the save button actually fires', (tester) async {
      var taps = 0;
      await _pumpCard(tester, _row(), _store(), onSave: () => taps++);

      await tester.tap(find.text('4'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a refused like leaves the count where it was', (tester) async {
      final store = _store(fail: true);
      await _pumpCard(tester, _row(), store);

      await store.toggleLike(
        targetType: InteractionTargets.media,
        targetId: _mediaId,
      );
      await tester.pump();

      expect(find.text('10'), findsOneWidget);
    });
  });

  group('interaction targets', () {
    test('a media row carries the target its actions need', () {
      expect(FeedCardMapper.toCardData(_row()).targetType, 'media');
    });

    test('a devotional series uses its own name, not the feed\'s', () {
      final data = FeedCardMapper.toCardData(
        _row(entityType: 'devotional_series'),
      );
      expect(data.targetType, InteractionTargets.devotional);
    });

    test('a creator row has nothing to like', () {
      // Its buttons stay inert rather than posting a call the API rejects.
      expect(
        FeedCardMapper.toCardData(_row(entityType: 'creator')).targetType,
        isNull,
      );
    });

    test('a creator row still knows which creator to follow', () {
      // profileCreatorId is the row itself, not a nested creator object.
      final data = FeedCardMapper.toCardData(_row(entityType: 'creator'));
      expect(data.creatorId, _mediaId);
    });
  });
}
