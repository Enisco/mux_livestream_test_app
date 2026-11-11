import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:test_app/features/livestream/views/start_livestream_screen.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// The older go-live screen, reached from the landing screen.
///
/// It had the same two faults as `LiveBroadcastScreen`: one dead end for a
/// refusal the system would still ask about, and — once the permission was
/// granted and the camera itself failed — a heading about permissions, a
/// raw `e.toString()` for a body, and a button to Settings over a
/// permission that was not the problem.
///
/// `ApiVideoLiveStreamController` is built in `initState` and not
/// injectable here, so the plugin is registered against a stubbed channel
/// instead: `create` answers nothing, which is how the camera is made to
/// fail. Without the registration every call raises `UnimplementedError`
/// from the platform interface's own defaults, including the `dispose()`
/// each teardown runs.
const _channel = MethodChannel('video.api.livestream/controller');

Future<List<Permission>> _pump(
  WidgetTester tester, {
  required PermissionStatus status,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  ApiVideoMobileLiveStreamPlatform.registerWith();
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, (call) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  final asked = <Permission>[];
  await tester.pumpWidget(
    MaterialApp(
      home: StartLivestreamScreen(
        ask: (permission) async {
          asked.add(permission);
          // The real ask puts a system dialog in front of the creator and
          // takes as long as they do, so it must not resolve inside the
          // same frame as the tap that started it.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return status;
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return asked;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a standing refusal is the one sent to Settings', (tester) async {
    await _pump(tester, status: PermissionStatus.permanentlyDenied);

    expect(find.text(AppStrings.cameraPermNeeded), findsOneWidget);
    expect(find.text(AppStrings.cameraPermDeniedBody), findsOneWidget);
    expect(find.text(AppStrings.openSettings), findsOneWidget);
  });

  testWidgets('a refusal the system will ask about again offers the ask', (
    tester,
  ) async {
    await _pump(tester, status: PermissionStatus.denied);

    expect(find.text(AppStrings.cameraPermNeeded), findsOneWidget);
    expect(find.text(AppStrings.openSettings), findsNothing);
    expect(find.text(AppStrings.feedRetry), findsOneWidget);
  });

  testWidgets('and asking again both asks and shows that it is working', (
    tester,
  ) async {
    final asked = await _pump(tester, status: PermissionStatus.denied);
    expect(asked, [Permission.camera, Permission.microphone]);

    await tester.tap(find.byKey(const ValueKey('start-live-recover')));
    await tester.pump();

    // The spinner is the feedback: the button used to leave the error in
    // place for as long as the system took, which reads as a dead button.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(asked, hasLength(4));
  });

  testWidgets('a camera that will not open says so, and not in Dart', (
    tester,
  ) async {
    // Permissions are granted here, so Settings has nothing to fix and the
    // permission heading would name the wrong problem.
    await _pump(tester, status: PermissionStatus.granted);

    expect(find.text(AppStrings.cameraFailedTitle), findsOneWidget);
    expect(find.text(AppStrings.cameraPermNeeded), findsNothing);
    expect(find.text(AppStrings.goLiveCameraFailed), findsOneWidget);
    expect(find.text(AppStrings.openSettings), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('TypeError'), findsNothing);
  });
}
