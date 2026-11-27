import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/features/discovery/views/widgets/portrait_watch_view.dart';
import 'package:test_app/features/discovery/views/widgets/watch_rail.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/video_fit.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

import 'support/fake_playback.dart';

const _mediaId = 'media-1';

const _target = PlaybackTarget(
  mediaId: _mediaId,
  creatorId: 'creator-1',
  mediaType: 'video',
  source: 'home_feed',
);

void main() {
  // The detector otherwise leaves a 500ms timer pending at the end of every
  // widget test here.
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  group('which surface a video is watched on', () {
    test('upright gets the screen, square and wider keep the page', () {
      // The shapes a phone actually produces, and the line between them.
      // 1:1 and 5:4 read as "about square" and still work in a page with a
      // title and comments under the picture; below that the picture stops
      // being something a page can hold.
      const cases = {
        (1080, 1920): VideoShape.portrait, // held upright, the common one
        (1080, 1350): VideoShape.portrait, // 4:5
        (720, 960): VideoShape.portrait, // 3:4
        (1080, 1080): VideoShape.standard, // square
        (1280, 1024): VideoShape.standard, // 5:4
        (640, 480): VideoShape.standard, // 4:3
        (1920, 1080): VideoShape.standard, // the ordinary one
        (2048, 858): VideoShape.standard, // a cinema cut
      };
      cases.forEach((size, want) {
        expect(
          VideoFit.shapeOf(width: size.$1, height: size.$2),
          want,
          reason: '${size.$1}x${size.$2}',
        );
      });
    });

    test('and nothing is decided before the decoder has said', () {
      // Every surface has to draw before the picture's size is known, and
      // guessing portrait would restructure the screen under a reader for
      // a video that turns out to be ordinary.
      for (final size in [(0, 0), (1920, 0), (0, 1080), (-1, 10)]) {
        expect(
          VideoFit.shapeOf(width: size.$1, height: size.$2),
          VideoShape.unknown,
          reason: '${size.$1}x${size.$2}',
        );
      }
    });
  });

  group('the frame a standard video sits in', () {
    test('takes the video own shape, so nothing is cropped or padded', () {
      expect(VideoFit.frameAspect(width: 1920, height: 1080), 16 / 9);
      expect(VideoFit.frameAspect(width: 640, height: 480), 4 / 3);
      expect(VideoFit.frameAspect(width: 1280, height: 1024), 1.25);
    });

    test('but never narrower than square, which the page cannot hold', () {
      // A portrait video should never reach the framed layout at all. If one
      // does, a square frame is a graceful floor rather than a sliver.
      expect(VideoFit.frameAspect(width: 1080, height: 1920), 1.0);
    });

    test('and never wider than the frame the page was drawn for', () {
      // A 2.35:1 cut is letterboxed inside a familiar frame rather than
      // squeezing the whole page into a letterbox of its own.
      expect(VideoFit.frameAspect(width: 2048, height: 858), 16 / 9);
    });

    test('falling back to the shared shape until the size is known', () {
      expect(
        VideoFit.frameAspect(width: 0, height: 0),
        VideoFit.landscapeAspect,
      );
    });
  });

  group('the rail carries everything the page offers', () {
    Future<void> pump(
      WidgetTester tester, {
      required FakePlayback playback,
      required Map<String, int> taps,
      bool canGive = true,
    }) async {
      // A real phone. The default test window is 800x600, shorter than any
      // handset the app runs on, and the rail is built for the screen it
      // actually gets.
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: playback,
            target: _target,
            title: 'A sermon',
            creatorName: 'Grace Chapel',
            creatorHandle: 'gracechapel',
            hasCreator: true,
            canGive: canGive,
            likes: '12',
            saves: '3',
            comments: '4',
            onLike: () => taps['like'] = (taps['like'] ?? 0) + 1,
            onSave: () => taps['save'] = (taps['save'] ?? 0) + 1,
            onShare: () => taps['share'] = (taps['share'] ?? 0) + 1,
            onGive: () => taps['give'] = (taps['give'] ?? 0) + 1,
            onComments: () async {
              taps['comments'] = (taps['comments'] ?? 0) + 1;
            },
            onFollow: () => taps['follow'] = (taps['follow'] ?? 0) + 1,
            onCreator: () => taps['creator'] = (taps['creator'] ?? 0) + 1,
            onBack: () => taps['back'] = (taps['back'] ?? 0) + 1,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('every action on the standard row is reachable', (
      tester,
    ) async {
      final playback = FakePlayback();
      final taps = <String, int>{};
      await pump(tester, playback: playback, taps: taps);

      // The counts the rail shows are the page's counts.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text(AppStrings.share), findsOneWidget);
      expect(find.text(AppStrings.give), findsOneWidget);

      for (final label in ['12', '3', '4', AppStrings.share, AppStrings.give]) {
        await tester.tap(find.text(label));
        await tester.pump();
      }

      expect(taps['like'], 1);
      expect(taps['save'], 1);
      expect(taps['comments'], 1);
      expect(taps['share'], 1);
      expect(taps['give'], 1, reason: 'giving must not be lost here');
    });

    testWidgets('and the ministry can be opened and followed', (tester) async {
      final playback = FakePlayback();
      final taps = <String, int>{};
      await pump(tester, playback: playback, taps: taps);

      // The avatar opens the ministry; the badge on it follows. See
      // creator-profile-entry-points: every avatar goes to the profile.
      await tester.tap(find.text('G'));
      await tester.pump();
      expect(taps['creator'], 1);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(taps['follow'], 1);
    });

    testWidgets('give is absent when the ministry cannot take one', (
      tester,
    ) async {
      final playback = FakePlayback();
      await pump(tester, playback: playback, taps: {}, canGive: false);
      expect(find.text(AppStrings.give), findsNothing);
    });

    testWidgets('sound is the rail own control, not the creator mute', (
      tester,
    ) async {
      // `cardMute`/`cardUnmute` mute a *ministry* in the overflow sheet.
      // The same word on a rail would read as silencing the creator.
      final playback = FakePlayback();
      await pump(tester, playback: playback, taps: {});

      // Mute starts on, app-wide — a feed autoplays silent — so the rail
      // opens offering to turn the sound on.
      expect(playback.muted.value, isTrue);
      expect(find.text(AppStrings.watchUnmute), findsOneWidget);

      await tester.tap(find.text(AppStrings.watchUnmute));
      await tester.pump();

      expect(playback.muted.value, isFalse);
      expect(find.text(AppStrings.watchSound), findsOneWidget);
    });
  });

  group('the rail on a screen that cannot hold all of it', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
            creatorName: 'Grace Chapel',
            creatorHandle: 'grace',
            hasCreator: true,
            canGive: true,
            likes: '12.3K',
            saves: '482',
            comments: '1.1K',
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('keeps clear of the top bar instead of being clipped by it', (
      tester,
    ) async {
      // A `Positioned` with no top bound hands the column every pixel it
      // asks for and lets the stack clip the overflow — and the overflow is
      // the top of the column, which is the ministry and its follow badge.
      await pumpAt(tester, const Size(360, 600));

      final settings = tester.getRect(find.byIcon(Icons.settings_rounded));
      final rail = tester.getRect(find.byType(SingleChildScrollView).first);
      expect(
        rail.top,
        greaterThanOrEqualTo(settings.bottom),
        reason: 'the rail must start below the back arrow and settings',
      );
    });

    testWidgets('and the ministry is still reachable by scrolling it', (
      tester,
    ) async {
      await pumpAt(tester, const Size(360, 600));

      // Anchored at the bottom, so sound — the one a thumb reaches for — is
      // what stays put, and the ministry is what moves out of view.
      expect(find.text(AppStrings.watchUnmute), findsOneWidget);

      await tester.drag(find.text(AppStrings.give), const Offset(0, 120));
      await tester.pump();

      expect(
        tester.getRect(find.text('G')).top,
        greaterThanOrEqualTo(0.0),
        reason: 'the avatar should come into view when the rail is scrolled',
      );
    });

    testWidgets('while an ordinary phone never scrolls it at all', (
      tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));

      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(SingleChildScrollView).first,
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      expect(
        position.maxScrollExtent,
        0.0,
        reason: 'the whole rail fits, so there is nothing to scroll',
      );
    });
  });

  group('a livestream, which is the same surface with less of it', () {
    Future<void> pumpLive(WidgetTester tester, {required bool isLive}) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final playback = FakePlayback();
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: playback,
            target: _target,
            title: 'Sunday service',
            creatorName: 'Grace Chapel',
            hasCreator: true,
            isLive: isLive,
          ),
        ),
      );
      playback.emit(
        mediaId: _mediaId,
        kind: PlaybackKind.video,
        position: const Duration(seconds: 30),
        // A live edge reports a duration; a replay reports its own.
        duration: const Duration(minutes: 90),
        videoWidth: 1080,
        videoHeight: 1920,
      );
      await tester.pump();
    }

    testWidgets('broadcasting now has no scrubber to drag', (tester) async {
      // There is nowhere to seek to on a live edge, and a track under the
      // thumb that cannot move is worse than no track.
      await pumpLive(tester, isLive: true);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('but a replay is an ordinary video and gets one', (
      tester,
    ) async {
      // A finished broadcast is just a video with a different flag on it.
      await pumpLive(tester, isLive: false);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('and the rail is the same either way', (tester) async {
      // Liking, commenting, sharing and giving all apply to a broadcast as
      // much as to an upload — losing them while live would be the worst
      // time to lose them.
      await pumpLive(tester, isLive: true);
      expect(find.byType(WatchRailAction), findsWidgets);
      expect(find.text(AppStrings.share), findsOneWidget);
      expect(find.text(AppStrings.watchUnmute), findsOneWidget);
    });
  });

  group('the controls while the page is being pulled up', () {
    testWidgets('stop taking taps at the moment they stop being visible', (
      tester,
    ) async {
      // They fade faster than the sheet rises. If pointers kept going to
      // the top of the travel, a reader dragging the page past halfway
      // would be tapping a rail that is no longer on screen.
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
            page: (context) => const Column(children: [Text('x')]),
          ),
        ),
      );
      await tester.pump();

      final chrome = find.byType(IgnorePointer);
      expect(chrome, findsWidgets);

      // Every IgnorePointer wrapping the chrome must switch on the same
      // number the opacity does, so there is never an invisible target.
      final source = File(
        'lib/features/discovery/views/widgets/portrait_watch_view.dart',
      ).readAsStringSync();
      expect(source, contains('ignoring: opacity <= 0'));
      expect(source, isNot(contains('ignoring: hidden')));
    });

    testWidgets('and back puts the page down before it leaves', (tester) async {
      final source = File(
        'lib/features/discovery/views/widgets/portrait_watch_view.dart',
      ).readAsStringSync();
      expect(source, contains('canPop: _sheetOpen < 0.02'));
      expect(source, contains('if (!didPop) _shutSheet();'));
    });
  });

  group('handing the video between the two surfaces', () {
    test('the detail screen will not swap while fullscreen is up', () {
      // The hero pauses what it was playing when it is torn down, so
      // swapping under the fullscreen route would stop the video the reader
      // is watching in it.
      final source = File(
        'lib/features/discovery/views/media_detail_screen.dart',
      ).readAsStringSync();
      expect(source, contains('if (_playback.fullscreen.value) return;'));
    });

    test(
      'and the upright view holds its playback the same way the hero does',
      () {
        // Covered by a route means stop; covered by the fullscreen route means
        // carry on, because that is still this video being watched.
        final source = File(
          'lib/features/discovery/views/widgets/portrait_watch_view.dart',
        ).readAsStringSync();
        expect(
          source,
          contains('if (widget.playback.fullscreen.value) return;'),
        );
        expect(source, contains('widget.playback.pauseIfActive(_mediaId);'));
      },
    );
  });

  group('the page under the video', () {
    testWidgets('opens when the handle itself is dragged', (tester) async {
      // The handle is the only thing on screen when the sheet is shut, so
      // it has to be what moves it. A `DraggableScrollableSheet` is driven
      // by the scrollable holding its controller and by nothing else — a
      // handle sitting *beside* that scrollable looks exactly like a handle
      // and does nothing, and the page underneath is zero pixels tall when
      // shut, so there is nothing else left to grab either.
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
            page: (context) => const Column(
              children: [SizedBox(height: 900, child: Text('Up next'))],
            ),
          ),
        ),
      );
      await tester.pump();

      // Shut: the page is there but has no room to show.
      expect(
        tester.getRect(find.text(AppStrings.watchMore)).top,
        greaterThan(700),
      );

      await tester.drag(find.text(AppStrings.watchMore), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Up to the cap and no further: the picture keeps the rest of the
      // screen and shrinks into it, rather than being covered to a
      // sliver nobody can make anything of.
      const ceiling = 844 * (1 - PortraitWatchView.sheetMax);
      final handleTop = tester.getRect(find.text(AppStrings.watchMore)).top;
      expect(
        handleTop,
        greaterThan(ceiling - 1),
        reason: 'the sheet went past the cap and swallowed the video',
      );
      expect(
        handleTop,
        lessThan(ceiling + 80),
        reason: 'dragging the handle should have brought the sheet up',
      );
      expect(find.text('Up next'), findsOneWidget);
    });

    testWidgets('and Save is the glyph the feed card uses', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
            saves: '1',
          ),
        ),
      );
      await tester.pump();

      // The rail drew an `archive` box, so saving a video looked like a
      // different action here than on the card that opened it.
      expect(
        tester
            .widgetList<DesignIcon>(find.byType(DesignIcon))
            .map((i) => i.asset),
        contains(AppAssets.iconFeedBookmark),
      );
    });

    testWidgets('and the picture shrinks into what the sheet leaves it', (
      tester,
    ) async {
      // TikTok's behaviour, and the point of capping the sheet: the video
      // scales down into the strip above the panel instead of sitting
      // full-bleed behind it with almost none of it visible.
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
            page: (context) => const Column(
              children: [SizedBox(height: 900, child: Text('Up next'))],
            ),
          ),
        ),
      );
      await tester.pump();

      double factor() => tester
          .widget<AnimatedFractionallySizedBox>(
            find.byType(AnimatedFractionallySizedBox),
          )
          .heightFactor!;

      // Shut, the picture still has the whole screen.
      expect(factor(), 1);

      await tester.drag(find.text(AppStrings.watchMore), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(factor(), closeTo(1 - PortraitWatchView.sheetMax, 0.02));
    });

    testWidgets('and shrinks for the comment thread too', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final opened = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
            comments: '2',
            onComments: () => opened.future,
          ),
        ),
      );
      await tester.pump();

      double factor() => tester
          .widget<AnimatedFractionallySizedBox>(
            find.byType(AnimatedFractionallySizedBox),
          )
          .heightFactor!;

      expect(factor(), 1);

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      expect(factor(), closeTo(1 - PortraitWatchView.sheetMax, 0.02));

      // And comes back when the thread is shut.
      opened.complete();
      await tester.pumpAndSettle();

      expect(factor(), 1);
    });

    testWidgets('and the controls over the video go with it', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
            creatorName: 'Grace Chapel',
            hasCreator: true,
            likes: '12',
            page: (context) => const Column(
              children: [SizedBox(height: 900, child: Text('Up next'))],
            ),
          ),
        ),
      );
      await tester.pump();

      final before = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(before.opacity, 1.0);

      await tester.drag(find.text(AppStrings.watchMore), const Offset(0, -600));
      await tester.pumpAndSettle();

      final after = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(after.opacity, 0.0, reason: 'the rail should be gone, not dimmed');
    });

    testWidgets('is offered in words, not just a handle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
            page: (context) => const Column(children: [Text('Up next')]),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.watchMore), findsOneWidget);
    });

    testWidgets('and is left out entirely when there is none', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PortraitWatchView(
            playback: FakePlayback(),
            target: _target,
            title: 'A sermon',
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.watchMore), findsNothing);
    });
  });

  group('the detail screen picks the surface', () {
    test('it locks the choice once, and never mid-watch', () {
      // Re-reading the shape would turn the layout over under a reader who
      // is already watching — the same fault as the rotating fullscreen box.
      final source = File(
        'lib/features/discovery/views/media_detail_screen.dart',
      ).readAsStringSync();

      expect(source, contains('if (_shape != VideoShape.unknown) return;'));
      expect(source, contains('VideoFit.shapeOf('));
      expect(
        source,
        contains('if (_shape == VideoShape.portrait) return _buildPortrait();'),
      );
    });

    test('and hands the upright view every action the page has', () {
      final source = File(
        'lib/features/discovery/views/media_detail_screen.dart',
      ).readAsStringSync();
      final portrait = source.substring(source.indexOf('_buildPortrait() {'));
      final view = portrait.substring(0, portrait.indexOf('\n  /// The hero'));

      for (final wiring in [
        'onLike: _toggleLike',
        'onSave: _toggleSave',
        'onFollow: _toggleFollow',
        'onShare:',
        'onGive:',
        'onComments:',
        'onBack:',
        'page:',
      ]) {
        expect(view, contains(wiring), reason: wiring);
      }
    });

    test('music never takes it, having no picture to be shaped by', () {
      final source = File(
        'lib/features/discovery/views/media_detail_screen.dart',
      ).readAsStringSync();
      expect(source, contains('if (_mediaType == MediaTypes.music) return;'));
    });
  });

  group('one rail, not two', () {
    test('the swipe feed and the upright view share it', () {
      // Two private copies is how the heart ends up in a different place
      // depending on which upright video you are on.
      for (final path in [
        'lib/features/discovery/views/vertical_feed_screen.dart',
        'lib/features/discovery/views/widgets/portrait_watch_view.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('WatchRailAction('), reason: path);
        expect(
          source,
          contains("widgets/watch_rail.dart'"),
          reason: '$path should import the shared rail',
        );
      }
    });

    test('and the old private copies are gone', () {
      final feed = File(
        'lib/features/discovery/views/vertical_feed_screen.dart',
      ).readAsStringSync();
      expect(feed, isNot(contains('class _FeedActionButton')));
      expect(feed, isNot(contains('class _AvatarButton')));
    });
  });
}
