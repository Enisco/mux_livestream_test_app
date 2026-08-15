import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';

/// Shapes below are the ones staging actually returns (captured 2026-08-14).
/// Each entity type keeps its fields in a different place, which is exactly
/// what the mapper exists to absorb.
WebFeedItem _item(Map<String, dynamic> json) => WebFeedItem.fromJson(json);

const _creator = {
  'entityType': 'creator',
  'entityId': 'c1',
  'title': 'Evangelist En Ol',
  'subtitle': '@enol_ministries',
  'facets': {
    'categorySlugs': ['worship'],
    'creatorType': 'individual',
  },
  'meta': {
    'handle': 'enol_ministries',
    'isVerified': true,
    'avatarKey': 'a/b.png',
    'creatorType': 'individual',
  },
};

const _event = {
  'entityType': 'event',
  'entityId': 'e1',
  'title': 'Encounter Night Lagos 2026',
  'calendarStartAt': '2026-09-12T18:30:00.000Z',
  'calendarEndAt': '2026-09-12T21:00:00.000Z',
  'creator': {
    'displayName': 'CCI International',
    'handle': 'cci',
    'isVerified': true,
  },
  'facets': {
    'eventStatus': 'published',
    'categorySlugs': ['prayer'],
  },
  'meta': {'locationLabel': 'Grace Hall Auditorium', 'coverImageKey': 'k.png'},
};

const _post = {
  'entityType': 'post',
  'entityId': 'p1',
  'title': 'Small Faithful Steps',
  'subtitle': 'Spiritual growth rarely happens all at once.',
  'creator': {'displayName': 'Mirage', 'handle': 'mirage'},
  'facets': {'engagementLikeCount': 4, 'analyticsViews': 9},
  'meta': {
    'coverThumbnailKey': 'cover.png',
    'publishedAt': '2026-08-01T00:00:00.000Z',
  },
};

const _devotionalSeries = {
  'entityType': 'devotional_series',
  'entityId': 'd1',
  'title': "Three Days of Practising God's Peace",
  'subtitle': 'public · active',
  'creator': {'displayName': 'Mirage', 'handle': 'mirage'},
  'facets': {
    'categorySlugs': ['devotionals'],
  },
  'meta': {
    'description': 'Each day includes a short Scripture reading.',
    'publishedEntryCount': 3,
  },
};

const _devotionalEntry = {
  'entityType': 'devotional_entry',
  'entityId': 'de1',
  'title': 'Carry Peace Into the Day',
  'subtitle': "Day 3 · Three Days of Practising God's Peace",
  'creator': {'displayName': 'Mirage', 'handle': 'mirage'},
  'meta': {'dayNumber': 3, 'seriesTitle': "Three Days"},
};

const _mediaSeries = {
  'entityType': 'media_series',
  'entityId': 'ms1',
  'title': 'Test Series',
  'subtitle': 'series · public',
  'creator': {'displayName': 'Mirage', 'handle': 'mirage'},
  'meta': {'videoCount': 4, 'musicCount': 1},
};

const _video = {
  'entityType': 'media',
  'entityId': 'm1',
  'title': 'Sunday Service',
  'subtitle': 'video · public',
  'creator': {'displayName': 'Petra', 'handle': 'petra'},
  'facets': {'mediaType': 'video', 'analyticsViews': 12900},
  'meta': {'durationSeconds': 315, 'thumbnailUrl': 'https://x/y.png'},
};

const _audio = {
  'entityType': 'media',
  'entityId': 'm2',
  'title': 'Walking by Faith',
  'subtitle': 'music · public',
  'creator': {'displayName': 'Petra', 'handle': 'petra'},
  'facets': {'mediaType': 'music'},
  'meta': {'durationSeconds': 55},
};

const _live = {
  'entityType': 'media',
  'entityId': 'm3',
  'title': 'Live Service',
  'creator': {'displayName': 'Petra', 'handle': 'petra'},
  'facets': {'mediaType': 'video', 'isLiveNow': true},
  'meta': {},
};

void main() {
  group('every entity type lands on a kind', () {
    final cases = <String, (Map<String, dynamic>, FeedCardKind)>{
      'creator': (_creator, FeedCardKind.channel),
      'event': (_event, FeedCardKind.event),
      'post': (_post, FeedCardKind.post),
      'devotional_series': (_devotionalSeries, FeedCardKind.devotional),
      'devotional_entry': (_devotionalEntry, FeedCardKind.blog),
      'media_series': (_mediaSeries, FeedCardKind.series),
      'media/video': (_video, FeedCardKind.video),
      'media/music': (_audio, FeedCardKind.audio),
      'media/live': (_live, FeedCardKind.live),
    };

    cases.forEach((name, entry) {
      test(name, () {
        expect(FeedCardMapper.kindOf(_item(entry.$1)), entry.$2);
      });
    });

    test('a user row is treated as a channel', () {
      final item = _item({..._creator, 'entityType': 'user'});
      expect(FeedCardMapper.kindOf(item), FeedCardKind.channel);
    });

    test('an unknown type still renders as video rather than crashing', () {
      final item = _item({'entityType': 'something_new', 'entityId': 'x'});
      expect(FeedCardMapper.kindOf(item), FeedCardKind.video);
      expect(FeedCardMapper.toCardData(item).id, 'x');
    });

    test('live wins over the underlying media type', () {
      final item = _item({
        ..._audio,
        'facets': {'mediaType': 'music', 'isLiveNow': true},
      });
      expect(FeedCardMapper.kindOf(item), FeedCardKind.live);
    });
  });

  group('creator rows', () {
    test('take identity from meta, not the absent creator object', () {
      final data = FeedCardMapper.toCardData(_item(_creator));
      expect(data.creatorName, 'Evangelist En Ol');
      expect(data.handle, 'enol_ministries');
      expect(data.verified, isTrue);
      expect(data.title, isNull);
    });
  });

  group('events', () {
    test('read the schedule from calendarStartAt', () {
      final data = FeedCardMapper.toCardData(_item(_event));
      expect(data.eventStart, isNotNull);
      expect(data.eventStart!.toUtc().month, 9);
      expect(data.eventStart!.toUtc().day, 12);
    });

    test('carry the venue', () {
      expect(
        FeedCardMapper.toCardData(_item(_event)).location,
        'Grace Hall Auditorium',
      );
    });
  });

  group('bodies and subtitles', () {
    test('a post keeps its excerpt', () {
      expect(
        FeedCardMapper.toCardData(_item(_post)).body,
        startsWith('Spiritual growth'),
      );
    });

    test('a status-only subtitle is dropped', () {
      expect(FeedCardMapper.excerpt('public · active'), isNull);
      expect(FeedCardMapper.excerpt('series · public'), isNull);
      expect(FeedCardMapper.excerpt('video · public'), isNull);
    });

    test('a devotional series uses its description, not its status line', () {
      final data = FeedCardMapper.toCardData(_item(_devotionalSeries));
      expect(data.subtitle, startsWith('Each day includes'));
    });

    test(
      'a devotional series without a description falls back to day count',
      () {
        final json = Map<String, dynamic>.from(_devotionalSeries)
          ..['meta'] = {'publishedEntryCount': 3};
        expect(FeedCardMapper.toCardData(_item(json)).subtitle, '3 day plan');
      },
    );

    test('a devotional entry keeps its day line', () {
      expect(
        FeedCardMapper.toCardData(_item(_devotionalEntry)).body,
        startsWith('Day 3'),
      );
    });

    test('a media series counts its contents', () {
      expect(
        FeedCardMapper.toCardData(_item(_mediaSeries)).subtitle,
        '4 videos · 1 track',
      );
    });
  });

  group('media', () {
    test('duration formats as m:ss', () {
      expect(FeedCardMapper.toCardData(_item(_video)).duration, '5:15');
    });

    test('views format for display', () {
      expect(FeedCardMapper.toCardData(_item(_video)).views, isNotNull);
      expect(FeedCardMapper.toCardData(_item(_video)).viewCount, 12900);
    });

    test('zero views produce no label', () {
      expect(FeedCardMapper.toCardData(_item(_audio)).views, isNull);
    });
  });

  group('recommended creators', () {
    test('parse and strip a leading @', () {
      final creator = RecommendedCreator.fromJson(const {
        'creatorId': 'c9',
        'displayName': 'Pastor Luke Cage',
        'handle': '@lukecage',
        'verifiedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(creator.handle, 'lukecage');
      expect(creator.isVerified, isTrue);
      expect(creator.isFollowing, isFalse);
    });
  });

  _libraryShapeTests();
}

void _libraryShapeTests() {
  group('creator library search shape', () {
    // The library route answers with data.hits + data.total, not data.items.
    // Reading only `items` silently produced an empty Library for creators who
    // clearly had content.
    const libraryResponse = {
      'success': true,
      'data': {
        'total': 8,
        'hits': [
          {
            'entityType': 'media',
            'entityId': 'm1',
            'title': 'Big Buck',
            'subtitle': 'video · public',
            'facets': {'mediaType': 'video', 'analyticsViews': 59},
            'meta': {
              'thumbnailUrl':
                  'https://api.staging.gospeltube.tv/v1/public/media/m1/assets/thumbnail',
              'durationSeconds': 10,
            },
          },
        ],
        'nextCursor': null,
      },
    };

    test('parses hits', () {
      final result = WebFeedResponse.fromJson(libraryResponse);
      expect(result.items, hasLength(1));
      expect(result.total, 8);
      expect(result.items.first.title, 'Big Buck');
    });

    test('still parses feed-shaped items', () {
      final result = WebFeedResponse.fromJson(const {
        'data': {
          'items': [
            {'entityType': 'media', 'entityId': 'm2', 'title': 'Worship'},
          ],
          'nextCursor': 'abc',
        },
      });
      expect(result.items, hasLength(1));
      expect(result.nextCursor, 'abc');
      expect(result.total, isNull);
    });

    test('the proxy thumbnail url is used as-is', () {
      final item = WebFeedResponse.fromJson(libraryResponse).items.first;
      expect(item.meta.thumbnailUrl, contains('/assets/thumbnail'));
    });
  });
}
