import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/views/live_broadcast_screen.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/shared/services/screen_wakelock.dart';
import 'helpers/load_app_fonts.dart';

/// Which camera a broadcast starts on.
///
/// `ApiVideoLiveStreamController`'s own default is `CameraPosition.back`,
/// so going live pointed the camera away from the creator. The position is
/// only applied inside `initialize()`, as a `setCameraPosition` over the
/// plugin channel — so this builds the screen's *real* controller against
/// a stubbed channel and reads what it asked for. A test that injected a
/// fake controller could not see this at all.
const _controllerChannel = MethodChannel('video.api.livestream/controller');
const _eventChannel = MethodChannel('video.api.livestream/events');

class _Repo implements LivestreamRepo {
  @override
  Future<DateTime?> armIngest(String mediaId) async => null;

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

/// Every call the controller makes, in order.
Future<List<MethodCall>> _onAir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  ApiVideoMobileLiveStreamPlatform.registerWith();
  final calls = <MethodCall>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_controllerChannel, (call) async {
    calls.add(call);
    return switch (call.method) {
      // An uninitialised texture id keeps `ApiVideoCameraPreview` rendering
      // an empty box, and the native orientation reader out of the test.
      'create' => {
        'textureId': ApiVideoLiveStreamController.kUninitializedTextureId,
      },
      'getCameraPosition' => {'position': 'front'},
      // These three answer with maps the plugin casts unconditionally, so
      // a null would throw inside it rather than here.
      'getVideoSize' => {'width': 1280.0, 'height': 720.0},
      'getIsMuted' => {'isMuted': false},
      'getIsStreaming' => {'isStreaming': false},
      _ => null,
    };
  });
  messenger.setMockMethodCallHandler(_eventChannel, (_) async => null);
  addTearDown(() {
    messenger.setMockMethodCallHandler(_controllerChannel, null);
    messenger.setMockMethodCallHandler(_eventChannel, null);
  });

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        home: LiveBroadcastScreen(
          mediaId: 'm-1',
          rtmpIngestUrl: 'rtmp://example.test/app',
          streamKey: 'key',
          live: _Repo(),
          ask: (_) async => PermissionStatus.granted,
          wakelock: ScreenWakelock(set: (_) async {}),
        ),
      ),
    ),
  );
  // Timers run for the whole broadcast, so this cannot settle.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return calls;
}

List<String> _positionsSet(List<MethodCall> calls) => calls
    .where((c) => c.method == 'setCameraPosition')
    .map((c) => (c.arguments as Map)['position'] as String)
    .toList();

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a broadcast opens on the camera pointing at the creator', (
    tester,
  ) async {
    final calls = await _onAir(tester);

    expect(_positionsSet(calls), ['front']);
  });

  testWidgets('and the creator can turn it around', (tester) async {
    final calls = await _onAir(tester);
    expect(find.byKey(const ValueKey('live-flip')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('live-flip')));
    await tester.pump();
    await tester.pump();

    // Read, then set the other one: the plugin asks the platform which
    // camera is live rather than assuming, so this is right from either
    // starting position.
    expect(_positionsSet(calls), ['front', 'back']);
  });
}
