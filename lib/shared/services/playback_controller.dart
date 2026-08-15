import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:test_app/core/logger.dart';

enum PlaybackKind { audio, video }

/// What is playing right now, for widgets to render against.
@immutable
class PlaybackState {
  const PlaybackState({
    this.mediaId,
    this.kind,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final String? mediaId;
  final PlaybackKind? kind;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;

  bool isActive(String id) => mediaId == id;

  bool isPlaying(String id) => mediaId == id && playing;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlaybackState copyWith({
    String? mediaId,
    PlaybackKind? kind,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
  }) => PlaybackState(
    mediaId: mediaId ?? this.mediaId,
    kind: kind ?? this.kind,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

/// The app's single media pipeline.
///
/// Everything that plays — feed cards, detail heroes, the fullscreen view —
/// shares this one `Player`, which is what makes the guarantees hold: only one
/// stream is ever audible, audio survives scrolling and navigation, and opening
/// a detail continues from wherever the card had reached rather than starting
/// over.
///
/// Widgets must never build their own `Player`. Two players means two audio
/// sessions, and the second one silently steals focus from the first.
class PlaybackController {
  PlaybackController({Player? player})
    : _player = player ?? Player(configuration: const PlayerConfiguration()) {
    _videoController = VideoController(_player);
    _listen();
  }

  final Player _player;
  late final VideoController _videoController;

  /// The surface currently allowed to render video. Only one `Video` widget
  /// may be mounted against a controller at a time.
  VideoController get videoController => _videoController;

  final ValueNotifier<PlaybackState> state = ValueNotifier(
    const PlaybackState(),
  );

  /// Global, shared by every surface. Video starts muted like a feed should;
  /// audio is never muted, since the reader asked for it explicitly.
  final ValueNotifier<bool> muted = ValueNotifier(true);

  final List<StreamSubscription<dynamic>> _subs = [];
  String? _openingId;

  void _listen() {
    _subs.addAll([
      _player.stream.playing.listen(
        (v) => state.value = state.value.copyWith(playing: v),
      ),
      _player.stream.buffering.listen(
        (v) => state.value = state.value.copyWith(buffering: v),
      ),
      _player.stream.position.listen(
        (v) => state.value = state.value.copyWith(position: v),
      ),
      _player.stream.duration.listen(
        (v) => state.value = state.value.copyWith(duration: v),
      ),
      _player.stream.error.listen((e) => logger.w('Playback error: $e')),
    ]);
  }

  bool isActive(String mediaId) => state.value.isActive(mediaId);

  bool isPlaying(String mediaId) => state.value.isPlaying(mediaId);

  /// Starts [mediaId], replacing whatever was playing.
  ///
  /// Re-requesting the media that is already loaded resumes it in place rather
  /// than reopening, which is what lets a detail screen pick up mid-stream.
  Future<void> play({
    required String mediaId,
    required String url,
    required PlaybackKind kind,
    Duration? startAt,
  }) async {
    if (state.value.mediaId == mediaId) {
      await resume();
      return;
    }
    if (_openingId == mediaId) return;
    _openingId = mediaId;

    state.value = PlaybackState(mediaId: mediaId, kind: kind, buffering: true);
    try {
      await _player.open(Media(url), play: false);
      await _applyVolume(kind);
      if (startAt != null && startAt > Duration.zero) {
        await _player.seek(startAt);
      }
      await _player.play();
    } catch (e) {
      logger.e('Could not start $mediaId', error: e);
      state.value = const PlaybackState();
    } finally {
      if (_openingId == mediaId) _openingId = null;
    }
  }

  Future<void> _applyVolume(PlaybackKind kind) async {
    // Muting only ever applies to video; audio the reader started should be
    // audible whatever the feed's mute state happens to be.
    final silent = kind == PlaybackKind.video && muted.value;
    await _player.setVolume(silent ? 0 : 100);
  }

  Future<void> setMuted(bool value) async {
    muted.value = value;
    if (state.value.kind == PlaybackKind.video) {
      await _player.setVolume(value ? 0 : 100);
    }
  }

  Future<void> toggleMuted() => setMuted(!muted.value);

  Future<void> resume() async {
    if (state.value.mediaId == null) return;
    await _player.play();
  }

  Future<void> pause() async {
    if (state.value.mediaId == null) return;
    await _player.pause();
  }

  Future<void> togglePlayPause() async {
    if (state.value.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration to) => _player.seek(to);

  /// Ends playback entirely and clears the active media.
  Future<void> stop() async {
    if (state.value.mediaId == null) return;
    await _player.stop();
    state.value = const PlaybackState();
  }

  /// Stops only if [mediaId] is the one playing — used when a card scrolls out
  /// of view, so it cannot cut off whatever replaced it.
  Future<void> stopIfActive(String mediaId) async {
    if (state.value.mediaId == mediaId) await stop();
  }

  /// Pauses only if [mediaId] is the one playing.
  Future<void> pauseIfActive(String mediaId) async {
    if (state.value.mediaId == mediaId) await pause();
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _player.dispose();
    state.dispose();
    muted.dispose();
  }
}
