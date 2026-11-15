import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'package:test_app/shared/services/playback_controller.dart' as pb;

/// Puts audio in the system's notification shade and on the lock screen.
class MediaSessionHandler extends BaseAudioHandler with SeekHandler {
  MediaSessionHandler(this._playback, {this.setSessionActive}) {
    _playback.state.addListener(_publish);
    _publish();
  }

  final pb.PlaybackHandle _playback;

  /// Claims and releases the OS audio session around a track.
  final Future<void> Function({required bool active})? setSessionActive;

  /// The media currently published, so an unchanged track is not re-announced
  /// on every position tick.
  String? _publishedId;

  /// Whether anything is published at all. Guards against clearing a session
  /// that was never opened, which would show an empty notification.
  bool _live = false;

  @override
  Future<void> play() => _playback.resume();

  @override
  Future<void> pause() => _playback.pause();

  @override
  Future<void> seek(Duration position) => _playback.seek(position);

  @override
  Future<void> stop() async {
    await _playback.stop();
    await super.stop();
  }

  void dispose() => _playback.state.removeListener(_publish);

  void _publish() {
    final s = _playback.state.value;
    final target = s.target;

    // Video, or nothing loaded: tear the session down rather than leave a
    // stale track sitting in the shade.
    if (s.kind != pb.PlaybackKind.audio || s.mediaId == null) {
      if (!_live) return;
      _live = false;
      _publishedId = null;
      unawaited(setSessionActive?.call(active: false));
      mediaItem.add(null);
      playbackState.add(
        PlaybackState(processingState: AudioProcessingState.idle),
      );
      return;
    }

    if (!_live) unawaited(setSessionActive?.call(active: true));

    if (_publishedId != s.mediaId) {
      _publishedId = s.mediaId;
      mediaItem.add(_itemFor(s.mediaId!, target, s.duration));
    } else if (s.duration > Duration.zero &&
        mediaItem.value?.duration != s.duration) {
      // The duration only arrives once the stream has been parsed, a beat
      // after playback starts; without this the shade shows no scrubber.
      mediaItem.add(mediaItem.value!.copyWith(duration: s.duration));
    }

    _live = true;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          if (s.playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: s.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: s.playing,
        updatePosition: s.position,
        bufferedPosition: s.position,
      ),
    );
  }

  MediaItem _itemFor(String id, pb.PlaybackTarget? target, Duration duration) {
    final art = target?.artworkUrl;
    return MediaItem(
      id: id,
      // A blank title would show as an empty notification row, so fall back to
      // something that at least names the app.
      title: target?.title?.trim().isNotEmpty == true
          ? target!.title!.trim()
          : 'GospelTube',
      artist: target?.artist?.trim().isNotEmpty == true
          ? target!.artist!.trim()
          : null,
      duration: duration > Duration.zero ? duration : null,
      artUri: art == null || art.isEmpty ? null : Uri.tryParse(art),
    );
  }
}
