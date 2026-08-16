import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/features/home/data/feed_autoplay_coordinator.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'helpers/load_app_fonts.dart';
import 'support/fake_playback.dart';

const _clip = FeedCardData(
  id: 'm-video-1',
  kind: FeedCardKind.video,
  creatorName: 'GospelTube',
  handle: 'gospeltube',
  age: '2w',
  title: 'Big Buck',
  duration: '5:15',
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    loadAppFonts();
    // Otherwise its debounce timer outlives the widget tree and every test
    // fails on a pending timer.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('video feed card', () {
    testWidgets('an idle card shows the catalogue duration', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, FeedCard(data: _clip, playback: playback));

      expect(find.text('5:15'), findsOneWidget);
    });

    testWidgets('a playing card shows how far it has got', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, FeedCard(data: _clip, playback: playback));

      playback.emit(
        mediaId: 'm-video-1',
        kind: PlaybackKind.video,
        position: const Duration(seconds: 12),
        duration: const Duration(minutes: 5, seconds: 15),
      );
      await tester.pump();

      // The running clock is the only cue that a black-rendering clip is live.
      expect(find.text('0:12 / 5:15'), findsOneWidget);
      expect(find.text('5:15'), findsNothing);
    });

    testWidgets('another card playing leaves this one showing its duration', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, FeedCard(data: _clip, playback: playback));

      playback.emit(mediaId: 'a-different-clip', kind: PlaybackKind.video);
      await tester.pump();

      expect(find.text('5:15'), findsOneWidget);
    });

    testWidgets('a card with no known duration keeps the static label', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, FeedCard(data: _clip, playback: playback));

      // Active but the player has not reported a duration yet.
      playback.emit(
        mediaId: 'm-video-1',
        kind: PlaybackKind.video,
        duration: Duration.zero,
      );
      await tester.pump();

      expect(find.text('5:15'), findsOneWidget);
    });

    testWidgets('a surface that cannot autoplay shows a still, not controls', (
      tester,
    ) async {
      final playback = FakePlayback()
        ..emit(mediaId: 'm-video-1', kind: PlaybackKind.video);
      // No coordinator: search results and "Up next" rows never autoplay, so
      // a mute button there would control something the surface cannot start.
      await _pump(tester, FeedCard(data: _clip, playback: playback));

      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
    });

    testWidgets('the mute toggle appears only on the playing card', (
      tester,
    ) async {
      final playback = FakePlayback();
      final autoplay = FeedAutoplayCoordinator(playback: playback);
      addTearDown(autoplay.dispose);
      await _pump(
        tester,
        FeedCard(data: _clip, playback: playback, coordinator: autoplay),
      );

      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);

      playback.emit(mediaId: 'm-video-1', kind: PlaybackKind.video);
      await tester.pump();

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('the mute toggle flips the global flag, not the card', (
      tester,
    ) async {
      final playback = FakePlayback()
        ..emit(mediaId: 'm-video-1', kind: PlaybackKind.video);
      final autoplay = FeedAutoplayCoordinator(playback: playback);
      addTearDown(autoplay.dispose);
      var opened = 0;
      await _pump(
        tester,
        FeedCard(
          data: _clip,
          playback: playback,
          coordinator: autoplay,
          onTap: () => opened++,
        ),
      );

      await tester.tap(find.byIcon(Icons.volume_off_rounded));
      await tester.pump();

      expect(playback.muted.value, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      // The only control on the card must not double as a way in.
      expect(opened, 0);
    });

    testWidgets('tapping the card opens it even while playing', (tester) async {
      final playback = FakePlayback()
        ..emit(mediaId: 'm-video-1', kind: PlaybackKind.video);
      var opened = 0;
      await _pump(
        tester,
        FeedCard(data: _clip, playback: playback, onTap: () => opened++),
      );

      // A video card carries no title text — the frame itself is the target.
      await tester.tapAt(tester.getCenter(find.byType(FeedCard)));
      await tester.pump();

      expect(opened, 1);
    });
  });
}
