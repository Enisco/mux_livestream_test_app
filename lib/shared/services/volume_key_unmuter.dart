import 'dart:async';

import 'package:volume_controller/volume_controller.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/shared/services/playback_controller.dart';

/// Turns a press of the phone's volume keys into "unmute this video".
class VolumeKeyUnmuter {
  VolumeKeyUnmuter({required PlaybackHandle playback, VolumeController? volume})
    : _playback = playback,
      _volume = volume ?? VolumeController.instance;

  final PlaybackHandle _playback;
  final VolumeController _volume;

  StreamSubscription<double>? _sub;
  double? _lastVolume;

  bool get isListening => _sub != null;

  void start() {
    if (_sub != null) return;
    try {
      // The system's own volume HUD still shows; suppressing it would leave
      // a press with no feedback at all when nothing is muted.
      _sub = _volume.addListener(_onVolume);
    } catch (e) {
      logger.w('Volume keys unavailable', error: e);
    }
  }

  /// [level] is the system volume, 0..1.
  void _onVolume(double level) {
    final previous = _lastVolume;
    _lastVolume = level;

    // The first event is the current volume, not a press.
    if (previous == null) return;
    if (level <= previous) return;

    // Only while something is actually on screen and silent. Turning the
    // volume up with nothing playing means exactly what it says.
    if (!_playback.muted.value) return;
    if (!_playback.state.value.playing) return;
    unawaited(_playback.setMuted(false));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _lastVolume = null;
  }
}
