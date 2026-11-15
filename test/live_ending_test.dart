import 'dart:async';

import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/views/live_broadcast_screen.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/shared/services/screen_wakelock.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// Ending a broadcast, from the creator's side.
class _LiveController implements ApiVideoLiveStreamController {
  int stops = 0;
  bool _up = false;

  @override
  bool get isInitialized => _up;

  @override
  Future<void> initialize() async => _up = true;

  @override
  Future<void> startPreview() async {}

  @override
  Future<void> startStreaming({
    required String streamKey,
    String url = '',
  }) async {}

  @override
  Future<void> stopStreaming() async => stops++;

  @override
  Future<void> stopPreview() async {}

  @override
  Future<void> dispose() async {}

  // The screen mounts the real `ApiVideoCameraPreview` over an initialised
  // controller.
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

/// A backend that puts the broadcast on air and then takes its time
/// acknowledging the end, which is the few seconds this is all about.
class _LiveRepo implements LivestreamRepo {
  _LiveRepo({this.endAnswers = true});

  /// Whether `end` ever completes. False stands in for the server that
  /// accepts the request and says nothing back.
  final bool endAnswers;

  int ends = 0;
  final _ended = Completer<void>();

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
  Future<void> end(String mediaId, {String reason = 'creator'}) {
    ends++;
    return endAnswers ? Future.value() : _ended.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The app's own media playback, which must not be running underneath a
/// broadcast: the microphone would put it into the stream.
class _Playback implements PlaybackHandle {
  int stops = 0;

  @override
  Future<void> stop() async => stops++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the screen and gets it on air.
Future<_LiveRepo> _onAir(
  WidgetTester tester, {
  bool endAnswers = true,
  ScreenWakelock? wakelock,
  PlaybackHandle? playback,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  // A notch and a home indicator, so `SafeArea` has something to inset:
  // without them an overlay inside one measures the same as a full-bleed
  // one and the difference this fixes would not show.
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);

  final repo = _LiveRepo(endAnswers: endAnswers);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        home: LiveBroadcastScreen(
          mediaId: 'm-1',
          rtmpIngestUrl: 'rtmp://example.test/app',
          streamKey: 'key',
          controller: _LiveController(),
          live: repo,
          ask: (_) async => PermissionStatus.granted,
          wakelock: wakelock ?? ScreenWakelock(set: (_) async {}),
          playback: playback ?? _Playback(),
        ),
      ),
    ),
  );
  // Timers run for the whole broadcast, so this cannot settle.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));

  expect(
    find.text(AppStrings.goLiveLivePill),
    findsOneWidget,
    reason: 'the broadcast has to be on air before it can be ended',
  );
  return repo;
}

Future<void> _tapEnd(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('live-end')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(const ValueKey('live-confirm-end')));
  await tester.pump();
  await tester.pump();
}

/// Lets the bounded wait elapse and the screen leave.
Future<void> _letGo(WidgetTester tester) async {
  await tester.pump(LiveBroadcastScreen.endTimeout);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('ending says so, over the whole screen', (tester) async {
    await _onAir(tester, endAnswers: false);
    await _tapEnd(tester);

    expect(find.byKey(const ValueKey('live-ending')), findsOneWidget);
    expect(find.text(AppStrings.goLiveEnding), findsOneWidget);
    // The whole screen, notch and home indicator included: a strip of
    // live camera showing above it still reads as being on air.
    expect(
      tester.getSize(find.byKey(const ValueKey('live-ending'))),
      const Size(390, 844),
    );

    await _letGo(tester);
  });

  testWidgets('and the broadcast stops looking like one still running', (
    tester,
  ) async {
    final repo = await _onAir(tester, endAnswers: false);
    await _tapEnd(tester);

    // The three things that said "still live" while it was ending.
    expect(find.text(AppStrings.goLiveLivePill), findsNothing);
    expect(find.byKey(const ValueKey('live-chat-toggle')), findsNothing);
    // And the control that was tapped again and again is not there to be
    // tapped: before, it stayed put and only stopped responding.
    expect(find.byKey(const ValueKey('live-end')), findsNothing);
    expect(repo.ends, 1, reason: 'one tap, one request');

    await _letGo(tester);
  });

  testWidgets('a backend that never answers does not trap the creator', (
    tester,
  ) async {
    // `receiveTimeout` is unset on the dio client, so `end` can hang for
    // ever; the overlay has no way out, so the wait has to be bounded.
    await _onAir(tester, endAnswers: false);
    await _tapEnd(tester);
    expect(find.byKey(const ValueKey('live-ending')), findsOneWidget);

    await _letGo(tester);

    expect(
      find.byType(LiveBroadcastScreen),
      findsNothing,
      reason: 'it leaves the screen rather than spinning for ever',
    );
  });

  testWidgets('and an ordinary end just leaves', (tester) async {
    await _onAir(tester);
    await _tapEnd(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LiveBroadcastScreen), findsNothing);
  });

  testWidgets('the screen cannot lock while the broadcast is up', (
    tester,
  ) async {
    // Reported from the app: the phone locked itself mid-livestream.
    final asked = <bool>[];
    final wakelock = ScreenWakelock(set: (on) async => asked.add(on));

    await _onAir(tester, endAnswers: false, wakelock: wakelock);

    expect(asked, [true]);
    expect(wakelock.holds, 1);

    await _tapEnd(tester);
    // Still held while it is ending: the screen is still showing something.
    expect(asked, [true]);

    await _letGo(tester);

    expect(asked, [true, false], reason: 'and given back on the way out');
    expect(wakelock.holds, 0);
  });

  testWidgets('and the app stops playing over the broadcast', (tester) async {
    // Nothing stopped the feed when a broadcast started, so a video still
    // playing kept its audio and the microphone put it into the stream.
    final playback = _Playback();
    await _onAir(tester, playback: playback);

    expect(playback.stops, 1);
  });
}
