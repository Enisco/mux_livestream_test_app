import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/discovery_models/media_detail.dart';
import 'package:test_app/shared/services/media_url_resolver.dart';
import 'package:test_app/shared/services/playback_info_cache.dart';

PlaybackInfo _info(String url) => PlaybackInfo(
  mediaId: 'm1',
  mediaType: 'music',
  playbackId: 'p1',
  playbackUrl: url,
);

void main() {
  group('media url resolver', () {
    test('asks the API once, then serves the cache', () async {
      var calls = 0;
      final resolver = MediaUrlResolver(
        cache: PlaybackInfoCache(),
        fetch: (_) async {
          calls++;
          return _info('https://cdn/track.m3u8');
        },
      );

      expect(await resolver('m1'), 'https://cdn/track.m3u8');
      expect(await resolver('m1'), 'https://cdn/track.m3u8');
      // A second tap on the same card must not cost another round trip.
      expect(calls, 1);
    });

    test('an empty playback url is not cached and yields null', () async {
      var calls = 0;
      final resolver = MediaUrlResolver(
        cache: PlaybackInfoCache(),
        fetch: (_) async {
          calls++;
          return _info('');
        },
      );

      expect(await resolver('m1'), isNull);
      expect(await resolver('m1'), isNull);
      // Caching a blank URL would make the track permanently unplayable.
      expect(calls, 2);
    });

    test('a missing media yields null', () async {
      final resolver = MediaUrlResolver(
        cache: PlaybackInfoCache(),
        fetch: (_) async => null,
      );
      expect(await resolver('m1'), isNull);
    });

    test('a failed lookup returns null instead of throwing', () async {
      final resolver = MediaUrlResolver(
        cache: PlaybackInfoCache(),
        fetch: (_) async => throw Exception('offline'),
      );
      // The card falls back to idle; it must not take the tap handler down.
      expect(await resolver('m1'), isNull);
    });

    test('an empty id never reaches the API', () async {
      var calls = 0;
      final resolver = MediaUrlResolver(
        cache: PlaybackInfoCache(),
        fetch: (_) async {
          calls++;
          return _info('https://cdn/x');
        },
      );
      expect(await resolver(''), isNull);
      expect(calls, 0);
    });
  });
}
