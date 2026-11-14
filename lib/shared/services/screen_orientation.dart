import 'dart:ui' show FlutterView;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Which way up the app is allowed to be.
///
/// In one place because a screen that narrows the set has to put back the
/// same set it found. `player_screen` restored portrait alone, which is
/// narrower than what `main.dart` asks for, so leaving a fullscreen video
/// left the whole app portrait-only until it was restarted.
abstract final class ScreenOrientation {
  /// Every orientation the app runs in. `main.dart` asks for these at
  /// startup and anything that narrows them restores exactly these.
  static const all = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Upright, and only upright — a requirement of broadcasting, not a
  /// preference.
  ///
  /// Both live SDKs take the encoder's frame size from the **interface**
  /// orientation, not from the resolution the app asks for. iOS reads
  /// `UIApplication.shared.statusBarOrientation` when the controller is
  /// built and swaps 1280x720 to 720x1280 unless it is landscape — and
  /// re-swaps on every `UIDevice.orientationDidChangeNotification`, so an
  /// unlocked interface can change the frame size *mid-broadcast*.
  /// Android's StreamPack takes its target rotation from the activity the
  /// same way, and the plugin never sets it.
  ///
  /// So a rotated phone did not produce a rotated picture in an upright
  /// frame: it produced a genuinely landscape recording, which is why the
  /// replay played landscape on the web while a portrait phone player
  /// fitted it into an upright page. Only `portraitUp`: `portraitDown`
  /// encodes the same frame size upside down.
  static const upright = <DeviceOrientation>[DeviceOrientation.portraitUp];

  /// Pins the interface upright.
  ///
  /// Fire and forget: the message is dispatched synchronously, which is
  /// all the ordering the platform side needs, and awaiting it would only
  /// tell you the *preference* was accepted — not that the screen had
  /// finished turning. Use [awaitUpright] for that.
  static Future<void> lockUpright() =>
      SystemChrome.setPreferredOrientations(upright);

  /// Waits, briefly, for the interface to have actually turned upright.
  ///
  /// A creator who opens go-live holding the phone sideways has a lock in
  /// flight and a landscape screen, and the encoder reads the orientation
  /// as it is built — so the camera waits for the turn rather than for an
  /// acknowledgement. The view's own size is the only signal Flutter
  /// gives that it has happened.
  ///
  /// Bounded, and it never throws: a broadcast that cannot be framed
  /// perfectly is still better than one that will not start. Past the
  /// deadline the SDK's own rotation observer is the remaining safety
  /// net — it re-reads the orientation and resizes on the next movement
  /// of the phone.
  ///
  /// Reads the binding's own view rather than one looked up from a
  /// `BuildContext`, because callers reach this from `initState`, where
  /// `View.of` is not allowed — and rather than
  /// `PlatformDispatcher.instance`, which under a widget test is the real
  /// dispatcher and reports a default 800x600 that is landscape, so every
  /// test would sit here until the deadline.
  static Future<void> awaitUpright({
    FlutterView? view,
    Duration timeout = const Duration(seconds: 2),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    final it = view ?? WidgetsBinding.instance.platformDispatcher.implicitView;
    if (it == null) return;
    // Counted in steps rather than against `DateTime.now()`: the delays
    // below are the only clock that is guaranteed to be moving, and under
    // a widget test wall time barely advances at all while they do.
    var left = step.inMicroseconds <= 0
        ? 0
        : timeout.inMicroseconds ~/ step.inMicroseconds;
    while (left > 0 && it.physicalSize.width > it.physicalSize.height) {
      await Future<void>.delayed(step);
      left--;
    }
  }

  /// Hands the app's own set back.
  static Future<void> restore() => SystemChrome.setPreferredOrientations(all);
}
