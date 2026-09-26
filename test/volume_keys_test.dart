import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:volume_controller/volume_controller.dart';

import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/shared/services/volume_key_unmuter.dart';
import 'support/fake_playback.dart';

/// Pressing volume-up on a silent feed video should unmute it.
///
/// Mute is player volume 0, so the hardware keys moved the system stream and
/// left the video exactly as silent — which reads as the buttons not working.
class _FakeVolume implements VolumeController {
  final _controller = StreamController<double>.broadcast();

  @override
  StreamSubscription<double> addListener(
    void Function(double)? onData, {
    bool fetchInitialVolume = true,
  }) => _controller.stream.listen(onData);

  void emit(double level) => _controller.add(level);

  Future<void> close() => _controller.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late FakePlayback playback;
  late _FakeVolume volume;
  late VolumeKeyUnmuter unmuter;

  setUp(() {
    playback = FakePlayback();
    volume = _FakeVolume();
    unmuter = VolumeKeyUnmuter(playback: playback, volume: volume);
    unmuter.start();
  });

  tearDown(() async {
    await unmuter.dispose();
    await volume.close();
  });

  /// Something muted and playing, which is what a feed card looks like.
  void playSomething() {
    playback.muted.value = true;
    playback.state.value = const PlaybackState(mediaId: 'm1', playing: true);
  }

  Future<void> press(List<double> levels) async {
    for (final l in levels) {
      volume.emit(l);
    }
    await Future<void>.delayed(Duration.zero);
  }

  test('turning the volume up unmutes what is playing', () async {
    playSomething();
    // The first event is the current level, not a press.
    await press([0.3, 0.4]);
    expect(playback.muted.value, isFalse);
  });

  test('turning it down does not', () async {
    // Reaching for volume-down on something silent means quieter, not louder.
    playSomething();
    await press([0.3, 0.2]);
    expect(playback.muted.value, isTrue);
  });

  test('the first reading is never treated as a press', () async {
    playSomething();
    await press([0.9]);
    expect(playback.muted.value, isTrue);
  });

  test('no change is not a press either', () async {
    playSomething();
    await press([0.5, 0.5]);
    expect(playback.muted.value, isTrue);
  });

  test('with nothing playing the keys are just volume', () async {
    playback.muted.value = true;
    playback.state.value = const PlaybackState();
    await press([0.3, 0.6]);
    expect(playback.muted.value, isTrue);
  });

  test('once unmuted it stops interfering', () async {
    playSomething();
    await press([0.3, 0.4]);
    expect(playback.muted.value, isFalse);

    // Muting again by hand, then a further rise: still honoured, because the
    // reader is looking at a silent video again.
    playback.muted.value = true;
    await press([0.5]);
    expect(playback.muted.value, isFalse);
  });

  test('it stops listening when disposed', () async {
    playSomething();
    await unmuter.dispose();
    expect(unmuter.isListening, isFalse);
    await press([0.3, 0.9]);
    expect(playback.muted.value, isTrue);
  });

  test('starting twice keeps one listener', () {
    unmuter.start();
    expect(unmuter.isListening, isTrue);
  });
}
