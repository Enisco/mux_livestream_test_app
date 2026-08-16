import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/analytics_models/analytics_models.dart';

void main() {
  group('beacon content targeting', () {
    test('media is targeted by mediaId, never a content type', () {
      // Media beacons set `mediaId` and omit contentType entirely.
      expect(ContentTypes.fromEntityType('media'), isNull);
    });

    test('feed entity types map onto the gateway enum', () {
      expect(ContentTypes.fromEntityType('post'), ContentTypes.post);
      expect(
        ContentTypes.fromEntityType('devotional_series'),
        ContentTypes.devotionalSeries,
      );
      expect(
        ContentTypes.fromEntityType('devotional_entry'),
        ContentTypes.devotionalEntry,
      );
      expect(
        ContentTypes.fromEntityType('media_series'),
        ContentTypes.mediaSeries,
      );
    });

    test('the feed says event, the beacon enum says calendar_event', () {
      // Sending the feed's own word here is rejected, and one bad row fails
      // the whole batch.
      expect(ContentTypes.fromEntityType('event'), ContentTypes.calendarEvent);
      expect(ContentTypes.calendarEvent, 'calendar_event');
    });

    test('a creator row targets creator, not creator_channel', () {
      // `creator_channel` is a *source* value; using it as a content type is
      // rejected at ingest.
      expect(ContentTypes.fromEntityType('creator'), ContentTypes.creator);
      expect(ContentTypes.fromEntityType('user'), ContentTypes.creator);
      expect(ContentTypes.creator, 'creator');
      expect(AnalyticsSource.creatorChannel, 'creator_channel');
    });

    test('an unrecognised row is not guessed at', () {
      // Guessing would poison the batch; no beacon is better than a wrong one.
      expect(ContentTypes.fromEntityType('something_new'), isNull);
      expect(ContentTypes.fromEntityType(null), isNull);
      expect(ContentTypes.fromEntityType(''), isNull);
    });

    test('every mapped value is one the gateway accepts', () {
      const entityTypes = [
        'post',
        'event',
        'creator',
        'user',
        'media_series',
        'devotional_series',
        'devotional_entry',
      ];
      for (final e in entityTypes) {
        final mapped = ContentTypes.fromEntityType(e);
        expect(mapped, isNotNull, reason: '$e should map');
        expect(
          ContentTypes.all.contains(mapped),
          isTrue,
          reason: '$e mapped to $mapped, which the gateway rejects',
        );
      }
    });

    test('the accepted set matches the gateway enum exactly', () {
      // Verified against staging: anything outside this list is a 400.
      expect(ContentTypes.all, {
        'creator',
        'media_series',
        'post',
        'devotional_series',
        'devotional_entry',
        'calendar_event',
      });
    });
  });
}
