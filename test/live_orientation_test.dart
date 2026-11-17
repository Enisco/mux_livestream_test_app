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
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/shared/services/screen_orientation.dart';
import 'package:test_app/shared/services/screen_wakelock.dart';
import 'helpers/load_app_fonts.dart';

/// Which way up a broadcast records.

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
    test('is upright, in one place', () {
      // `main.dart` and everything that restores after narrowing read the
      // same list, so a screen can hand back what it found instead of
      // guessing. Upright because every screen is a 390x844 portrait design:
      // letting the whole app turn left a fullscreen video rotated twice,
      // once by the device and once by the route.
      expect(ScreenOrientation.app, [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    });

    test('and the only sideways set belongs to a sideways video', () {
      expect(ScreenOrientation.landscape, [
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
      // net.
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
    // until it was restarted.
    final dart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    /// Every file that turns the screen, by whatever route.
    final turners = {
      for (final f in dart)
        if (f.readAsStringSync().contains('setPreferredOrientations(') ||
            f.readAsStringSync().contains('ScreenOrientation.'))
          f.path: f.readAsStringSync(),
    };

    test('has somewhere to narrow from', () {
      // If this empties out, the two below stop being able to fail.
      expect(turners.keys, contains(endsWith('screen_orientation.dart')));
      expect(turners, hasLength(greaterThan(1)));
    });

    test('goes through the one list that says what the app runs in', () {
      for (final entry in turners.entries) {
        if (entry.key.endsWith('screen_orientation.dart')) continue;
        expect(
          entry.value,
          contains('ScreenOrientation.'),
          reason:
              '${entry.key} changes the orientations without going through '
              'the one list that says what the app runs in',
        );
      }
    });

    test('and never writes an orientation list of its own', () {
      // A second copy is a second thing to forget to change — and a screen
      // that forces landscape for a video that is not landscape is exactly
      // the bug the fullscreen route had.
      for (final entry in turners.entries) {
        if (entry.key.endsWith('screen_orientation.dart')) continue;
        expect(
          entry.value,
          isNot(contains('setPreferredOrientations(')),
          reason: '${entry.key} asks the platform directly',
        );
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
      // constructed.
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
      // Opening go-live while holding the phone sideways.
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
        contains('orientations:portraitUp,portraitDown'),
        reason: 'leaving a broadcast must not leave the app portraitUp-only',
      );
    });
  });
}
