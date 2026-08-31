import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/shared/services/media_session_handler.dart';
import 'package:test_app/shared/services/playback_controller.dart' as pb;
import 'support/fake_playback.dart';

const _track = pb.PlaybackTarget(
  mediaId: 'track-1',
  creatorId: 'c1',
  title: 'Lasting Joy',
  artist: 'GospelTube US',
  artworkUrl: 'https://cdn/art.jpg',
);

void main() {
  late FakePlayback playback;
  late MediaSessionHandler handler;
  late List<bool> sessionClaims;

  setUp(() {
    playback = FakePlayback();
    sessionClaims = [];
    handler = MediaSessionHandler(
      playback,
      setSessionActive: ({required active}) async => sessionClaims.add(active),
    );
  });

  tearDown(() => handler.dispose());

  group('what reaches the notification', () {
    test('nothing is published before anything plays', () {
      expect(handler.mediaItem.value, isNull);
    });

    test('a playing track publishes its name and artwork', () {
      playback.emit(
        mediaId: 'track-1',
        kind: pb.PlaybackKind.audio,
        target: _track,
        duration: const Duration(minutes: 3),
      );

      final item = handler.mediaItem.value!;
      expect(item.id, 'track-1');
      expect(item.title, 'Lasting Joy');
      expect(item.artist, 'GospelTube US');
      expect(item.artUri.toString(), 'https://cdn/art.jpg');
      expect(item.duration, const Duration(minutes: 3));
    });

    test('a track with no title still names something', () {
      // An empty notification row is worse than a generic one.
      playback.emit(
        mediaId: 'track-1',
        target: const pb.PlaybackTarget(mediaId: 'track-1'),
      );
      expect(handler.mediaItem.value!.title, 'GospelTube');
      expect(handler.mediaItem.value!.artist, isNull);
    });

    test('artwork is dropped rather than published as a broken uri', () {
      playback.emit(
        mediaId: 'track-1',
        target: const pb.PlaybackTarget(mediaId: 'track-1', artworkUrl: ''),
      );
      expect(handler.mediaItem.value!.artUri, isNull);
    });

    test('the duration is filled in when the stream reports it late', () {
      // It arrives a beat after playback starts; without this the shade shows
      // no scrubber for the whole track.
      playback.emit(
        mediaId: 'track-1',
        target: _track,
        duration: Duration.zero,
      );
      expect(handler.mediaItem.value!.duration, isNull);

      playback.emit(
        mediaId: 'track-1',
        target: _track,
        duration: const Duration(minutes: 5),
      );
      expect(handler.mediaItem.value!.duration, const Duration(minutes: 5));
    });
  });

  group('video stays out of the shade', () {
    test('an autoplaying feed video publishes nothing', () {
      // The feed starts a muted clip every few seconds as the reader scrolls;
      // a notification for each would be noise, and would take audio focus.
      playback.emit(
        mediaId: 'clip-1',
        kind: pb.PlaybackKind.video,
        target: const pb.PlaybackTarget(mediaId: 'clip-1', title: 'Sermon'),
      );

      expect(handler.mediaItem.value, isNull);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    });

    test('a video after a track tears the session down', () {
      playback.emit(mediaId: 'track-1', target: _track);
      expect(handler.mediaItem.value, isNotNull);

      playback.emit(mediaId: 'clip-1', kind: pb.PlaybackKind.video);

      expect(handler.mediaItem.value, isNull);
      expect(handler.playbackState.value.playing, isFalse);
    });

    test('stopping clears the session', () {
      playback.emit(mediaId: 'track-1', target: _track);
      playback.clear();

      expect(handler.mediaItem.value, isNull);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    });
  });

  group('transport state', () {
    test('a playing track offers pause', () {
      playback.emit(mediaId: 'track-1', target: _track);

      final s = handler.playbackState.value;
      expect(s.playing, isTrue);
      expect(s.controls.contains(MediaControl.pause), isTrue);
      expect(s.controls.contains(MediaControl.play), isFalse);
    });

    test('a paused track offers play', () {
      playback.emit(mediaId: 'track-1', target: _track, playing: false);

      final s = handler.playbackState.value;
      expect(s.playing, isFalse);
      expect(s.controls.contains(MediaControl.play), isTrue);
    });

    test('buffering is reported so the shade does not look stalled', () {
      playback.emit(
        mediaId: 'track-1',
        target: _track,
        buffering: true,
        playing: false,
      );
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.buffering,
      );
    });

    test('the position is carried so the scrubber tracks', () {
      playback.emit(
        mediaId: 'track-1',
        target: _track,
        position: const Duration(seconds: 42),
      );
      expect(
        handler.playbackState.value.updatePosition,
        const Duration(seconds: 42),
      );
    });
  });

  group('the OS audio session', () {
    test('is claimed when a track starts', () {
      // iOS routes nothing from a session that was never activated.
      playback.emit(mediaId: 'track-1', target: _track);
      expect(sessionClaims, [true]);
    });

    test('is claimed once, not on every position tick', () {
      playback.emit(mediaId: 'track-1', target: _track);
      playback.emit(
        mediaId: 'track-1',
        target: _track,
        position: const Duration(seconds: 1),
      );
      playback.emit(
        mediaId: 'track-1',
        target: _track,
        position: const Duration(seconds: 2),
      );
      expect(sessionClaims, [true]);
    });

    test('is released when playback ends', () {
      // Holding it would keep interrupting whatever else the phone plays.
      playback.emit(mediaId: 'track-1', target: _track);
      playback.clear();
      expect(sessionClaims, [true, false]);
    });

    test('is released when a video takes over', () {
      playback.emit(mediaId: 'track-1', target: _track);
      playback.emit(mediaId: 'clip-1', kind: pb.PlaybackKind.video);
      expect(sessionClaims, [true, false]);
    });

    test('is never claimed for video', () {
      playback.emit(mediaId: 'clip-1', kind: pb.PlaybackKind.video);
      expect(sessionClaims, isEmpty);
    });
  });

  group('commands from the shade reach the one player', () {
    test('play resumes rather than reopening', () async {
      await handler.play();
      expect(playback.resumes, 1);
      expect(playback.played, isEmpty);
    });

    test('pause pauses', () async {
      await handler.pause();
      expect(playback.pauses, 1);
    });

    test('seek seeks', () async {
      await handler.seek(const Duration(seconds: 30));
      expect(playback.seeks, [const Duration(seconds: 30)]);
    });
  });
}
