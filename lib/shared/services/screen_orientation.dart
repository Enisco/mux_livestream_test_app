import 'dart:ui' show FlutterView;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Which way up the app is allowed to be.
abstract final class ScreenOrientation {
  /// Every orientation the app runs in. `main.dart` asks for these at
  /// startup and anything that narrows them restores exactly these.
  ///
  /// Upright only: every screen is drawn against a 390x844 portrait frame,
  /// and the one surface that wants the long edge — a landscape video filling
  /// the screen — asks for [landscape] while it is up. Letting the whole app
  /// turn meant a fullscreen video could be rotated twice: once by the
  /// device, once by the route.
  static const app = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  /// Sideways, for a video whose own shape is sideways.
  static const landscape = <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Turns the interface sideways.
  static Future<void> lockLandscape() =>
      SystemChrome.setPreferredOrientations(landscape);

  /// Upright, and only upright — a requirement of broadcasting, not a
  /// preference.
  static const upright = <DeviceOrientation>[DeviceOrientation.portraitUp];

  /// Pins the interface upright.
  static Future<void> lockUpright() =>
      SystemChrome.setPreferredOrientations(upright);

  /// Waits, briefly, for the interface to have actually turned upright.
  static Future<void> awaitUpright({
    FlutterView? view,
    Duration timeout = const Duration(seconds: 2),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    final it = view ?? WidgetsBinding.instance.platformDispatcher.implicitView;
    if (it == null) return;
    // Counted in steps rather than against `DateTime.now()`: the delays
    // below are the only clock that is guaranteed to be moving, and under a
    // widget test wall time barely advances at all while they do.
    var left = step.inMicroseconds <= 0
        ? 0
        : timeout.inMicroseconds ~/ step.inMicroseconds;
    while (left > 0 && it.physicalSize.width > it.physicalSize.height) {
      await Future<void>.delayed(step);
      left--;
    }
  }

  /// Hands the app's own set back.
  static Future<void> restore() => SystemChrome.setPreferredOrientations(app);
}
