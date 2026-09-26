import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/discovery/views/widgets/playback_settings_sheet.dart';
import 'package:test_app/shared/services/hls_manifest.dart';
import 'package:test_app/shared/services/playback_controller.dart';

/// Speed and quality, which the redesigned player had lost.
///
/// The hard part is quality: media_kit exposes a progressive file's
/// renditions as selectable video tracks, but an HLS stream's are not tracks
/// at all — the native player picks one by bitrate. Mux serves HLS, so the
/// only way to offer a menu is to read the master playlist.
const _master = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028"
1080.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f"
720.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1400000,RESOLUTION=842x480
480.m3u8
''';

void main() {
  group('reading an HLS master playlist', () {
    test('every rendition becomes a label and a ceiling', () {
      expect(HlsManifest.parse(_master), {
        '1080p': 5000000,
        '720p': 2800000,
        '480p': 1400000,
      });
    });

    test('the tallest comes first, which is how a menu reads', () {
      expect(HlsManifest.parse(_master).keys.first, '1080p');
    });

    test('variants sharing a resolution keep the richest one', () {
      // Different audio or codec variants of the same rendition are common.
      const dupes = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
a.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
b.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=640x360
c.m3u8
''';
      expect(HlsManifest.parse(dupes), {'720p': 2800000, '360p': 1000000});
    });

    test('a rendition with no resolution falls back to its bitrate', () {
      const audioOnly = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=128000
a.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=64000
b.m3u8
''';
      expect(HlsManifest.parse(audioOnly), {'128k': 128000, '64k': 64000});
    });

    test('a media playlist offers no choice, so it offers nothing', () {
      const media = '''
#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.0,
seg0.ts
''';
      expect(HlsManifest.parse(media), isEmpty);
    });

    test('a single rendition is not a menu either', () {
      const one = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
a.m3u8
''';
      expect(HlsManifest.parse(one), isEmpty);
    });

    test('junk parses to nothing rather than throwing', () {
      expect(HlsManifest.parse(''), isEmpty);
      expect(HlsManifest.parse('not a playlist at all'), isEmpty);
      expect(
        HlsManifest.parse('#EXT-X-STREAM-INF:RESOLUTION=1280x720\na.m3u8'),
        isEmpty,
      );
    });
  });

  group('an offer racing the stream it belongs to', () {
    // The manifest is read over the network while the player is opening, so
    // the two finish in either order. Getting this wrong loses the quality
    // menu intermittently, on exactly the fast connections where the
    // manifest wins.
    test('an offer for the open stream applies at once', () {
      final offers = HlsQualityOffers();
      final ready = offers.offer('a.m3u8', const {
        '720p': 1,
      }, openUrl: 'a.m3u8');
      expect(ready, const {'720p': 1});
    });

    test('an offer that arrives first is kept for when the stream opens', () {
      final offers = HlsQualityOffers();
      // Nothing open yet: nothing to apply...
      expect(offers.offer('a.m3u8', const {'720p': 1}, openUrl: null), isNull);
      // ...but it is not lost.
      expect(offers.forUrl('a.m3u8'), const {'720p': 1});
    });

    test("one stream's renditions are never applied to another", () {
      final offers = HlsQualityOffers();
      expect(
        offers.offer('a.m3u8', const {'720p': 1}, openUrl: 'b.m3u8'),
        isNull,
      );
      expect(offers.forUrl('b.m3u8'), isNull);
    });

    test('an empty offer is not remembered', () {
      final offers = HlsQualityOffers();
      expect(offers.offer('a.m3u8', const {}, openUrl: 'a.m3u8'), isNull);
      expect(offers.forUrl('a.m3u8'), isNull);
    });

    test('it does not grow without bound over a long session', () {
      final offers = HlsQualityOffers();
      for (var i = 0; i < HlsQualityOffers.maxRemembered * 3; i++) {
        offers.offer('s$i.m3u8', const {'720p': 1});
      }
      // The most recent is still there; the rest have been let go.
      final last = HlsQualityOffers.maxRemembered * 3 - 1;
      expect(offers.forUrl('s$last.m3u8'), isNotNull);
      expect(offers.forUrl('s0.m3u8'), isNull);
    });
  });

  group('the speed menu', () {
    test('offers the usual ladder around 1x', () {
      expect(PlaybackController.rateChoices, [
        0.5,
        0.75,
        1.0,
        1.25,
        1.5,
        1.75,
        2.0,
      ]);
    });

    test('1x reads as Normal, not "1x"', () {
      expect(PlaybackSettingsSheet.rateLabel(1.0), 'Normal');
    });

    test('and the others read as multipliers', () {
      expect(PlaybackSettingsSheet.rateLabel(0.5), '0.5x');
      expect(PlaybackSettingsSheet.rateLabel(1.25), '1.25x');
      expect(PlaybackSettingsSheet.rateLabel(2.0), '2x');
    });
  });
}
