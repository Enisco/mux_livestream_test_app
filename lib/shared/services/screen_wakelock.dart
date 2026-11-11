import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:test_app/core/logger.dart';

/// Turns the screen's auto-lock off and on.
///
/// Supplied by a test; otherwise the plugin, which disables the idle timer
/// on iOS and holds `FLAG_KEEP_SCREEN_ON` on Android.
typedef WakelockSetter = Future<void> Function(bool enabled);

/// Keeps the screen awake while something on screen needs it to be.
///
/// The screen locked in the middle of a broadcast, which it must never do:
/// a creator who is talking to a camera is not touching the phone, so the
/// idle timer has nothing to go on.
///
/// Counted rather than switched, because "nobody needs this any more" is
/// not the same as "I stopped needing it": two holders letting go in the
/// wrong order would otherwise leave the screen locking under the one
/// still broadcasting. [hold] and [release] must be paired exactly once
/// each — a widget's `initState` and `dispose` are the reliable place.
///
/// **`media_kit_video` keeps a count of its own** for video playback, in
/// its internal `Wakelock`, which is not exported. Both end up calling the
/// same plugin, so a screen that plays a `Video` *and* takes a hold here
/// at the same time can have one release turn the screen off while the
/// other still wants it on. No screen does that today: the broadcast
/// screens show a camera preview, not a `Video`.
class ScreenWakelock {
  ScreenWakelock({WakelockSetter? set}) : _set = set ?? _plugin;

  static Future<void> _plugin(bool enabled) =>
      enabled ? WakelockPlus.enable() : WakelockPlus.disable();

  final WakelockSetter _set;

  int _holds = 0;

  /// How many holds are outstanding.
  int get holds => _holds;

  /// Asks for the screen to stay awake until a matching [release].
  Future<void> hold() async {
    _holds++;
    if (_holds == 1) await _apply(true);
  }

  /// Gives up one hold. The screen keeps its reprieve while others remain.
  Future<void> release() async {
    // Never below zero: an unpaired release would otherwise let the next
    // hold start from a debt and never reach the plugin at all.
    if (_holds == 0) return;
    _holds--;
    if (_holds == 0) await _apply(false);
  }

  Future<void> _apply(bool enabled) async {
    try {
      await _set(enabled);
    } catch (e) {
      // A broadcast is not worth failing over the idle timer.
      logger.w('Wakelock ${enabled ? 'enable' : 'disable'} failed', error: e);
    }
  }
}

/// The app's one hold on the screen, so that holders can be counted.
final screenWakelock = ScreenWakelock();
