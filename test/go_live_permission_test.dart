import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/live_broadcast_screen.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// What the creator is offered when the camera is refused.
class _FakeController implements ApiVideoLiveStreamController {
  @override
  bool get isInitialized => false;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A camera that opens and then will not preview.
class _OpenedThenFailingController implements ApiVideoLiveStreamController {
  int initializes = 0;
  int previews = 0;

  @override
  bool get isInitialized => initializes > 0;

  @override
  Future<void> initialize() async => initializes++;

  @override
  Future<void> startPreview() async {
    previews++;
    throw Exception('the camera is busy');
  }

  @override
  Future<void> dispose() async {}

  // Reporting itself initialised means the screen mounts the real
  // `ApiVideoCameraPreview` over it.
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
  Future<void> stopPreview() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<List<Permission>> _pump(
  WidgetTester tester, {
  required PermissionStatus status,
  ApiVideoLiveStreamController? controller,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final asked = <Permission>[];
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        home: LiveBroadcastScreen(
          mediaId: 'm-1',
          rtmpIngestUrl: 'rtmp://example.test/app',
          streamKey: 'key',
          controller: controller ?? _FakeController(),
          ask: (permission) async {
            asked.add(permission);
            return status;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return asked;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a standing refusal is sent to Settings, not round again', (
    tester,
  ) async {
    // iOS asks exactly once. "Try again" against a standing no is a button
    // that cannot work, so it must not be the only thing on offer.
    await _pump(tester, status: PermissionStatus.permanentlyDenied);

    expect(find.text(AppStrings.goLiveCameraBlocked), findsOneWidget);
    expect(find.byKey(const ValueKey('live-failed-settings')), findsOneWidget);
    expect(find.text(AppStrings.openSettings), findsOneWidget);
  });

  testWidgets('and keeps the retry for the walk back from Settings', (
    tester,
  ) async {
    await _pump(tester, status: PermissionStatus.permanentlyDenied);

    expect(find.byKey(const ValueKey('live-failed-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-failed-back')), findsOneWidget);
  });

  testWidgets('a refusal it can ask about again is not sent to Settings', (
    tester,
  ) async {
    // Nothing is wrong in Settings yet, and sending someone there to look
    // at a switch they have never been asked about is a dead end of its
    // own.
    await _pump(tester, status: PermissionStatus.denied);

    expect(find.text(AppStrings.goLiveNeedsCamera), findsOneWidget);
    expect(find.byKey(const ValueKey('live-failed-settings')), findsNothing);
    expect(find.byKey(const ValueKey('live-failed-retry')), findsOneWidget);
  });

  testWidgets('both are asked for, and the microphone is not forgotten', (
    tester,
  ) async {
    final asked = await _pump(tester, status: PermissionStatus.denied);

    expect(asked, [Permission.camera, Permission.microphone]);
  });

  testWidgets('trying again asks again, rather than pushing a dead stream', (
    tester,
  ) async {
    // The bug under this one: `_retry` armed the ingest window and pushed,
    // which is right for a lost connection and useless here — the camera
    // was never opened and no window was ever armed.
    final asked = await _pump(tester, status: PermissionStatus.denied);
    expect(asked, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('live-failed-retry')));
    await tester.pumpAndSettle();

    expect(
      asked,
      hasLength(4),
      reason: 'the camera and microphone are asked for a second time',
    );
  });

  testWidgets('a camera already open is not opened a second time', (
    tester,
  ) async {
    // Only reachable since "Try again" started going back through the whole
    // attempt, which a refused camera needs.
    final controller = _OpenedThenFailingController();
    await _pump(
      tester,
      status: PermissionStatus.granted,
      controller: controller,
    );

    expect(controller.initializes, 1);
    expect(controller.previews, 1);
    expect(find.text(AppStrings.goLiveCameraFailed), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('live-failed-retry')));
    await tester.pumpAndSettle();

    expect(controller.initializes, 1, reason: 'opened once, not twice');
    expect(controller.previews, 2, reason: 'but the preview is tried again');
  });
}
