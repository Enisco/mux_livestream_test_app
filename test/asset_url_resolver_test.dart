import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';

/// Only media rows arrive with a resolved `thumbnailUrl`. Posts, events,
/// devotional series, media series and creator avatars carry a bare storage
/// key — `public/thumbnail/{creatorId}/{uuid}.jpg` — which is the path of a
/// public object on the CDN. Those cards used to render with no artwork at
/// all because nothing put the host in front of the key.
const _cdn = 'https://cdn.example.test';

WebFeedItem _item(String entityType, Map<String, dynamic> meta) =>
    WebFeedItem.fromJson({
      'entityType': entityType,
      'entityId': 'e1',
      'title': 'A title',
      'meta': meta,
      'facets': <String, dynamic>{},
    });

void main() {
  group('with a CDN configured', () {
    setUp(() => dotenv.testLoad(fileInput: 'CDN_BASE_URL=$_cdn'));

    test('a storage key becomes a URL on the CDN', () {
      expect(
        AssetUrlResolver.resolve('public/thumbnail/c1/a.jpg'),
        '$_cdn/public/thumbnail/c1/a.jpg',
      );
    });

    test('a leading slash does not double up', () {
      expect(AssetUrlResolver.resolve('/public/a.jpg'), '$_cdn/public/a.jpg');
    });

    test('a trailing slash on the host does not double up', () {
      dotenv.testLoad(fileInput: 'CDN_BASE_URL=$_cdn/');
      expect(AssetUrlResolver.resolve('public/a.jpg'), '$_cdn/public/a.jpg');
    });

    test('a URL the API already resolved is passed through untouched', () {
      const url =
          'https://api.example.test/v1/public/media/m1/assets/thumbnail';
      expect(AssetUrlResolver.resolve(url), url);
    });

    test('nothing in, nothing out', () {
      expect(AssetUrlResolver.resolve(null), isNull);
      expect(AssetUrlResolver.resolve('   '), isNull);
    });

    test('a resolved url wins over a key', () {
      expect(
        AssetUrlResolver.imageFor(url: 'https://a.test/x.jpg', key: 'public/y'),
        'https://a.test/x.jpg',
      );
    });

    test('a post cover finally reaches the card', () {
      final card = FeedCardMapper.toCardData(
        _item('post', {'coverThumbnailKey': 'public/thumbnail/c1/cover.png'}),
      );
      expect(card.thumbnailUrl, '$_cdn/public/thumbnail/c1/cover.png');
    });

    test('a creator row resolves its own avatar', () {
      final card = FeedCardMapper.toCardData(
        _item('creator', {'avatarKey': 'public/avatar/c1/me.png'}),
      );
      expect(card.kind, FeedCardKind.channel);
      expect(card.avatarUrl, '$_cdn/public/avatar/c1/me.png');
    });

    test("a non-creator row resolves the poster's avatar", () {
      final item = WebFeedItem.fromJson({
        'entityType': 'post',
        'entityId': 'e1',
        'title': 'A title',
        'meta': <String, dynamic>{},
        'facets': <String, dynamic>{},
        'creator': {
          'creatorId': 'c1',
          'displayName': 'Grace',
          'handle': 'grace',
          'avatarKey': 'public/avatar/c1/me.png',
        },
      });
      expect(
        FeedCardMapper.toCardData(item).avatarUrl,
        '$_cdn/public/avatar/c1/me.png',
      );
    });

    test('media keeps the URL the API gave it', () {
      final card = FeedCardMapper.toCardData(
        _item('media', {
          'thumbnailUrl': 'https://api.test/v1/public/media/m/assets/thumbnail',
          'thumbnailKey': null,
        }),
      );
      expect(card.thumbnailUrl, startsWith('https://api.test/'));
    });
  });

  group('with no CDN configured', () {
    setUp(
      () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.test'),
    );

    test('a key resolves to nothing rather than a wrong host', () {
      expect(AssetUrlResolver.isConfigured, isFalse);
      expect(AssetUrlResolver.resolve('public/a.jpg'), isNull);
    });

    test('an absolute URL still passes through', () {
      expect(
        AssetUrlResolver.resolve('https://a.test/x.jpg'),
        'https://a.test/x.jpg',
      );
    });
  });

  test('an unloaded environment degrades instead of throwing', () {
    // Mapping runs in plenty of places that never load dotenv; artwork is not
    // worth taking a screen down for.
    expect(() => AssetUrlResolver.resolve('public/a.jpg'), returnsNormally);
  });
}
