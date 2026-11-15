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
    setUp(
      () => dotenv.testLoad(
        fileInput: 'CDN_BASE_URL=$_cdn\nBASE_URL=https://api.example.test',
      ),
    );

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

    test('a video published without a cover still gets a still', () {
      // The rung that was missing everywhere on the viewer side. A
      // `mux_auto` row carries neither a URL nor a key — only the public
      // asset proxy can answer for it, and a surface that stops at
      // `imageFor` draws an empty box for good.
      expect(
        AssetUrlResolver.mediaImage(
          mediaId: 'm1',
          source: AssetUrlResolver.muxAutoThumbnail,
        ),
        'https://api.example.test/v1/public/media/m1/assets/thumbnail',
      );
    });

    test('a row that says its thumbnail is manual is not asked twice', () {
      // The proxy is minted only for a public, published, Mux-generated
      // still. A manual row either has its key or has nothing, so asking
      // would be one 404 per row.
      expect(
        AssetUrlResolver.mediaImage(mediaId: 'm1', source: 'manual'),
        isNull,
      );
    });

    test('a row that says nothing is tried', () {
      expect(AssetUrlResolver.mediaImage(mediaId: 'm1'), isNotNull);
    });

    test('the proxy is the last rung, never the first', () {
      expect(
        AssetUrlResolver.mediaImage(
          url: 'https://signed.test/a.jpg',
          mediaId: 'm1',
        ),
        'https://signed.test/a.jpg',
      );
      expect(
        AssetUrlResolver.mediaImage(
          key: 'public/thumbnail/c1/a.jpg',
          mediaId: 'm1',
        ),
        '$_cdn/public/thumbnail/c1/a.jpg',
      );
    });

    test('a media card reaches for the proxy; a blog card does not', () {
      // The proxy is a media route. Asking it about a blog would be a 404
      // per card, so only media rows climb that far.
      final video = FeedCardMapper.toCardData(
        _item('media', {'mediaType': 'video', 'thumbnailSource': 'mux_auto'}),
      );
      expect(video.thumbnailUrl, contains('/v1/public/media/e1/assets/'));

      final blog = FeedCardMapper.toCardData(_item('blog', const {}));
      expect(blog.thumbnailUrl, isNull);
    });

    test('a media row climbs to the proxy; everything else stops short', () {
      // One getter so every surface reads the same ladder: the detail
      // hero's poster, the search row, the feed card, the discover grid,
      // a creator's profile grid and the playlist screens all took
      // `meta.thumbnailUrl` raw at some point, and each one drew an empty
      // box for a video published without a cover.
      final video = _item('media', {
        'mediaType': 'video',
        'thumbnailSource': 'mux_auto',
      });
      expect(video.isMediaRow, isTrue);
      expect(video.stillUrl, contains('/v1/public/media/e1/assets/thumbnail'));

      // The proxy is a media route; asking it about a blog is a 404 a row.
      final blog = _item('blog', const {});
      expect(blog.isMediaRow, isFalse);
      expect(blog.stillUrl, isNull);
    });

    test('a row artwork and the face beside it are different pictures', () {
      // `stillUrl` deliberately does not answer with an avatar: a card can
      // want both, and a channel's avatar in a 16:9 slot is not artwork.
      final channel = _item('creator', {'avatarKey': 'public/avatar/c1/a.png'});
      expect(channel.avatarUrl, '$_cdn/public/avatar/c1/a.png');
      expect(channel.stillUrl, isNull);
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
