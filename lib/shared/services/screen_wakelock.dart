import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:test_app/core/logger.dart';

/// Turns the screen's auto-lock off and on.
typedef WakelockSetter = Future<void> Function(bool enabled);

/// Keeps the screen awake while something on screen needs it to be.
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
