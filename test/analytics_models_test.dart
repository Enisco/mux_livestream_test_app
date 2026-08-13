import 'package:flutter_test/flutter_test.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/vertical_feed_item.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';

void main() {
  group('PromotionAttribution.tryParse', () {
    Map<String, dynamic> valid() => {
      'isPromoted': true,
      'promotionCampaignId': 'camp_123',
      'promotionPlacement': 'vertical_feed',
      'promotionDeliveryId': 'signed_delivery_token',
    };

    test('parses a complete promoted payload', () {
      final promotion = PromotionAttribution.tryParse(valid());
      expect(promotion, isNotNull);
      expect(promotion!.campaignId, 'camp_123');
      expect(promotion.placement, 'vertical_feed');
      expect(promotion.deliveryId, 'signed_delivery_token');
      expect(promotion.toBeaconFields(), {
        'promotionCampaignId': 'camp_123',
        'promotionPlacement': 'vertical_feed',
        'promotionDeliveryId': 'signed_delivery_token',
      });
    });

    test('treats an organic item as organic', () {
      expect(PromotionAttribution.tryParse({'title': 'x'}), isNull);
      expect(PromotionAttribution.tryParse(null), isNull);
    });

    test('rejects a partially populated payload rather than half-billing', () {
      for (final missing in [
        'promotionCampaignId',
        'promotionPlacement',
        'promotionDeliveryId',
      ]) {
        final json = valid()..remove(missing);
        expect(
          PromotionAttribution.tryParse(json),
          isNull,
          reason: 'missing $missing must not produce attribution',
        );
      }
    });

    test('rejects an unrecognised placement', () {
      final json = valid()..['promotionPlacement'] = 'banner';
      expect(PromotionAttribution.tryParse(json), isNull);
    });

    test('rejects attribution fields without the isPromoted flag', () {
      final json = valid()..['isPromoted'] = false;
      expect(PromotionAttribution.tryParse(json), isNull);
    });

    test('deliveryKey distinguishes deliveries of the same campaign', () {
      final a = PromotionAttribution.tryParse(valid())!;
      final b = PromotionAttribution.tryParse(
        valid()..['promotionDeliveryId'] = 'another_token',
      )!;
      expect(a.deliveryKey, isNot(b.deliveryKey));
      expect(
        a.deliveryKey,
        PromotionAttribution.tryParse(valid())!.deliveryKey,
      );
    });
  });

  group('normalisation', () {
    test('mediaType passes through known values and drops unknowns', () {
      expect(MediaTypes.normalize('video'), 'video');
      expect(MediaTypes.normalize('livestream'), 'livestream');
      expect(MediaTypes.normalize('podcast'), isNull);
      expect(MediaTypes.normalize(null), isNull);
    });

    test('source falls back to unknown instead of inventing a label', () {
      expect(AnalyticsSource.normalize('home_feed'), 'home_feed');
      expect(AnalyticsSource.normalize('made_up'), 'unknown');
      expect(AnalyticsSource.normalize(null), 'unknown');
    });
  });

  group('feed item parsing', () {
    test('vertical feed item carries promotion and mediaType', () {
      final item = VerticalFeedItem.fromJson({
        'mediaId': 'm1',
        'creatorId': 'c1',
        'title': 'Sunday Message',
        'type': 'video',
        'isLiveNow': false,
        'isPromoted': true,
        'promotionCampaignId': 'camp_1',
        'promotionPlacement': 'vertical_feed',
        'promotionDeliveryId': 'tok',
      });
      expect(item.isPromoted, isTrue);
      expect(item.mediaType, 'video');
      expect(item.promotion!.campaignId, 'camp_1');
    });

    test('web feed item reads promotion from meta', () {
      final item = WebFeedItem.fromJson({
        'entityType': 'media',
        'entityId': 'm2',
        'title': 'Teaching',
        'meta': {
          'mediaType': 'music',
          'isPromoted': true,
          'promotionCampaignId': 'camp_2',
          'promotionPlacement': 'catalogue',
          'promotionDeliveryId': 'tok2',
        },
      });
      expect(item.isPromoted, isTrue);
      expect(item.mediaType, 'music');
      expect(item.promotion!.placement, 'catalogue');
    });

    test('organic web feed item exposes no attribution', () {
      final item = WebFeedItem.fromJson({
        'entityType': 'media',
        'entityId': 'm3',
        'title': 'Organic',
        'meta': {'thumbnailUrl': 'https://example.test/t.jpg'},
      });
      expect(item.isPromoted, isFalse);
      expect(item.promotion, isNull);
    });
  });

  group('WatchClock', () {
    test('counts only time spent playing', () async {
      final clock = WatchClock();
      expect(clock.seconds, 0);

      clock.start();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      clock.stop();
      final afterFirstRun = clock.seconds;
      expect(afterFirstRun, greaterThan(0.03));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(clock.seconds, afterFirstRun);

      clock.start();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(clock.seconds, greaterThan(afterFirstRun));

      clock.reset();
      expect(clock.seconds, 0);
    });

    test('stop is idempotent', () {
      final clock = WatchClock()..start();
      clock.stop();
      final settled = clock.seconds;
      clock.stop();
      expect(clock.seconds, settled);
    });
  });
}
