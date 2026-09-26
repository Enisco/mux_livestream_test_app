import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/creator_models/studio_content_models.dart';

/// Stills in the Content tab.
///
/// Reported from the app: a published video showed a grey tile with a camera
/// glyph in the list, and a grey box reading "View content" on its detail —
/// while the row from `POST /v1/media/creator/{id}/search` already carried
///
/// ```
/// thumbnailKey: public/thumbnail/{creatorId}/…-image_….jpeg
/// thumbnailSource: manual
/// muxPlaybackId: UK12nV0001HppPN…
/// ```
///
/// The key was parsed and then dropped by both widgets.
///
/// Two sources, because the API uses two: an uploaded cover is a CDN key, and
/// a video left to Mux carries **no key at all** — its generated first frame
/// comes from `GET /v1/public/media/{id}/assets/thumbnail`, which is public
/// and 302s to a signed Mux image (verified on staging, 2026-09-26).
const _cdn = 'https://cdn.example.test';
const _api = 'https://api.example.test';

StudioContentItem _media({
  String type = 'video',
  String status = 'published',
  String? thumbnailKey,
  bool live = false,
  String? sourceLivestreamMediaId,
}) => StudioContentItem.fromMedia({
  'id': 'm1',
  'type': type,
  'title': 'Choose wisely',
  'status': status,
  'visibility': 'public',
  'isLiveNow': live,
  'thumbnailKey': thumbnailKey,
  'sourceLivestreamMediaId': sourceLivestreamMediaId,
  'updatedAt': DateTime.now().toIso8601String(),
});

void main() {
  setUp(() {
    dotenv.testLoad(fileInput: 'BASE_URL=$_api\nCDN_BASE_URL=$_cdn');
  });

  group('where the still comes from', () {
    test('an uploaded cover resolves on the CDN', () {
      final item = _media(thumbnailKey: 'public/thumbnail/c1/cover.jpeg');
      expect(item.stillUrl, '$_cdn/public/thumbnail/c1/cover.jpeg');
    });

    test('a video with no cover falls back to its generated first frame', () {
      // `thumbnailSource: mux_auto` rows carry no key whatsoever.
      expect(_media().stillUrl, '$_api/v1/public/media/m1/assets/thumbnail');
    });

    test('audio does the same', () {
      expect(
        _media(type: 'music').stillUrl,
        '$_api/v1/public/media/m1/assets/thumbnail',
      );
    });

    test('a livestream session does too', () {
      expect(_media(type: 'livestream').stillUrl, isNotNull);
    });

    test('an uploaded cover wins over the generated one', () {
      final item = _media(thumbnailKey: 'public/thumbnail/c1/cover.jpeg');
      expect(item.stillUrl, isNot(contains('/assets/thumbnail')));
    });

    test('a post has a cover or nothing — never a media still', () {
      final post = StudioContentItem.fromPost({
        'id': 'p1',
        'title': 'A post',
        'status': 'published',
        'visibility': 'public',
      });
      expect(post.stillUrl, isNull);

      final withCover = StudioContentItem.fromPost({
        'id': 'p2',
        'title': 'A post',
        'status': 'published',
        'visibility': 'public',
        'coverThumbnailKey': 'public/thumbnail/c1/post.png',
      });
      expect(withCover.stillUrl, '$_cdn/public/thumbnail/c1/post.png');
    });

    test('an unconfigured build shows no still rather than a broken one', () {
      dotenv.testLoad(fileInput: 'NOTHING=1');
      expect(_media().stillUrl, isNull);
      expect(_media(thumbnailKey: 'public/a.jpg').stillUrl, isNull);
    });
  });

  group('what opens the player', () {
    test('a published video does', () {
      expect(_media().isPlayable, isTrue);
    });

    test('so does a replay, which is the watchable half of a broadcast', () {
      final replay = _media(sourceLivestreamMediaId: 'ls1');
      expect(replay.state, StudioContentState.replay);
      expect(replay.isPlayable, isTrue);
    });

    test('a draft does not — there is nothing transcoded yet', () {
      expect(_media(status: 'draft').isPlayable, isFalse);
    });

    test('nor does one that failed to transcode', () {
      expect(_media(status: 'failed').isPlayable, isFalse);
    });

    test('nor a livestream session, whose recording is a separate row', () {
      expect(_media(type: 'livestream', live: true).isPlayable, isFalse);
      expect(_media(type: 'livestream', status: 'ended').isPlayable, isFalse);
    });

    test('nor a post or an event', () {
      final post = StudioContentItem.fromPost({
        'id': 'p1',
        'title': 'A post',
        'status': 'published',
        'visibility': 'public',
      });
      expect(post.isPlayable, isFalse);
    });

    test('published audio is playable too', () {
      expect(_media(type: 'music').isPlayable, isTrue);
    });
  });
}
