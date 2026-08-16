import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/home/data/feed_autoplay_coordinator.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'support/fake_playback.dart';

const _dwell = Duration(milliseconds: 20);
const _afterDwell = Duration(milliseconds: 40);

FeedAutoplayCoordinator _coordinator(FakePlayback playback) =>
    FeedAutoplayCoordinator(playback: playback, dwell: _dwell);

PlaybackTarget _t(String id) =>
    PlaybackTarget(mediaId: id, creatorId: 'c1', mediaType: 'video');

void main() {
  group('feed autoplay', () {
    test('a dominant card starts after the dwell, not before', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      // A card flicked past must not have started anything yet.
      expect(playback.played, isEmpty);

      await Future<void>.delayed(_afterDwell);
      expect(playback.played, ['a']);
      expect(playback.state.value.kind, PlaybackKind.video);
    });

    test('scrolling past a card before the dwell starts nothing', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      autoplay.report(_t('a'), 0.1);
      autoplay.report(_t('b'), 0.9);
      await Future<void>.delayed(_afterDwell);

      // Only the card that settled gets to play.
      expect(playback.played, ['b']);
    });

    test('a barely-visible card never wins', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.4);
      autoplay.report(_t('b'), 0.3);
      await Future<void>.delayed(_afterDwell);

      expect(playback.played, isEmpty);
      expect(autoplay.current, isNull);
    });

    test('the most visible of several cards wins', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.7);
      autoplay.report(_t('b'), 0.95);
      await Future<void>.delayed(_afterDwell);

      expect(playback.played, ['b']);
    });

    test('a card in charge is not unseated by a marginal rival', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);
      expect(playback.played, ['a']);

      // 'b' edges ahead but 'a' still fills the viewport — no handover.
      autoplay.report(_t('b'), 0.92);
      await Future<void>.delayed(_afterDwell);
      expect(playback.played, ['a']);
      expect(autoplay.current, 'a');
    });

    test('scrolling the playing card away pauses it', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);

      autoplay.report(_t('a'), 0.0);
      await Future<void>.delayed(_afterDwell);

      expect(playback.pauses, 1);
      // Paused, not stopped: the detail screen resumes from this position.
      expect(playback.state.value.isActive('a'), isTrue);
    });

    test('scrolling back resumes rather than reopening', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);
      autoplay.report(_t('a'), 0.0);
      await Future<void>.delayed(_afterDwell);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);

      // One open, then a resume — never a second buffering round.
      expect(playback.played, ['a']);
      expect(playback.state.value.playing, isTrue);
    });

    test('handing over pauses the outgoing card', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);

      autoplay.report(_t('a'), 0.2);
      autoplay.report(_t('b'), 0.9);
      await Future<void>.delayed(_afterDwell);

      expect(playback.played, ['a', 'b']);
      expect(playback.state.value.isActive('b'), isTrue);
    });

    test('audio the reader started is not interrupted by autoplay', () async {
      final playback = FakePlayback()
        ..emit(mediaId: 'track', kind: PlaybackKind.audio);
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);

      // Deliberate listening outranks a card drifting into view.
      expect(playback.played, isEmpty);
      expect(playback.state.value.isPlaying('track'), isTrue);
    });

    test('paused audio does not block autoplay', () async {
      final playback = FakePlayback()
        ..emit(mediaId: 'track', kind: PlaybackKind.audio, playing: false);
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);

      expect(playback.played, ['a']);
    });

    test('suspending stops anything from starting', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.suspend();
      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);

      expect(playback.played, isEmpty);
    });

    test('backgrounding pauses the card that was playing', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);

      autoplay.suspend();
      expect(playback.pauses, 1);

      autoplay.resume();
      await Future<void>.delayed(_afterDwell);
      expect(playback.state.value.playing, isTrue);
    });

    test('re-evaluating while it buffers never switches it off', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);
      expect(playback.state.value.playing, isTrue);

      // The card stays put and keeps reporting, as a settled card does. This
      // used to re-arm the dwell and toggle the video straight back off, so it
      // sat at 0:00 showing its first frame.
      for (var i = 0; i < 4; i++) {
        autoplay.report(_t('a'), 0.9);
        await Future<void>.delayed(_afterDwell);
      }

      expect(playback.state.value.playing, isTrue);
      expect(playback.pauses, 0);
      expect(playback.played, ['a']);
    });

    test('a card more than half out of view hands over', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 1.0);
      await Future<void>.delayed(_afterDwell);
      expect(autoplay.current, 'a');

      // Still mostly visible — it keeps its turn.
      autoplay.report(_t('a'), 0.6);
      autoplay.report(_t('b'), 0.9);
      await Future<void>.delayed(_afterDwell);
      expect(autoplay.current, 'a');

      // Now past halfway out: the more visible card takes over.
      autoplay.report(_t('a'), 0.4);
      await Future<void>.delayed(_afterDwell);

      expect(autoplay.current, 'b');
      expect(playback.state.value.isActive('b'), isTrue);
      expect(playback.state.value.playing, isTrue);
    });

    test('autoplay resumes a card it paused for the background', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      await Future<void>.delayed(_afterDwell);

      autoplay.suspend();
      expect(playback.state.value.playing, isFalse);

      autoplay.resume();
      await Future<void>.delayed(_afterDwell);

      // Resumed in place, not reopened.
      expect(playback.state.value.playing, isTrue);
      expect(playback.played, ['a']);
    });

    test('a card leaving the list gives up its claim', () async {
      final playback = FakePlayback();
      final autoplay = _coordinator(playback);
      addTearDown(autoplay.dispose);

      autoplay.report(_t('a'), 0.9);
      autoplay.remove('a');
      await Future<void>.delayed(_afterDwell);

      expect(playback.played, isEmpty);
      expect(autoplay.current, isNull);
    });
  });
}
