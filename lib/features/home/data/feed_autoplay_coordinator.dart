import 'dart:async';

import 'package:test_app/shared/services/playback_controller.dart';

/// Decides which feed card is allowed to autoplay.
///
/// Cards report how much of themselves is on screen; this picks the one that
/// dominates the viewport and starts it after a short dwell, so flicking
/// through the feed does not thrash the decoder on every card it passes.
///
/// Only one card can win at a time, which is what keeps the single-stream rule
/// intact while the reader scrolls.
class FeedAutoplayCoordinator {
  FeedAutoplayCoordinator({
    required this.playback,
    this.dwell = const Duration(seconds: 1),
    this.threshold = 0.5,
  });

  final PlaybackHandle playback;

  /// How long a card has to hold the viewport before it earns playback.
  final Duration dwell;

  /// How much of a card must be visible to hold or win playback.
  ///
  /// Half: once a card is more than halfway out of view, in either direction,
  /// it gives up playback to whichever card is now most visible.
  final double threshold;

  final Map<String, double> _visible = {};
  final Map<String, PlaybackTarget> _targets = {};
  Timer? _timer;
  String? _current;
  bool _paused = false;

  /// The card playing (or about to play) right now.
  String? get current => _current;

  /// Stops autoplay from starting anything — used while the app is in the
  /// background or a full-screen surface owns playback.
  bool get suspended => _paused;

  void suspend() {
    if (_paused) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
    final id = _current;
    if (id != null) unawaited(playback.pauseIfActive(id));
  }

  void resume() {
    if (!_paused) return;
    _paused = false;

    // The card chosen before backgrounding keeps its turn — it is still the one
    // on screen, and it has already served its dwell, so it picks straight up.
    final id = _current;
    final target = id == null ? null : _targets[id];
    if (target != null && (_visible[id] ?? 0) >= threshold) {
      unawaited(
        playback.ensurePlaying(target: target, kind: PlaybackKind.video),
      );
      return;
    }
    _evaluate();
  }

  void report(PlaybackTarget target, double fraction) {
    if (fraction <= 0) {
      remove(target.mediaId);
      return;
    }
    _visible[target.mediaId] = fraction;
    _targets[target.mediaId] = target;
    _evaluate();
  }

  void remove(String mediaId) {
    _targets.remove(mediaId);
    if (_visible.remove(mediaId) == null) return;
    _evaluate();
  }

  /// The most-visible card, provided it clears [threshold].
  ///
  /// A card that already holds playback keeps it while it still qualifies, so a
  /// rival that edges ahead by a pixel cannot steal mid-view. That protection
  /// starts only once the card has actually opened — until then it is just a
  /// candidate waiting out its dwell, and a better one should take its place.
  String? get winner {
    final held = _current;
    if (held != null &&
        playback.isActive(held) &&
        (_visible[held] ?? 0) >= threshold) {
      return held;
    }

    String? best;
    var bestFraction = threshold;
    for (final entry in _visible.entries) {
      if (entry.value >= bestFraction) {
        best = entry.key;
        bestFraction = entry.value;
      }
    }
    return best;
  }

  void _evaluate() {
    if (_paused) return;

    final next = winner;
    if (next == _current) {
      // Same card still in charge. Re-arm only if it has not been handed to the
      // player at all — testing `isPlaying` here would re-fire all through
      // buffering, and each re-fire used to toggle the new video straight off.
      if (next != null && !playback.isActive(next) && _timer == null) {
        _startDwell(next);
      }
      return;
    }

    _timer?.cancel();
    _timer = null;

    final previous = _current;
    _current = next;

    // Pause rather than stop: the detail screen picks the position up from
    // here, and scrolling back resumes instead of re-buffering from zero.
    if (previous != null) unawaited(playback.pauseIfActive(previous));

    if (next != null) _startDwell(next);
  }

  void _startDwell(String mediaId) {
    _timer = Timer(dwell, () {
      _timer = null;
      if (_paused || _current != mediaId) return;
      // Deliberate listening beats automatic watching: a track the reader
      // started by hand is not interrupted by a card drifting into view.
      if (playback.state.value.kind == PlaybackKind.audio &&
          playback.state.value.playing) {
        return;
      }
      if (playback.isPlaying(mediaId)) return;
      final target = _targets[mediaId];
      if (target == null) return;
      // `ensurePlaying`, never `playMedia`: autoplay must not toggle.
      unawaited(
        playback.ensurePlaying(target: target, kind: PlaybackKind.video),
      );
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _visible.clear();
    _targets.clear();
    _current = null;
  }
}
