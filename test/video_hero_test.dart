import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/features/discovery/views/widgets/video_hero.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'helpers/load_app_fonts.dart';
import 'support/fake_playback.dart';

const _url = 'https://cdn/clip.m3u8';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

/// Pumps the hero under a screen that reserves room for a notch, the way the
/// detail screen does.
Future<void> _pumpUnderNotch(
  WidgetTester tester,
  Widget child, {
  double topInset = 60,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: topInset)),
          child: Scaffold(
            body: Column(
              children: [
                SizedBox(height: topInset),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

VideoHero _hero(FakePlayback playback, {String? url = _url}) => VideoHero(
  playback: playback,
  target: const PlaybackTarget(mediaId: 'm-video-1', creatorId: 'c1'),
  playbackUrl: url,
);

void main() {
  setUpAll(() {
    loadAppFonts();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('video detail hero', () {
    testWidgets('the back arrow sits at the top of the frame', (tester) async {
      // The screen already holds the frame clear of the status bar, so the
      // arrow must not reserve room for it a second time — that dropped it
      // into the middle of the picture.
      final playback = FakePlayback();
      await _pumpUnderNotch(tester, _hero(playback));

      final frame = tester.getRect(find.byType(VideoHero));
      final back = tester.getRect(find.byType(GTubeBackButton));

      expect(back.top - frame.top, lessThan(24));
      expect(back.left - frame.left, lessThan(24));
    });

    testWidgets('opening a video starts it without another tap', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback));

      expect(playback.played, ['m-video-1']);
    });

    testWidgets('arriving from a playing card continues, never restarts', (
      tester,
    ) async {
      final playback = FakePlayback()
        ..emit(
          mediaId: 'm-video-1',
          kind: PlaybackKind.video,
          position: const Duration(seconds: 40),
        );
      await _pump(tester, _hero(playback));

      // No reopen — the position the card reached is the position here.
      expect(playback.played, isEmpty);
      expect(playback.state.value.position, const Duration(seconds: 40));
      expect(playback.state.value.playing, isTrue);
    });

    testWidgets('arriving from a card the feed paused resumes it', (
      tester,
    ) async {
      final playback = FakePlayback()
        ..emit(
          mediaId: 'm-video-1',
          kind: PlaybackKind.video,
          playing: false,
          position: const Duration(seconds: 40),
        );
      await _pump(tester, _hero(playback));

      expect(playback.resumes, 1);
      expect(playback.played, isEmpty);
      expect(playback.state.value.position, const Duration(seconds: 40));
    });

    testWidgets('a hero with no url yet waits for it', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback, url: null));
      expect(playback.played, isEmpty);

      // The detail fetch lands and the URL arrives.
      await _pump(tester, _hero(playback));
      expect(playback.played, ['m-video-1']);
    });

    testWidgets('the hero carries the controls the card withholds', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback));
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('the centre control pauses and resumes in place', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback));

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(playback.pauses, 1);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(playback.resumes, 1);
      // One open for the whole screen — pausing never reloads the stream.
      expect(playback.played, ['m-video-1']);
    });

    testWidgets('mute here is the same global flag the feed uses', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback));

      await tester.tap(find.byIcon(Icons.volume_off_rounded));
      await tester.pump();

      expect(playback.muted.value, isFalse);
    });

    testWidgets('fullscreen hands the video over and takes it back', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback));

      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pumpAndSettle();

      // Only one surface may hold the video at a time.
      expect(playback.fullscreen.value, isTrue);
      expect(find.byType(FullscreenVideo), findsOneWidget);
      expect(find.byType(RotatedBox), findsWidgets);
      // Playback is untouched by the handover.
      expect(playback.played, ['m-video-1']);

      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pumpAndSettle();

      expect(playback.fullscreen.value, isFalse);
      expect(find.byType(FullscreenVideo), findsNothing);
      expect(playback.played, ['m-video-1']);
    });

    testWidgets('going fullscreen does not pause the video it is showing', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback));

      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pumpAndSettle();

      // The hero is covered, but by the same video — pausing here would be
      // absurd.
      expect(playback.pauses, 0);
      expect(playback.state.value.playing, isTrue);
    });

    testWidgets('leaving the screen stops it playing unseen', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback));
      expect(playback.state.value.playing, isTrue);

      // Whatever replaced the detail, nothing is showing this video now.
      await _pump(tester, const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(playback.state.value.playing, isFalse);
    });

    testWidgets('fullscreen turns the picture, not the phone', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback));

      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pumpAndSettle();

      final rotated = tester.widget<RotatedBox>(
        find
            .descendant(
              of: find.byType(FullscreenVideo),
              matching: find.byType(RotatedBox),
            )
            .first,
      );
      expect(rotated.quarterTurns, 1);
    });
  });
}
