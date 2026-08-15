import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/discovery_models/content_detail.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';

/// The media aggregate 404s for anything that is not media, so the row's
/// entityType has to pick the route. Captured from staging 2026-08-15.
void main() {
  group('non-media detail payloads', () {
    test('a post parses its body and counts', () {
      final post = ContentPost.fromJson(const {
        'data': {
          'id': 'p1',
          'creatorId': 'c1',
          'title': 'Fasting Without Losing Mercy',
          'excerpt': 'A practical small-group reflection.',
          'body': '## Main Scripture\nRomans 12:1-2 reminds us...',
          'publishedAt': '2026-06-30T10:18:59.751Z',
          'scriptureRefs': ['Romans 12:1-2'],
          'categorySlugs': ['prayer'],
          'analyticsViews': 12,
          'engagementLikeCount': 3,
          'engagementCommentCount': 1,
        },
      });
      expect(post.title, startsWith('Fasting'));
      expect(post.body, contains('Romans'));
      expect(post.scriptureRefs, ['Romans 12:1-2']);
      expect(post.engagement.views, 12);
      expect(post.engagement.likes, 3);
      expect(post.publishedAt, isNotNull);
    });

    test('a devotional series parses entries and viewer progress', () {
      final series = DevotionalSeriesDetail.fromJson(const {
        'data': {
          'id': 'd1',
          'creatorId': 'c1',
          'title': '7 Days of Gratitude',
          'description': 'A week-long series.',
          'status': 'active',
          'entries': [
            {
              'id': 'e1',
              'title': 'Day one',
              'dayNumber': 1,
              'memoryVerseRef': 'Psalm 100:4',
              'reflectionQuestions': ['What are you thankful for?'],
            },
            {'id': 'e2', 'title': 'Day two', 'dayNumber': 2},
          ],
          'viewerProgress': {
            'completedEntryIds': ['e1'],
            'currentEntryId': 'e2',
          },
        },
      });
      expect(series.entryCount, 2);
      expect(series.entries.first.memoryVerseRef, 'Psalm 100:4');
      expect(series.isCompleted('e1'), isTrue);
      expect(series.isCompleted('e2'), isFalse);
      expect(series.currentEntryId, 'e2');
    });

    test('a signed-out viewer has no progress', () {
      final series = DevotionalSeriesDetail.fromJson(const {
        'data': {'id': 'd1', 'creatorId': 'c1', 'title': 'Series'},
      });
      expect(series.completedEntryIds, isEmpty);
      expect(series.currentEntryId, isNull);
    });

    test('an event parses its schedule and venue', () {
      final event = EventDetail.fromJson(const {
        'data': {
          'id': 'ev1',
          'creatorId': 'c1',
          'title': 'August Family Prayer',
          'description': 'Come along.',
          'startAt': '2026-08-16T09:00:00.000Z',
          'endAt': '2026-08-16T11:00:00.000Z',
          'venueType': 'hybrid',
          'location': {'label': 'Grace Hall Auditorium'},
          'engagementLikeCount': 1,
        },
      });
      expect(event.startAt, isNotNull);
      expect(event.locationLabel, 'Grace Hall Auditorium');
      expect(event.venueType, 'hybrid');
      expect(event.isOnline, isFalse);
      expect(event.engagement.likes, 1);
    });
  });

  group('devotional entries carry their series', () {
    test('seriesId is parsed so an entry can open its series', () {
      final item = WebFeedItem.fromJson(const {
        'entityType': 'devotional_entry',
        'entityId': 'entry1',
        'title': 'Carry Peace Into the Day',
        'meta': {'dayNumber': 3, 'seriesId': 'series9'},
      });
      expect(item.meta.seriesId, 'series9');
    });
  });
}
