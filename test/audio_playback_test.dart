import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/views/widgets/audio_hero.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/utils/helpers/duration_format.dart';
import 'helpers/load_app_fonts.dart';
import 'support/fake_playback.dart';

const _track = FeedCardData(
  id: 'm-audio-1',
  kind: FeedCardKind.audio,
  creatorName: 'Hillsong Worship',
  handle: 'hillsong',
  age: '2h',
  title: 'What A Beautiful Name',
  duration: '4:32',
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
  setUpAll(loadAppFonts);

  group('audio feed card', () {
    testWidgets('the play button starts the track without opening it', (
      tester,
    ) async {
      final playback = FakePlayback();
      var opened = 0;

      await _pump(
        tester,
        FeedCard(data: _track, playback: playback, onTap: () => opened++),
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(playback.played, ['m-audio-1']);
      // The whole point: play plays, it does not navigate.
      expect(opened, 0);
    });

    testWidgets('tapping the card body still opens the detail', (tester) async {
      final playback = FakePlayback();
      var opened = 0;

      await _pump(
        tester,
        FeedCard(data: _track, playback: playback, onTap: () => opened++),
      );

      await tester.tap(find.text('What A Beautiful Name'));
      await tester.pump();

      expect(opened, 1);
      expect(playback.played, isEmpty);
    });

    testWidgets('the button shows pause while this track plays', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, FeedCard(data: _track, playback: playback));

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      playback.emit(mediaId: 'm-audio-1');
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('another track playing leaves this card idle', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, FeedCard(data: _track, playback: playback));

      playback.emit(mediaId: 'some-other-track');
      await tester.pump();

      // Two cards must never both look live.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('a card with no controller falls back to opening it', (
      tester,
    ) async {
      var opened = 0;
      await _pump(tester, FeedCard(data: _track, onTap: () => opened++));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      // Nothing to play in place with, so the tap reaches the card and opens
      // the detail rather than dying under the finger.
      expect(opened, 1);
    });
  });

  group('audio detail hero', () {
    Widget hero(FakePlayback playback, {String? url}) => AudioHero(
      playback: playback,
      target: const PlaybackTarget(mediaId: 'm-audio-1'),
      title: 'What A Beautiful Name',
      creatorName: 'Hillsong Worship',
      playbackUrl: url ?? 'https://cdn/track.m3u8',
    );

    testWidgets('play starts the track in place', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, hero(playback));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(playback.played, ['m-audio-1']);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('arriving mid-stream shows it already playing', (tester) async {
      final playback = FakePlayback()
        ..emit(mediaId: 'm-audio-1', position: const Duration(seconds: 65));
      await _pump(tester, hero(playback));

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      // Position carries over from the card that started it.
      expect(find.text('1:05'), findsOneWidget);
      expect(playback.played, isEmpty);
    });

    testWidgets('pause stops the running track', (tester) async {
      final playback = FakePlayback()..emit(mediaId: 'm-audio-1');
      await _pump(tester, hero(playback));

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      expect(playback.pauses, 1);
      expect(playback.played, isEmpty);
    });

    Finder skip(List<List<dynamic>> icon) =>
        find.byWidgetPredicate((w) => w is HugeIcon && w.icon == icon);

    testWidgets('skipping forward jumps fifteen seconds', (tester) async {
      final playback = FakePlayback()
        ..emit(mediaId: 'm-audio-1', position: const Duration(seconds: 30));
      await _pump(tester, hero(playback));

      await tester.tap(skip(HugeIcons.strokeRoundedGoForward15Sec));
      await tester.pump();

      expect(playback.seeks, [const Duration(seconds: 45)]);
    });

    testWidgets('skipping back cannot go below zero', (tester) async {
      final playback = FakePlayback()
        ..emit(mediaId: 'm-audio-1', position: const Duration(seconds: 3));
      await _pump(tester, hero(playback));

      await tester.tap(skip(HugeIcons.strokeRoundedGoBackward15Sec));
      await tester.pump();

      expect(playback.seeks, [Duration.zero]);
    });

    testWidgets('skipping cannot run past the end', (tester) async {
      final playback = FakePlayback()
        ..emit(
          mediaId: 'm-audio-1',
          position: const Duration(minutes: 3, seconds: 55),
          duration: const Duration(minutes: 4),
        );
      await _pump(tester, hero(playback));

      await tester.tap(skip(HugeIcons.strokeRoundedGoForward15Sec));
      await tester.pump();

      expect(playback.seeks, [const Duration(minutes: 4)]);
    });

    testWidgets('the skip buttons are dead until something is loaded', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, hero(playback));

      await tester.tap(skip(HugeIcons.strokeRoundedGoForward15Sec));
      await tester.pump();

      expect(playback.seeks, isEmpty);
    });

    testWidgets('no playback url leaves the transport disabled', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, hero(playback, url: ''));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(playback.played, isEmpty);
    });

    testWidgets('the clock reads hours only when the track is that long', (
      tester,
    ) async {
      expect(formatClock(const Duration(seconds: 9)), '0:09');
      expect(formatClock(const Duration(minutes: 4, seconds: 32)), '4:32');
      expect(
        formatClock(const Duration(hours: 1, minutes: 4, seconds: 9)),
        '1:04:09',
      );
    });
  });
}
