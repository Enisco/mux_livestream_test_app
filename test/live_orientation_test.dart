import 'dart:async';
import 'dart:io';

import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/views/live_broadcast_screen.dart';
import 'package:test_app/features/livestream/views/start_livestream_screen.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/shared/services/screen_orientation.dart';
import 'package:test_app/shared/services/screen_wakelock.dart';
import 'helpers/load_app_fonts.dart';

/// Which way up a broadcast records.
///
/// Reported on 2026-11-13: a livestream recorded from the phone played
/// back landscape on the web, and upright-but-letterboxed in the phone's
/// own player. The asset really was landscape — the app asks for
/// `Resolution.RESOLUTION_720`, 1280x720, and the native SDK decides which
/// way round to use it from the **interface** orientation:
///
///   * iOS (`ApiVideoLiveStream.swift`) reads
///     `UIApplication.shared.statusBarOrientation` when the controller is
///     constructed, and `prepareVideo` then picks
///     `max(w, h) x min(w, h)` for a landscape interface and the swap of
///     that otherwise. `orientationDidChange` repeats it on every
///     `UIDevice.orientationDidChangeNotification`, reassigning
///     `videoSettings.videoSize` *during* a broadcast.
///   * Android's StreamPack takes its target rotation from the activity
///     and the plugin never overrides it.
///
/// `main.dart` allows all four orientations and neither broadcast screen
/// pinned one, so the frame size was whatever way the creator happened to
/// be holding the phone — and could change mid-sermon.
///
/// These tests watch the real platform channel, because
/// `SystemChrome.setPreferredOrientations` is the whole fix and a screen
/// that stops calling it is the regression.
///
/// One part is *not* pinned: both screens ask once in `initState` and then
/// `await` the same lock before building the camera. Only the awaited one
/// waits for the platform to accept the preference, which is what matters
/// on a device — but a mock channel accepts instantly, so a test cannot
/// tell the two apart. Deleting the awaited call alone leaves every test
/// here green. It is unpinned defence, kept deliberately.
const _liveChannel = MethodChannel('video.api.livestream/controller');

/// Everything the screens send down `SystemChannels.platform`, in order,
/// with the broadcast controller's own milestones interleaved — the order
/// is the point, not just the calls.
late List<String> _log;

void _watchPlatform(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemChrome.setPreferredOrientations') {
      final names = (call.arguments as List)
          .map((e) => '$e'.replaceFirst('DeviceOrientation.', ''))
          .join(',');
      _log.add('orientations:$names');
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

/// A camera that opens, so the screen gets past the permission gate and
/// as far as building the native session — which is the moment the
/// orientation has to already be settled.
class _RecordingController implements ApiVideoLiveStreamController {
  int initializes = 0;

  @override
  bool get isInitialized => initializes > 0;

  @override
  Future<void> initialize() async {
    initializes++;
    _log.add('initialize');
  }

  @override
  Future<void> startPreview() async => _log.add('startPreview');

  @override
  Future<void> startStreaming({
    required String streamKey,
    String url = '',
  }) async => _log.add('startStreaming');

  @override
  Future<void> stopStreaming() async {}

  @override
  Future<void> stopPreview() async {}

  @override
  Future<void> dispose() async {}

  @override
  int get textureId => ApiVideoLiveStreamController.kUninitializedTextureId;

  @override
  void addWidgetListener(ApiVideoLiveStreamWidgetListener listener) {}

  @override
  void removeWidgetListener(ApiVideoLiveStreamWidgetListener listener) {}

  @override
  void addEventsListener(ApiVideoLiveStreamEventsListener listener) {}

  @override
  void removeEventsListener(ApiVideoLiveStreamEventsListener listener) {}

  @override
  Future<Size?> get videoSize async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A backend that puts the broadcast on air. Without one the screen
/// reaches `LivestreamRepo`, which resolves `ApiService` out of the
/// locator a widget test has no reason to build.
class _Repo implements LivestreamRepo {
  @override
  Future<DateTime?> armIngest(String mediaId) async =>
      DateTime.now().add(const Duration(minutes: 10));

  @override
  Future<LiveRuntime> start(String mediaId) async => LiveRuntime.connecting;

  @override
  Future<LivestreamStudio> studio(String mediaId) async => LivestreamStudio(
    runtime: LiveRuntime.live,
    isLiveNow: true,
    startedAt: DateTime.now(),
  );

  @override
  Future<void> end(String mediaId, {String reason = 'creator'}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playback implements PlaybackHandle {
  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => _log = <String>[]);

  group('the orientation set the app runs in', () {
    test('is every orientation, in one place', () {
      // `main.dart` and everything that restores after narrowing read the
      // same list, so a screen can hand back what it found instead of
      // guessing.
      expect(ScreenOrientation.all, [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

    test('and upright means portraitUp alone', () {
      // Not `portraitDown` as well: it encodes the same frame size upside
      // down, which is a broadcast nobody can watch.
      expect(ScreenOrientation.upright, [DeviceOrientation.portraitUp]);
    });
  });

  group('waiting for the turn', () {
    testWidgets('lets a screen that is already upright straight through', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      addTearDown(tester.view.reset);

      var done = false;
      unawaited(ScreenOrientation.awaitUpright().then((_) => done = true));
      await tester.pump();

      expect(done, isTrue);
    });

    testWidgets('and holds a sideways one until it has turned', (tester) async {
      // A creator who opens go-live holding the phone in landscape: the
      // lock is in flight, the screen has not caught up, and the encoder
      // reads the orientation as it is built.
      tester.view.physicalSize = const Size(844 * 3, 390 * 3);
      addTearDown(tester.view.reset);

      var done = false;
      unawaited(ScreenOrientation.awaitUpright().then((_) => done = true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(done, isFalse, reason: 'still sideways');

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(done, isTrue);
    });

    testWidgets('and gives up rather than holding a broadcast hostage', (
      tester,
    ) async {
      // Past the deadline the SDK's own rotation observer is the safety
      // net. A livestream that will not start is worse than one framed
      // the wrong way.
      tester.view.physicalSize = const Size(844 * 3, 390 * 3);
      addTearDown(tester.view.reset);

      var done = false;
      unawaited(
        ScreenOrientation.awaitUpright(
          timeout: const Duration(milliseconds: 300),
        ).then((_) => done = true),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(done, isTrue, reason: 'it never turned, and it started anyway');
    });
  });

  group('whoever narrows it', () {
    // `PlayerScreen` cannot be mounted in a unit test — it needs libmpv —
    // and it is where the second half of this bug lived: one
    // `_restorePortrait` served both leaving fullscreen *and* leaving the
    // screen, so watching one video left the whole app unable to rotate
    // until it was restarted. These read the source instead, which is the
    // same thing `ios_permission_config_test` does for a build setting.
    final dart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    final callers = {
      for (final f in dart)
        if (f.readAsStringSync().contains('setPreferredOrientations('))
          f.path: f.readAsStringSync(),
    }..removeWhere((path, _) => path.endsWith('screen_orientation.dart'));

    test('has somewhere to narrow from', () {
      // If this empties out, the two below stop being able to fail.
      expect(callers, isNotEmpty);
    });

    test('puts the app orientations back, not a set of its own', () {
      for (final entry in callers.entries) {
        expect(
          entry.value,
          contains('ScreenOrientation.'),
          reason:
              '${entry.key} changes the orientations without going through '
              'the one list that says what the app runs in',
        );
      }
    });

    test('and does not keep its own copy of that list', () {
      // Naming all four across two *different* narrowed calls is fine —
      // the player has a landscape pair for fullscreen and a portrait pair
      // for leaving it. What must not come back is a second spelling of
      // the whole set in one call, because that is the copy that drifts.
      final literal = RegExp(
        r'setPreferredOrientations\(\s*\[(.*?)\]',
        dotAll: true,
      );
      for (final entry in callers.entries) {
        for (final call in literal.allMatches(entry.value)) {
          final list = call.group(1)!;
          final names = [
            'portraitUp',
            'portraitDown',
            'landscapeLeft',
            'landscapeRight',
          ].where(list.contains).length;
          expect(
            names,
            lessThan(4),
            reason:
                '${entry.key} writes the app\'s whole orientation set out '
                'in place of ScreenOrientation.all; a second copy is a '
                'second thing to forget to change',
          );
        }
      }
    });
  });

  group('LiveBroadcastScreen', () {
    Future<_RecordingController> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      _watchPlatform(tester);

      final controller = _RecordingController();
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            home: LiveBroadcastScreen(
              mediaId: 'm-1',
              rtmpIngestUrl: 'rtmp://example.test/app',
              streamKey: 'key',
              controller: controller,
              live: _Repo(),
              ask: (_) async => PermissionStatus.granted,
              wakelock: ScreenWakelock(set: (_) async {}),
              playback: _Playback(),
            ),
          ),
        ),
      );
      // A broadcast runs timers for its whole life, so this never settles.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      return controller;
    }

    testWidgets('pins the interface upright', (tester) async {
      await pump(tester);

      expect(_log, contains('orientations:portraitUp'));
    });

    testWidgets('and does it before the camera is built, not after', (
      tester,
    ) async {
      // The native controller reads the interface orientation as it is
      // constructed. Locking afterwards is locking too late: the encoder
      // already has its frame size.
      final controller = await pump(tester);
      expect(controller.initializes, 1);

      expect(
        _log.indexOf('orientations:portraitUp'),
        lessThan(_log.indexOf('initialize')),
        reason: 'the lock has to land first — $_log',
      );
    });

    testWidgets('holds the camera back until the screen has turned', (
      tester,
    ) async {
      // Opening go-live while holding the phone sideways. The lock goes
      // out in `initState`, but UIKit takes its time, and the encoder
      // reads the orientation as the native controller is built — so the
      // camera has to wait for the turn, not merely for the preference.
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(844 * 3, 390 * 3);
      addTearDown(tester.view.reset);
      _watchPlatform(tester);

      final controller = _RecordingController();
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            home: LiveBroadcastScreen(
              mediaId: 'm-1',
              rtmpIngestUrl: 'rtmp://example.test/app',
              streamKey: 'key',
              controller: controller,
              live: _Repo(),
              ask: (_) async => PermissionStatus.granted,
              wakelock: ScreenWakelock(set: (_) async {}),
              playback: _Playback(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(_log, contains('orientations:portraitUp'));
      expect(
        controller.initializes,
        0,
        reason: 'the camera must not be built while the screen is sideways',
      );

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(controller.initializes, 1);
    });

    testWidgets('and hands the app its orientations back on the way out', (
      tester,
    ) async {
      await pump(tester);
      _log.clear();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(
        _log,
        contains(
          'orientations:portraitUp,portraitDown,landscapeLeft,landscapeRight',
        ),
        reason: 'leaving a broadcast must not leave the app upright-only',
      );
    });
  });

  group('StartLivestreamScreen', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      _watchPlatform(tester);

      // Its controller is built in `initState` and is not injectable, so
      // the plugin is stubbed: `initialize` is recorded off the channel
      // instead of off a fake.
      ApiVideoMobileLiveStreamPlatform.registerWith();
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_liveChannel, (call) async {
        _log.add('live:${call.method}');
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_liveChannel, null));

      await tester.pumpWidget(
        MaterialApp(
          home: StartLivestreamScreen(
            ask: (_) async => PermissionStatus.granted,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pins the interface upright before creating the session', (
      tester,
    ) async {
      await pump(tester);

      expect(_log, contains('orientations:portraitUp'));
      expect(
        _log.indexOf('orientations:portraitUp'),
        lessThan(_log.indexOf('live:create')),
        reason: 'the lock has to land before the native session — $_log',
      );
    });

    testWidgets('and restores the app orientations on the way out', (
      tester,
    ) async {
      await pump(tester);
      _log.clear();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(
        _log,
        contains(
          'orientations:portraitUp,portraitDown,landscapeLeft,landscapeRight',
        ),
      );
    });
  });
}
