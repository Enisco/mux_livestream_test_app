import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/studio_content_parts.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// A media row exactly as staging returns one.
Map<String, dynamic> _media({
  String type = 'video',
  String status = 'published',
  String visibility = 'public',
  int views = 0,
  int? duration,
  bool live = false,
  String? publishedAt,
  String? updatedAt,
  String? endedAt,
  String? scheduledAt,
  String? sourceLivestreamMediaId,
}) => {
  'id': 'm1',
  'type': type,
  'title': 'The Prodigal Returns',
  'status': status,
  'visibility': visibility,
  'isLiveNow': live,
  'durationSeconds': duration,
  'analyticsViews': views,
  'engagementLikeCount': 36,
  'engagementCommentCount': 12,
  'publishedAt': publishedAt,
  'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
  'endedAt': endedAt,
  'scheduledAt': scheduledAt,
  'sourceLivestreamMediaId': sourceLivestreamMediaId,
};

Future<void> _pumpRow(WidgetTester tester, StudioContentItem item) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: StudioContentRow(item: item, onTap: () {}, onAction: () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('parsing what the three services return', () {
    test('music is the API word for the Audio chip', () {
      final item = StudioContentItem.fromMedia(_media(type: 'music'));
      expect(item.kind, StudioContentKind.audio);
    });

    test('a live row outranks whatever its status says', () {
      final item = StudioContentItem.fromMedia(
        _media(status: 'published', live: true),
      );
      expect(item.state, StudioContentState.live);
    });

    group('a livestream is not a video', () {
      test('it parses as its own kind', () {
        final item = StudioContentItem.fromMedia(_media(type: 'livestream'));
        expect(item.kind, StudioContentKind.livestream);
        expect(item.isLivestream, isTrue);
        // The API creates these through provision/sessions, never
        // POST /v1/media, and the studio must not conflate the two.
        expect(item.kind, isNot(StudioContentKind.video));
      });

      test('it rides the Videos chip, which asks for both types', () {
        expect(StudioContentKind.livestream.chip, StudioContentKind.video.chip);
        expect(StudioContentKind.video.mediaTypes, ['video', 'livestream']);
        expect(StudioContentKind.audio.mediaTypes, ['music']);
        // Drawing `values` would repeat Videos.
        expect(StudioContentKind.chips, hasLength(4));
      });

      test('a finished broadcast has ended; it is not the replay', () {
        // Ending a stream leaves two rows. This is the session.
        final session = StudioContentItem.fromMedia(
          _media(
            type: 'livestream',
            status: 'published',
            endedAt: '2026-09-14T11:20:00.000Z',
          ),
        );
        expect(session.state, StudioContentState.ended);
        expect(session.isReplay, isFalse);
      });

      test('the replay is the video archive pointing back at the session', () {
        // And this is the archive the backend publishes alongside it.
        final replay = StudioContentItem.fromMedia(
          _media(
            status: 'published',
            endedAt: '2026-09-14T11:20:00.000Z',
            sourceLivestreamMediaId: 'ls1',
          ),
        );
        expect(replay.kind, StudioContentKind.video);
        expect(replay.state, StudioContentState.replay);
        expect(replay.isReplay, isTrue);
      });

      test('one still to come is scheduled, not published', () {
        final item = StudioContentItem.fromMedia(
          _media(
            type: 'livestream',
            // An unscheduled session sits at `ready`, which would otherwise
            // read as published.
            status: 'ready',
            scheduledAt: DateTime.now()
                .add(const Duration(days: 3))
                .toIso8601String(),
          ),
        );
        expect(item.state, StudioContentState.scheduled);
      });

      test('airing now outranks everything', () {
        final item = StudioContentItem.fromMedia(
          _media(
            type: 'livestream',
            status: 'ready',
            live: true,
            endedAt: '2026-09-14T11:20:00.000Z',
          ),
        );
        expect(item.state, StudioContentState.live);
      });

      testWidgets('the replay row says Replay and who can see it', (
        tester,
      ) async {
        await _pumpRow(
          tester,
          StudioContentItem.fromMedia(
            _media(
              status: 'published',
              visibility: 'unlisted',
              views: 2140,
              endedAt: '2026-09-14T11:20:00.000Z',
              sourceLivestreamMediaId: 'ls1',
            ),
          ),
        );

        expect(find.textContaining(AppStrings.contentReplay), findsOneWidget);
        expect(find.textContaining(AppStrings.contentUnlisted), findsOneWidget);
      });

      testWidgets('an airing stream counts who is watching live', (
        tester,
      ) async {
        await _pumpRow(
          tester,
          StudioContentItem.fromMedia(
            _media(type: 'livestream', status: 'published', live: true),
          ),
        );

        expect(find.textContaining(AppStrings.contentLiveNow), findsOneWidget);
      });
    });

    test('an unknown status degrades rather than throwing', () {
      final item = StudioContentItem.fromMedia(_media(status: 'quarantined'));
      expect(item.state, StudioContentState.other);
    });

    test('every status the three services return has a state', () {
      // The search filter's own refusal spells each enum out.
      const media = [
        'archived',
        'blocked',
        'draft',
        'failed',
        'processing',
        'published',
        'ready',
        'scheduled',
        'under_review',
      ];
      const posts = ['archived', 'draft', 'published', 'scheduled'];
      const events = ['draft', 'published', 'cancelled', 'completed'];

      for (final status in {...media, ...posts, ...events}) {
        expect(
          StudioContentItem.fromMedia(_media(status: status)).state,
          isNot(StudioContentState.other),
          reason: status,
        );
      }
    });

    testWidgets('a failed upload says so rather than reading as published', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        StudioContentItem.fromMedia(
          _media(status: 'failed', visibility: 'public', views: 0),
        ),
      );

      expect(find.textContaining(AppStrings.contentFailed), findsOneWidget);
      expect(find.textContaining(AppStrings.contentPublic), findsNothing);
    });

    test('a video that has finished transcoding is not yet published', () {
      // `ready` means Mux is done, not that anyone can see it — only
      // POST /v1/media/{id}/publish does that.
      expect(
        StudioContentItem.fromMedia(_media(status: 'ready')).state,
        StudioContentState.draft,
      );
    });

    test('a post counts reads and an event counts RSVPs', () {
      final post = StudioContentItem.fromPost({
        'id': 'p1',
        'title': 'Why We Fast',
        'status': 'draft',
        'analyticsViews': 1204,
      });
      expect(post.kind, StudioContentKind.post);
      expect(post.views, 1204);
      expect(post.isDraft, isTrue);

      final event = StudioContentItem.fromEvent({
        'id': 'e1',
        'title': 'Midweek Prayer Vigil',
        'status': 'published',
        'attendingCount': 58,
        'startAt': '2026-06-10T18:30:00.000Z',
        'location': {'label': 'Grace Chapel'},
      });
      expect(event.kind, StudioContentKind.event);
      expect(event.goingCount, 58);
      expect(event.startsAt?.day, 10);
    });

    test('rows sort by whatever happened to them last', () {
      final older = StudioContentItem.fromMedia(
        _media(publishedAt: '2026-01-01T00:00:00.000Z'),
      );
      final newer = StudioContentItem.fromMedia(
        _media(publishedAt: '2026-06-01T00:00:00.000Z'),
      );
      final list = [older, newer]..sort((a, b) => b.sortAt.compareTo(a.sortAt));
      expect(list.first.sortAt, newer.sortAt);
    });
  });

  group('the row', () {
    testWidgets('a published video says who can see it and how it did', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        StudioContentItem.fromMedia(
          _media(views: 5180, publishedAt: '2026-09-16T00:00:00.000Z'),
        ),
      );

      expect(find.textContaining(AppStrings.contentPublic), findsOneWidget);
      expect(find.textContaining('5.2K views'), findsOneWidget);
    });

    testWidgets('a processing row offers nothing to share', (tester) async {
      await _pumpRow(
        tester,
        StudioContentItem.fromMedia(_media(status: 'processing')),
      );

      expect(find.textContaining(AppStrings.contentProcessing), findsOneWidget);
      expect(find.byKey(const ValueKey('content-action-m1')), findsNothing);
    });

    testWidgets('a draft offers edit, not share', (tester) async {
      await _pumpRow(
        tester,
        StudioContentItem.fromMedia(_media(status: 'draft')),
      );

      expect(find.byKey(const ValueKey('content-action-m1')), findsOneWidget);
      expect(find.textContaining(AppStrings.contentDraft), findsOneWidget);
      // Visibility belongs to something published; a draft has none to name.
      expect(find.textContaining(AppStrings.contentPublic), findsNothing);
    });

    testWidgets('a duration is shown as clock time', (tester) async {
      await _pumpRow(
        tester,
        StudioContentItem.fromMedia(_media(duration: 2538)),
      );

      expect(find.text('42:18'), findsOneWidget);
    });

    testWidgets('an event leads with its date, not a thumbnail', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        StudioContentItem.fromEvent({
          'id': 'e1',
          'title': 'Midweek Prayer Vigil',
          'status': 'published',
          'visibility': 'public',
          'attendingCount': 58,
          'startAt': '2026-06-10T18:30:00.000Z',
        }),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.text('JUN'), findsOneWidget);
      expect(find.textContaining('58 going'), findsOneWidget);
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: StudioContentRow(
                item: StudioContentItem.fromMedia(
                  _media(views: 5180, duration: 2538),
                ),
                onTap: () {},
                onAction: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the chips', () {
    testWidgets('All plus one per kind, with All lit by default', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      StudioContentKind? picked;
      var calls = 0;
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(
            home: Scaffold(
              body: StudioContentChips(
                selected: null,
                onSelected: (k) {
                  picked = k;
                  calls++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.contentChipAll), findsOneWidget);
      for (final kind in StudioContentKind.chips) {
        expect(find.text(kind.chip), findsOneWidget, reason: kind.chip);
      }

      await tester.tap(find.text(StudioContentKind.event.chip));
      await tester.pump();
      expect(picked, StudioContentKind.event);
      expect(calls, 1);
    });
  });
}
