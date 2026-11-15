// What a viewer sees when the video in front of them is going out live
// right now, rather than sitting finished on a CDN.
//
// Three surfaces carry live video and each had to learn the same two
// things: there is nothing to seek to, and the viewer should be told.
// The LIVE badge is one widget shared with the home feed's live card, so
// all four places are the same mark at different sizes.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/discovery/views/widgets/playback_settings_sheet.dart';
import 'package:test_app/features/discovery/views/widgets/video_hero.dart';
import 'package:test_app/features/player/views/widgets/controls_overlay.dart';
import 'package:test_app/features/player/views/widgets/seek_button.dart';
import 'package:test_app/features/player/views/widgets/speed_selector.dart';
import 'package:test_app/features/player/views/widgets/video_progress_bar.dart';
import 'package:test_app/shared/components/live_badge.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';
import 'support/fake_playback.dart';

const _url = 'https://cdn/live.m3u8';

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

VideoHero _hero(FakePlayback playback, {required bool isLive}) => VideoHero(
  playback: playback,
  target: const PlaybackTarget(mediaId: 'm-live-1', creatorId: 'c1'),
  playbackUrl: _url,
  isLive: isLive,
);

ControlsOverlay _overlay({required bool isLive}) => ControlsOverlay(
  title: 'Sunday Service',
  isLive: isLive,
  isPlaying: true,
  isCompleted: false,
  position: const Duration(minutes: 1),
  duration: const Duration(minutes: 2),
  volume: 1,
  playbackSpeed: 1,
  isFullscreen: false,
  speeds: const [1, 1.5, 2],
  qualities: const ['Auto', '720p'],
  currentQuality: 'Auto',
  onBack: () {},
  onPlayPause: () {},
  onSeekBack: () {},
  onSeekForward: () {},
  onSeek: (_) {},
  onVolumeChanged: (_) {},
  onSpeedChanged: (_) {},
  onQualityChanged: (_) {},
  onFullscreenToggle: () {},
);

void main() {
  setUpAll(() {
    loadAppFonts();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('the LIVE badge is one badge', () {
    test('the swipe feed keeps its own, and says why', () {
      // Not an oversight: a translucent outlined pill disappears over a
      // full-bleed video, so that surface draws a solid badge. What must
      // not happen is a *third* one appearing by accident, or the word
      // being hardcoded away from AppStrings.
      final feed = File(
        'lib/features/discovery/views/vertical_feed_screen.dart',
      ).readAsStringSync();

      expect(feed, contains('is **not** `LiveBadge`'));
      expect(feed, contains('AppStrings.liveBadge'));
      expect(feed, isNot(contains("'LIVE'")));
    });

    test('the feed card draws it rather than its own pill', () {
      // The card's private pill was deleted in favour of this widget. If
      // the card grows another one the four marks can drift apart again,
      // which is the whole reason the badge was extracted.
      final card = File(
        'lib/features/home/views/widgets/feed_card.dart',
      ).readAsStringSync();

      expect(card, contains('LiveBadge()'));
      expect(card, isNot(contains('_LivePill')));
    });

    testWidgets('it reads LIVE', (tester) async {
      await _pump(tester, const LiveBadge());
      expect(find.text(AppStrings.liveBadge), findsOneWidget);
    });

    testWidgets('the reading size is larger than the card size', (
      tester,
    ) async {
      // Beside a title it has to hold its own against 18pt type; on a
      // 176-wide card it has to stay a pill.
      expect(LiveBadge.readingFontSize, greaterThan(LiveBadge.cardFontSize));

      await _pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiveBadge(key: ValueKey('small')),
            LiveBadge(
              key: ValueKey('big'),
              fontSize: LiveBadge.readingFontSize,
            ),
          ],
        ),
      );

      final small = tester.getSize(find.byKey(const ValueKey('small')));
      final big = tester.getSize(find.byKey(const ValueKey('big')));
      // Padding, radius and border scale with the text, so the whole pill
      // grows rather than the glyphs bursting out of a fixed box.
      expect(big.width, greaterThan(small.width));
      expect(big.height, greaterThan(small.height));
    });
  });

  group('the detail title row', () {
    testWidgets('a live broadcast is marked beside its title', (tester) async {
      await _pump(
        tester,
        const DetailTitleBlock(title: 'Sunday Service', isLive: true),
      );

      expect(find.byType(LiveBadge), findsOneWidget);
      final badge = tester.getRect(find.byType(LiveBadge));
      final title = tester.getRect(find.text('Sunday Service'));
      // Before the title, on the same row — not above or below it.
      expect(badge.right, lessThanOrEqualTo(title.left));
      expect(badge.center.dy, closeTo(title.center.dy, 14));
    });

    testWidgets('a recording carries no badge', (tester) async {
      await _pump(
        tester,
        const DetailTitleBlock(title: 'Last Sunday', viewsLabel: '2K views'),
      );

      expect(find.byType(LiveBadge), findsNothing);
      expect(find.text('Last Sunday'), findsOneWidget);
    });
  });

  group('the detail hero', () {
    testWidgets('a live broadcast gets a badge and no scrubber', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback, isLive: true));
      await tester.pump();

      // Nothing to scrub to: the end of the track is the present moment.
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(LiveBadge), findsOneWidget);
      // The rest of the row is untouched.
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    });

    testWidgets('a recording keeps its scrubber and clock', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback, isLive: false));
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(LiveBadge), findsNothing);
    });

    testWidgets('fullscreen keeps the broadcast marked', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, _hero(playback, isLive: true));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(FullscreenVideo), findsOneWidget);
      expect(find.byType(LiveBadge), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });
  });

  group('the playback settings sheet', () {
    testWidgets('a live broadcast is offered no speed', (tester) async {
      final playback = FakePlayback()..qualities.value = const ['Auto', '720p'];
      await _pump(
        tester,
        PlaybackSettingsSheet(playback: playback, isLive: true),
      );

      expect(find.text(AppStrings.playbackSpeed), findsNothing);
      expect(find.byKey(const ValueKey('speed-1.5')), findsNothing);
      // Quality still applies — a live stream carries renditions too.
      expect(find.byKey(const ValueKey('quality-720p')), findsOneWidget);
    });

    testWidgets('a single-rendition broadcast says why it is empty', (
      tester,
    ) async {
      final playback = FakePlayback();
      await _pump(
        tester,
        PlaybackSettingsSheet(playback: playback, isLive: true),
      );

      expect(find.text(AppStrings.liveQualityAutomatic), findsOneWidget);
    });

    testWidgets('a recording still gets its speeds', (tester) async {
      final playback = FakePlayback();
      await _pump(tester, PlaybackSettingsSheet(playback: playback));

      expect(find.text(AppStrings.playbackSpeed), findsOneWidget);
      expect(find.byKey(const ValueKey('speed-1.5')), findsOneWidget);
      // A progressive file has nothing to say about quality.
      expect(find.text(AppStrings.liveQualityAutomatic), findsNothing);
    });
  });

  group('the legacy player overlay', () {
    testWidgets('a live broadcast loses the bar, the skips and the speed', (
      tester,
    ) async {
      await _pump(tester, _overlay(isLive: true));

      expect(find.byType(VideoProgressBar), findsNothing);
      expect(find.byType(SeekButton), findsNothing);
      expect(find.byType(SpeedSelector), findsNothing);
      // Marked in the title row, the same as the detail screen.
      expect(find.byType(LiveBadge), findsOneWidget);
      expect(find.text('Sunday Service'), findsOneWidget);
    });

    testWidgets('a recording keeps all of them', (tester) async {
      await _pump(tester, _overlay(isLive: false));

      expect(find.byType(VideoProgressBar), findsOneWidget);
      expect(find.byType(SeekButton), findsNWidgets(2));
      expect(find.byType(SpeedSelector), findsOneWidget);
      expect(find.byType(LiveBadge), findsNothing);
    });
  });

  group('seeking a live stream', () {
    // The player screen cannot be mounted here — media_kit needs libmpv —
    // so the gate is read off the source. It matters because the overlay
    // is only one of three ways to ask for a seek: a double-tap on either
    // half of the picture and the arrow keys go to the same two methods.
    final player = File(
      'lib/features/player/views/player_screen.dart',
    ).readAsStringSync();

    test('every seek is gated on the live flag', () {
      // Both of them: the offset seek and the fraction seek.
      const gate = 'if (_isLive || _duration == Duration.zero) return;';
      expect(gate.allMatches(player).length, 2);
      // And the gate is live-*now*, not live-when-opened: a broadcast that
      // has ended is a recording, and does have somewhere to seek to.
      expect(
        player,
        contains('bool get _isLive => widget.isLive && !_isCompleted;'),
      );
    });

    test('the overlay is told', () {
      expect(player, contains('isLive: _isLive,'));
    });

    test('the detail screen tells both the title row and the hero', () {
      // The flag is useless unless the screen that knows passes it on.
      // media_kit keeps this screen off the test harness as well.
      final detail = File(
        'lib/features/discovery/views/media_detail_screen.dart',
      ).readAsStringSync();

      expect(detail, contains('isLive: media.isLiveNow'));
      // `widget.item.isLiveNow`, not `facets.isLiveNow`: a feed row can
      // carry the flag under `meta` instead, and the model's own getter is
      // the only thing that reads both.
      expect(
        detail,
        contains('isLive: _detail?.media.isLiveNow ?? widget.item.isLiveNow'),
      );
    });

    test('both livestream screens open the player as live', () {
      for (final path in [
        'lib/features/livestream/views/join_livestream_screen.dart',
        'lib/features/livestream/views/start_livestream_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains('isLive: true'),
          reason: '$path opens a broadcast; the player has to know',
        );
      }
    });
  });
}
