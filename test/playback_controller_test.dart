import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/shared/services/playback_controller.dart';

void main() {
  group('playback state', () {
    test('nothing is active to begin with', () {
      const s = PlaybackState();
      expect(s.mediaId, isNull);
      expect(s.isActive('a'), isFalse);
      expect(s.isPlaying('a'), isFalse);
    });

    test('active is not the same as playing', () {
      const paused = PlaybackState(mediaId: 'a', kind: PlaybackKind.audio);
      expect(paused.isActive('a'), isTrue);
      expect(paused.isPlaying('a'), isFalse);
    });

    test('only the active id counts as playing', () {
      const s = PlaybackState(
        mediaId: 'a',
        kind: PlaybackKind.video,
        playing: true,
      );
      expect(s.isPlaying('a'), isTrue);
      // Every other card must render as idle, or two cards look live at once.
      expect(s.isPlaying('b'), isFalse);
      expect(s.isActive('b'), isFalse);
    });

    test('progress is a safe fraction', () {
      const none = PlaybackState();
      expect(none.progress, 0);

      const half = PlaybackState(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 60),
      );
      expect(half.progress, 0.5);

      // A position past the duration must not overflow a progress bar.
      const over = PlaybackState(
        position: Duration(seconds: 90),
        duration: Duration(seconds: 60),
      );
      expect(over.progress, 1.0);
    });

    test('copyWith keeps the fields it is not given', () {
      const s = PlaybackState(
        mediaId: 'a',
        kind: PlaybackKind.audio,
        playing: true,
        position: Duration(seconds: 5),
      );
      final next = s.copyWith(playing: false);
      expect(next.mediaId, 'a');
      expect(next.kind, PlaybackKind.audio);
      expect(next.position, const Duration(seconds: 5));
      expect(next.playing, isFalse);
    });
  });
}
