import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/discovery_models/media_detail.dart';
import 'package:test_app/shared/services/playback_info_cache.dart';

/// A Mux-shaped signed URL whose token expires [inSeconds] from now.
String _signedUrl(int inSeconds) {
  final exp = DateTime.now().add(Duration(seconds: inSeconds));
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'exp': exp.millisecondsSinceEpoch ~/ 1000, 'aud': 'v'}),
        ),
      )
      .replaceAll('=', '');
  return 'https://stream.mux.com/abc.m3u8?token=header.$payload.sig';
}

PlaybackInfo _info(String url) => PlaybackInfo(
  mediaId: 'm1',
  mediaType: 'video',
  playbackId: 'p1',
  playbackUrl: url,
);

void main() {
  group('playback url cache', () {
    test('a fresh signed url is served back', () {
      final cache = PlaybackInfoCache();
      final url = _signedUrl(600);
      cache.put('m1', _info(url));

      expect(cache.get('m1')?.playbackUrl, url);
    });

    test('an already-expired token is never served', () {
      final cache = PlaybackInfoCache();
      cache.put('m1', _info(_signedUrl(-60)));

      // Handing this to the player does not fail loudly — it just never
      // produces a frame, which is the stall this cache caused.
      expect(cache.get('m1'), isNull);
    });

    test('a token expiring within the margin is treated as gone', () {
      final cache = PlaybackInfoCache();
      // 10s left, less than the 30s safety margin.
      cache.put('m1', _info(_signedUrl(10)));

      expect(cache.get('m1'), isNull);
    });

    test('a long-lived token still expires on the plain TTL', () {
      final cache = PlaybackInfoCache();
      // A token good for a day must not pin a URL in memory for a day.
      cache.put('m1', _info(_signedUrl(86400)));

      expect(cache.get('m1'), isNotNull);
    });

    test('a url with no token falls back rather than refusing to play', () {
      final cache = PlaybackInfoCache();
      const plain = 'https://cdn.example.com/clip.m3u8';
      cache.put('m1', _info(plain));

      expect(cache.get('m1')?.playbackUrl, plain);
    });

    test('an unreadable token falls back instead of throwing', () {
      final cache = PlaybackInfoCache();
      const bad = 'https://stream.mux.com/abc.m3u8?token=not-a-jwt';
      cache.put('m1', _info(bad));

      expect(cache.get('m1')?.playbackUrl, bad);
    });

    test('a missing entry is simply absent', () {
      expect(PlaybackInfoCache().get('nope'), isNull);
    });

    test('clear drops everything', () {
      final cache = PlaybackInfoCache();
      cache.put('m1', _info(_signedUrl(600)));
      cache.clear();

      expect(cache.get('m1'), isNull);
    });
  });
}
