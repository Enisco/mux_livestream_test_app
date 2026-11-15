// ignore_for_file: invalid_use_of_internal_member
// The widget under test reaches the plugin's texture hooks; so must its
// double.

import 'dart:io';

import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/views/widgets/broadcast_preview.dart';
import 'package:test_app/shared/components/video_fit.dart';

class _FakeController implements ApiVideoLiveStreamController {
  _FakeController({this.id = 7, this.reports = const Size(1280, 720)});

  int id;

  /// What `videoSize` answers. The controller reports the *configured*
  /// resolution, which is written landscape-first whichever way the camera
  /// is pointing.
  final Size reports;

  final List<ApiVideoLiveStreamWidgetListener> listeners = [];

  @override
  int get textureId => id;

  @override
  bool get isInitialized => true;

  @override
  Future<Size?> get videoSize async => reports;

  @override
  void addWidgetListener(ApiVideoLiveStreamWidgetListener listener) =>
      listeners.add(listener);

  @override
  void removeWidgetListener(ApiVideoLiveStreamWidgetListener listener) =>
      listeners.remove(listener);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A phone-shaped surface, the way the broadcast screen hands one over.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: 390, height: 844, child: child)),
    ),
  );
  await tester.pump();
}

Size _textureBox(WidgetTester tester) {
  final box = tester.widget<SizedBox>(
    find
        .ancestor(of: find.byType(Texture), matching: find.byType(SizedBox))
        .first,
  );
  return Size(box.width!, box.height!);
}

void main() {
  group('what the creator sees of themselves', () {
    testWidgets('the camera is not stretched into a landscape box', (
      tester,
    ) async {
      // The bug: the plugin's own preview laid the upright camera buffer
      // into a 1280x720 box, so the creator watched a squashed, widened
      // version of themselves while the stream went out upright.
      await _pump(tester, BroadcastPreview(controller: _FakeController()));
      await tester.pump();

      final frame = _textureBox(tester);
      expect(
        frame.width,
        lessThan(frame.height),
        reason: 'the broadcast is pinned upright, so its frame is tall',
      );
      expect(frame, const Size(720, 1280));
    });

    testWidgets('whichever way round the controller reports it', (
      tester,
    ) async {
      await _pump(
        tester,
        BroadcastPreview(
          controller: _FakeController(reports: const Size(720, 1280)),
        ),
      );
      await tester.pump();

      expect(_textureBox(tester), const Size(720, 1280));
    });

    testWidgets('and it fills the frame the viewer will watch it in', (
      tester,
    ) async {
      await _pump(tester, BroadcastPreview(controller: _FakeController()));
      await tester.pump();

      final band = tester.getSize(find.byType(ClipRect));
      expect(band.width, closeTo(390, 0.01));
      expect(band.width / band.height, closeTo(VideoFit.landscapeAspect, 0.01));

      final fitted = tester.widget<FittedBox>(find.byType(FittedBox));
      expect(fitted.fit, VideoFit.landscapeFrame);
    });

    testWidgets('it shows nothing at all before the texture exists', (
      tester,
    ) async {
      await _pump(
        tester,
        BroadcastPreview(
          controller: _FakeController(
            id: ApiVideoLiveStreamController.kUninitializedTextureId,
          ),
        ),
      );

      expect(find.byType(Texture), findsNothing);
    });

    testWidgets('a new texture replaces the old one', (tester) async {
      final controller = _FakeController();
      await _pump(tester, BroadcastPreview(controller: controller));
      await tester.pump();

      controller.id = 11;
      for (final listener in controller.listeners) {
        listener.onTextureReady!();
      }
      await tester.pump();

      expect(tester.widget<Texture>(find.byType(Texture)).textureId, 11);
    });

    testWidgets('and it lets go of the controller when it leaves', (
      tester,
    ) async {
      final controller = _FakeController();
      await _pump(tester, BroadcastPreview(controller: controller));
      await _pump(tester, const SizedBox.shrink());

      expect(controller.listeners, isEmpty);
    });
  });

  group('the creator and the congregation share one frame', () {
    test('the viewer hero takes its shape from the same constant', () {
      // Two literals would drift, and the day they did, a creator would be
      // composing a shot nobody else sees.
      final hero = File(
        'lib/features/discovery/views/widgets/video_hero.dart',
      ).readAsStringSync();

      expect(hero, contains('aspectRatio: VideoFit.landscapeAspect'));
      expect(
        RegExp(r'aspectRatio:\s*16\s*/\s*9').hasMatch(hero),
        isFalse,
        reason: 'the hero wrote its own copy of the shape again',
      );
    });

    test('the broadcast screen uses the preview that honours it', () {
      final screen = File(
        'lib/features/creator/views/live_broadcast_screen.dart',
      ).readAsStringSync();

      expect(screen, contains('BroadcastPreview(controller: _controller)'));
      expect(
        screen,
        isNot(contains('ApiVideoCameraPreview(')),
        reason: "the plugin's own preview stretches the picture",
      );
    });
  });
}
