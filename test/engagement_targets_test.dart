import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';

WebFeedItem _item({String entityType = 'media', String id = 'e1'}) =>
    WebFeedItem.fromJson({
      'entityType': entityType,
      'entityId': id,
      'title': 'Row',
      'creator': {'creatorId': 'c1', 'displayName': 'GospelTube'},
      'facets': {'mediaType': 'video'},
      'meta': {},
    });

void main() {
  group('interaction targets', () {
    test('the enum matches what staging accepts', () {
      expect(InteractionTargets.all, {
        'media',
        'post',
        'devotional',
        'devotional_entry',
        'event',
        'testimony',
        'verse_of_day',
      });
    });

    test('a devotional series is "devotional" here, not devotional_series', () {
      // Three naming schemes for one entity; the beacon name is rejected here.
      expect(
        InteractionTargets.fromEntityType('devotional_series'),
        InteractionTargets.devotional,
      );
      expect(
        ContentTypes.fromEntityType('devotional_series'),
        'devotional_series',
      );
    });

    test('an event is "event" here, not calendar_event', () {
      expect(InteractionTargets.fromEntityType('event'), 'event');
      expect(ContentTypes.fromEntityType('event'), 'calendar_event');
    });

    test('creators and media series carry no interactions', () {
      // Sending these would 400 the request for the whole page.
      expect(InteractionTargets.fromEntityType('creator'), isNull);
      expect(InteractionTargets.fromEntityType('media_series'), isNull);
      expect(InteractionTargets.fromEntityType('user'), isNull);
    });

    test('every mapped value is one the API accepts', () {
      for (final e in ['media', 'post', 'devotional_series', 'event']) {
        final mapped = InteractionTargets.fromEntityType(e);
        expect(InteractionTargets.all.contains(mapped), isTrue, reason: e);
      }
    });

    test('dislike is not an interaction the API knows', () {
      // Why the card's second action is save, not a thumbs-down.
      expect(InteractionTypes.all.contains('dislike'), isFalse);
      expect(InteractionTypes.all, {'like', 'favorite', 'amen', 'share'});
    });
  });

  group('card hydration', () {
    test('a card with no viewer state renders unliked', () {
      final card = FeedCardMapper.toCardData(_item());
      expect(card.liked, isFalse);
      expect(card.saved, isFalse);
    });

    test('the viewer’s like and save land on the card', () {
      final card = FeedCardMapper.toCardData(
        _item(),
        interactions: {
          'e1': {InteractionTypes.like, InteractionTypes.favorite},
        },
      );
      expect(card.liked, isTrue);
      expect(card.saved, isTrue);
    });

    test('another row’s state never bleeds onto this card', () {
      final card = FeedCardMapper.toCardData(
        _item(id: 'e1'),
        interactions: {
          'a-different-row': {InteractionTypes.like},
        },
      );
      expect(card.liked, isFalse);
    });

    test('an unrelated interaction type does not imply a like', () {
      final card = FeedCardMapper.toCardData(
        _item(),
        interactions: {
          'e1': {InteractionTypes.share, InteractionTypes.amen},
        },
      );
      expect(card.liked, isFalse);
      expect(card.saved, isFalse);
    });
  });
}
