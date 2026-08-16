import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/discovery/data/search_query.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';

WebFeedItem _item({
  String title = '',
  String? subtitle,
  String? description,
  String? mediaType,
  String creator = '',
  String handle = '',
  String entityType = 'media',
}) => WebFeedItem.fromJson({
  'entityType': entityType,
  'entityId': 'e1',
  'title': title,
  'subtitle': subtitle,
  'creator': {'creatorId': 'c1', 'displayName': creator, 'handle': handle},
  'facets': {'mediaType': mediaType},
  'meta': {'description': description},
});

void main() {
  group('search matching', () {
    test('an empty query keeps everything', () {
      expect(SearchMatcher.matches(_item(title: 'Anything'), ''), isTrue);
      expect(SearchMatcher.matches(_item(title: 'Anything'), '   '), isTrue);
    });

    test('matching is case and position insensitive', () {
      final item = _item(title: 'Sunday Worship Service');
      expect(SearchMatcher.matches(item, 'worship'), isTrue);
      expect(SearchMatcher.matches(item, 'WORSHIP'), isTrue);
      expect(SearchMatcher.matches(item, 'sunday'), isTrue);
      expect(SearchMatcher.matches(item, 'evening'), isFalse);
    });

    test('every word must land, not just one', () {
      final item = _item(title: 'Sunday Worship Service');
      expect(SearchMatcher.matches(item, 'sunday worship'), isTrue);
      // Otherwise "kids worship" returns every worship row there is.
      expect(SearchMatcher.matches(item, 'kids worship'), isFalse);
    });

    test('the creator name and handle are searchable', () {
      final item = _item(
        title: 'Untitled',
        creator: 'Hillsong Worship',
        handle: 'hillsong',
      );
      expect(SearchMatcher.matches(item, 'hillsong'), isTrue);
      expect(SearchMatcher.matches(item, 'Hillsong Worship'), isTrue);
    });

    test('the description is searchable', () {
      final item = _item(
        title: 'Day 3',
        description: 'Practising God\'s peace',
      );
      expect(SearchMatcher.matches(item, 'peace'), isTrue);
    });

    test('a missing field never crashes the match', () {
      expect(SearchMatcher.matches(_item(), 'anything'), isFalse);
      expect(SearchMatcher.matches(_item(), ''), isTrue);
    });

    test('tokens ignore extra whitespace', () {
      expect(SearchMatcher.tokens('  sunday   worship '), [
        'sunday',
        'worship',
      ]);
      expect(SearchMatcher.tokens(''), isEmpty);
    });
  });

  group('search filters', () {
    test('All asks the API for nothing in particular', () {
      expect(SearchFilter.all.entityTypes, isEmpty);
      expect(SearchFilter.all.liveOnly, isFalse);
      expect(SearchFilter.all.mediaType, isNull);
    });

    test('Live is the only filter that sets the server live flag', () {
      for (final f in SearchFilter.values) {
        expect(f.liveOnly, f == SearchFilter.live);
      }
    });

    test('Videos and Audio split one entity type on the client', () {
      // The API has a single `media` type, so the split cannot be a request.
      expect(SearchFilter.videos.entityTypes, ['media']);
      expect(SearchFilter.audio.entityTypes, ['media']);
      expect(SearchFilter.videos.mediaType, 'video');
      expect(SearchFilter.audio.mediaType, 'music');
    });

    test('a video filter drops audio rows and vice versa', () {
      final video = _item(title: 'Clip', mediaType: 'video');
      final music = _item(title: 'Track', mediaType: 'music');

      expect(SearchMatcher.passesFilter(video, SearchFilter.videos), isTrue);
      expect(SearchMatcher.passesFilter(music, SearchFilter.videos), isFalse);
      expect(SearchMatcher.passesFilter(music, SearchFilter.audio), isTrue);
      expect(SearchMatcher.passesFilter(video, SearchFilter.all), isTrue);
    });

    test('non-media filters carry the API entity types', () {
      expect(SearchFilter.creators.entityTypes, ['creator']);
      expect(SearchFilter.blogs.entityTypes, ['post']);
      expect(SearchFilter.events.entityTypes, ['event']);
      expect(SearchFilter.series.entityTypes, ['media_series']);
      expect(SearchFilter.devotionals.entityTypes, [
        'devotional_series',
        'devotional_entry',
      ]);
    });

    test('apply narrows by filter and query together', () {
      final rows = [
        _item(title: 'Worship Night', mediaType: 'video'),
        _item(title: 'Worship Track', mediaType: 'music'),
        _item(title: 'Sermon Clip', mediaType: 'video'),
      ];

      final result = SearchMatcher.apply(rows, 'worship', SearchFilter.videos);
      expect(result.map((i) => i.title), ['Worship Night']);
    });
  });
}
