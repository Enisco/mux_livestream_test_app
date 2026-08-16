import 'package:flutter/foundation.dart';

import 'package:test_app/shared/services/playback_controller.dart';

/// A [PlaybackHandle] with no decoder behind it, so playback-aware widgets can
/// be driven from a test.
class FakePlayback implements PlaybackHandle {
  @override
  final ValueNotifier<PlaybackState> state = ValueNotifier(
    const PlaybackState(),
  );

  @override
  final ValueNotifier<bool> muted = ValueNotifier(true);

  @override
  final ValueNotifier<bool> fullscreen = ValueNotifier(false);

  @override
  void setFullscreen(bool value) => fullscreen.value = value;

  final List<String> played = [];
  final List<PlaybackTarget> targets = [];
  final List<Duration> seeks = [];
  int pauses = 0;
  int resumes = 0;

  /// Pretends [mediaId] is loaded and running.
  void emit({
    required String mediaId,
    PlaybackKind kind = PlaybackKind.audio,
    bool playing = true,
    bool buffering = false,
    Duration position = Duration.zero,
    Duration duration = const Duration(minutes: 4),
  }) {
    state.value = PlaybackState(
      mediaId: mediaId,
      kind: kind,
      playing: playing,
      buffering: buffering,
      position: position,
      duration: duration,
    );
  }

  @override
  bool isActive(String mediaId) => state.value.isActive(mediaId);

  @override
  bool isPlaying(String mediaId) => state.value.isPlaying(mediaId);

  @override
  Future<void> playMedia({
    required PlaybackTarget target,
    required PlaybackKind kind,
  }) async {
    // Matches the real controller: asking for the media already loaded resumes
    // it rather than opening it again, so `played` counts opens only.
    if (state.value.mediaId == target.mediaId) {
      await togglePlayPause();
      return;
    }
    played.add(target.mediaId);
    targets.add(target);
    emit(mediaId: target.mediaId, kind: kind);
  }

  @override
  Future<void> ensurePlaying({
    required PlaybackTarget target,
    required PlaybackKind kind,
  }) async {
    if (state.value.mediaId == target.mediaId) {
      if (!state.value.playing) await resume();
      return;
    }
    await playMedia(target: target, kind: kind);
  }

  @override
  Future<void> play({
    required PlaybackTarget target,
    required String url,
    required PlaybackKind kind,
    Duration? startAt,
  }) async {
    played.add(target.mediaId);
    targets.add(target);
    emit(mediaId: target.mediaId, kind: kind);
  }

  @override
  Future<void> pause() async {
    pauses++;
    state.value = state.value.copyWith(playing: false);
  }

  @override
  Future<void> resume() async {
    resumes++;
    state.value = state.value.copyWith(playing: true);
  }

  @override
  Future<void> togglePlayPause() async =>
      state.value.playing ? pause() : resume();

  @override
  Future<void> seek(Duration to) async {
    seeks.add(to);
    state.value = state.value.copyWith(position: to);
  }

  @override
  Future<void> setMuted(bool value) async => muted.value = value;

  @override
  Future<void> toggleMuted() => setMuted(!muted.value);

  @override
  Future<void> stop() async => state.value = const PlaybackState();

  @override
  Future<void> stopIfActive(String mediaId) async {
    if (isActive(mediaId)) await stop();
  }

  @override
  Future<void> pauseIfActive(String mediaId) async {
    if (isActive(mediaId)) await pause();
  }
}
