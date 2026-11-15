import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/event_repo.dart';
import 'package:test_app/features/creator/repo/post_repo.dart';
import 'package:test_app/features/creator/views/new_article_screen.dart';
import 'package:test_app/features/creator/views/new_event_screen.dart';
import 'package:test_app/features/creator/views/studio_content_detail_screen.dart';
import 'package:test_app/models/creator_models/event_draft_models.dart';
import 'package:test_app/models/creator_models/post_draft_models.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// Editing on the phone what was only editable on the web.
///
/// Asked for on 2026-11-13: "We should be able to Edit contents on mobile
/// too. The API needs are in the integration guides."
///
/// The guides give update routes for **posts** and **calendar events**:
/// `PATCH /v1/content/posts/:id` and
/// `PATCH /v1/content/calendar/events/:id`. They give **none** for a media
/// row — video, audio and livestream have create, `publish` and the live
/// session routes and nothing else — so those keep the web studio rather
/// than getting a button that cannot work. An unauthenticated probe could
/// not settle it either way: the staging gateway answers 403 to every
/// path, including one that does not exist.
///
/// The regression these mostly guard: the editor shows a headline, a body
/// and a cover, but a post also has an excerpt, categories and a
/// visibility. A PATCH assembled from the form alone would send those back
/// empty and wipe them.
class _FakeApi implements ApiService {
  _FakeApi({this.getBody, this.error});

  Map<String, dynamic>? getBody;
  DioException? error;

  final List<String> gets = [];
  final List<String> patches = [];
  final Map<String, Map<String, dynamic>> sent = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    gets.add(path);
    if (error != null) throw error!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (getBody ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    patches.add(path);
    if (data is Map<String, dynamic>) sent[path] = data;
    if (error != null) throw error!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: const <String, dynamic>{} as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A filed article, as `GET /v1/content/posts/:id` answers.
const _postRow = {
  'data': {
    'id': 'p1',
    'title': 'Walking in Faith',
    'body': '# Faith\n\nWhen trials come…',
    'excerpt': 'A short reflection.',
    'categorySlugs': ['faith', 'encouragement'],
    'visibility': 'unlisted',
    'status': 'published',
    'coverThumbnailFileId': 'f1',
    'coverThumbnailKey': 'content/c1/covers/f1.jpg',
  },
};

/// A filed event, as `GET /v1/content/calendar/events/:id` answers. The
/// schedule really does come back twice.
const _eventRow = {
  'data': {
    'id': 'e1',
    'title': 'Sunday Worship',
    'description': 'Join us.',
    'categorySlugs': ['worship'],
    'venueType': 'hybrid',
    'visibility': 'public',
    'status': 'published',
    'schedule': {
      'startAt': '2026-06-14T09:00:00.000Z',
      'endAt': '2026-06-14T11:00:00.000Z',
      'timezone': 'America/New_York',
    },
    'startAt': '2026-06-14T09:00:00.000Z',
    'location': {
      'label': 'Main Sanctuary',
      'addressLine': '123 Faith Ave',
      'city': 'Atlanta',
      'meetingUrl': 'https://example.test/live',
    },
    'registration': {'required': true, 'capacity': 500},
    'coverImageFileId': 'f2',
    'coverImageKey': 'content/c1/covers/f2.jpg',
  },
};

StudioContentItem _item(
  StudioContentKind kind, {
  StudioContentState state = StudioContentState.published,
}) => StudioContentItem(id: 'x1', kind: kind, title: 'Something', state: state);

void main() {
  setUpAll(loadAppFonts);

  group('reading back what is filed', () {
    test('a post keeps the fields the editor does not show', () {
      final draft = PostDraft.fromJson(
        _postRow['data']! as Map<String, dynamic>,
      );

      expect(draft.title, 'Walking in Faith');
      expect(draft.excerpt, 'A short reflection.');
      expect(draft.categorySlugs, ['faith', 'encouragement']);
      expect(draft.visibility, 'unlisted');
      expect(draft.coverThumbnailFileId, 'f1');
    });

    test('an event reads the schedule that carries its timezone', () {
      // The row has `startAt` at the top level *and* inside `schedule`.
      // Only the nested one comes with the zone, so that is the pair read.
      final draft = EventDraft.fromJson(
        _eventRow['data']! as Map<String, dynamic>,
      );

      expect(draft.timezone, 'America/New_York');
      expect(draft.startAt.toUtc(), DateTime.utc(2026, 6, 14, 9));
      expect(draft.endAt?.toUtc(), DateTime.utc(2026, 6, 14, 11));
      expect(draft.venueType, EventVenueType.hybrid);
      expect(draft.location.city, 'Atlanta');
      expect(draft.rsvpRequired, isTrue);
      expect(draft.capacity, 500);
    });

    test('and a venue type this client has not heard of costs nothing', () {
      // Throwing here would cost the creator their whole edit over a value
      // added to the API after this build.
      final draft = EventDraft.fromJson(const {
        'title': 'x',
        'venueType': 'teleport',
        'schedule': {'startAt': '2026-06-14T09:00:00.000Z', 'timezone': 'UTC'},
      });

      expect(draft.venueType, EventVenueType.physical);
    });
  });

  group('what a PATCH sends', () {
    test('a cleared field is sent empty, not left out', () {
      // Left out, the API keeps the old value — so a creator who deleted
      // their excerpt would watch it come back.
      const draft = PostDraft(title: 'T', body: 'B');
      final json = draft.toPatchJson();

      expect(json['excerpt'], '');
      expect(json.containsKey('excerpt'), isTrue);
    });

    test('and no creatorId or scheduledAt rides along', () {
      // Ownership comes from the path, and rescheduling a post someone
      // only meant to fix a typo in would be a surprise.
      final json = const PostDraft(title: 'T').toPatchJson();

      expect(json.containsKey('creatorId'), isFalse);
      expect(json.containsKey('scheduledAt'), isFalse);
    });

    test('an event always states its registration', () {
      // Turning RSVP off has to be a change the API can see; an absent key
      // is indistinguishable from "unchanged".
      final json = EventDraft(
        title: 'T',
        venueType: EventVenueType.virtual,
        startAt: DateTime.utc(2026, 6, 14, 9),
        timezone: 'UTC',
      ).toPatchJson();

      expect((json['registration'] as Map)['required'], isFalse);
    });

    test('but an empty meeting link is left out, not sent blank', () {
      // The one field here likely to be format-validated. `@IsOptional()`
      // skips null, not '', so a blank would risk "must be a URL" on every
      // physical event's edit — a worse failure than not being able to
      // empty a link from the phone.
      final json = EventDraft(
        title: 'T',
        venueType: EventVenueType.physical,
        startAt: DateTime.utc(2026, 6, 14, 9),
        timezone: 'UTC',
        location: const EventLocation(label: 'Hall', city: 'Lagos'),
      ).toPatchJson();
      final location = json['location'] as Map;

      expect(location.containsKey('meetingUrl'), isFalse);
      // The plain text fields still clear, which is the point of the rest.
      expect(location['addressLine'], '');
    });

    test('and never sends the stream a broadcast attached to it', () {
      final json = EventDraft(
        title: 'T',
        venueType: EventVenueType.virtual,
        startAt: DateTime.utc(2026, 6, 14, 9),
        timezone: 'UTC',
      ).toPatchJson();

      expect(json.containsKey('streamId'), isFalse);
    });
  });

  group('the repos', () {
    test('a post is read from, and written back to, its own route', () async {
      final api = _FakeApi(getBody: _postRow);
      final repo = PostRepo(api);

      final filed = await repo.load('p1');
      expect(api.gets, ['/v1/content/posts/p1']);
      expect(filed.coverKey, 'content/c1/covers/f1.jpg');
      expect(filed.isPublished, isTrue);

      await repo.update(postId: 'p1', draft: filed.draft);
      expect(api.patches, ['/v1/content/posts/p1']);
      expect(api.sent['/v1/content/posts/p1']!['title'], 'Walking in Faith');
    });

    test('and so is an event', () async {
      final api = _FakeApi(getBody: _eventRow);
      final repo = EventRepo(api);

      final filed = await repo.load('e1');
      expect(api.gets, ['/v1/content/calendar/events/e1']);
      expect(filed.coverKey, 'content/c1/covers/f2.jpg');

      await repo.update(eventId: 'e1', draft: filed.draft);
      expect(api.patches, ['/v1/content/calendar/events/e1']);
      final sent = api.sent['/v1/content/calendar/events/e1']!;
      expect((sent['schedule'] as Map)['timezone'], 'America/New_York');
      expect(sent['venueType'], 'hybrid');
    });
  });

  group('the article editor', () {
    Future<_FakeApi> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final api = _FakeApi(getBody: _postRow);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            home: NewArticleScreen(
              creatorId: 'c1',
              posts: PostRepo(api),
              editPostId: 'p1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('opens what is already filed', (tester) async {
      await pump(tester);

      expect(find.text(AppStrings.editArticleTitle), findsOneWidget);
      expect(find.text('Walking in Faith'), findsOneWidget);
    });

    testWidgets('offers Save changes, not Publish or Save draft', (
      tester,
    ) async {
      // Correcting a typo must not be able to publish a draft by accident,
      // or reschedule a post that is already out.
      await pump(tester);

      expect(find.byKey(const ValueKey('article-save-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('article-publish')), findsNothing);
      expect(find.byKey(const ValueKey('article-draft')), findsNothing);
    });

    testWidgets('and keeps the markdown tools it writes with', (tester) async {
      // Editing is writing. A footer that swapped the toolbar out for a
      // Save button left a creator correcting an article with no bold, no
      // link and no way to add a picture.
      await pump(tester);

      expect(find.byKey(const ValueKey('article-tool-bold')), findsOneWidget);
      expect(find.byKey(const ValueKey('article-tool-link')), findsOneWidget);
      expect(find.byKey(const ValueKey('article-tool-image')), findsOneWidget);
    });

    testWidgets('and saving carries back the fields it never showed', (
      tester,
    ) async {
      // The whole point: the editor shows a headline, a body and a cover.
      // A PATCH built from those alone would clear the excerpt, the
      // categories and the visibility the creator set on the web.
      final api = await pump(tester);

      await tester.tap(find.byKey(const ValueKey('article-save-edit')));
      await tester.pumpAndSettle();

      final sent = api.sent['/v1/content/posts/p1']!;
      expect(sent['excerpt'], 'A short reflection.');
      expect(sent['categorySlugs'], ['faith', 'encouragement']);
      expect(sent['visibility'], 'unlisted');
    });

    testWidgets('an article that cannot be opened says so and offers again', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final api = _FakeApi(
        error: DioException(
          requestOptions: RequestOptions(path: '/v1/content/posts/p1'),
          type: DioExceptionType.connectionError,
        ),
      );
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            home: NewArticleScreen(
              creatorId: 'c1',
              posts: PostRepo(api),
              editPostId: 'p1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.editCouldNotOpen), findsOneWidget);
      expect(find.byKey(const ValueKey('article-open-retry')), findsOneWidget);
      // Nothing may be written from a form that was never filled in.
      expect(api.patches, isEmpty);
    });
  });

  group('the event editor', () {
    testWidgets('opens what is filed and offers Save changes', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 2200 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final api = _FakeApi(getBody: _eventRow);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            home: NewEventScreen(
              creatorId: 'c1',
              events: EventRepo(api),
              editEventId: 'e1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.editEventTitle), findsOneWidget);
      expect(find.text('Sunday Worship'), findsOneWidget);
      expect(find.byKey(const ValueKey('event-save-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-publish')), findsNothing);
    });
  });

  group('what an edit must not quietly change', () {
    testWidgets('an event keeps the time it actually ends at', (tester) async {
      // The form collects an end *date* only, so a new event ends at
      // whatever time it starts. Rebuilding an existing one that way
      // turned a 9-to-11 service into one ending at 9.
      tester.view.physicalSize = const Size(390 * 3, 2200 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final api = _FakeApi(getBody: _eventRow);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            home: NewEventScreen(
              creatorId: 'c1',
              events: EventRepo(api),
              editEventId: 'e1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('event-save-edit')));
      await tester.pumpAndSettle();

      final schedule =
          api.sent['/v1/content/calendar/events/e1']!['schedule'] as Map;
      expect(
        DateTime.parse(schedule['endAt'] as String).toUtc(),
        DateTime.utc(2026, 6, 14, 11),
        reason: 'it ended at 11:00 and must still end at 11:00',
      );
      expect(
        DateTime.parse(schedule['startAt'] as String).toUtc(),
        DateTime.utc(2026, 6, 14, 9),
      );
    });
  });

  group('which kinds offer it', () {
    Future<void> pump(
      WidgetTester tester,
      StudioContentKind kind, {
      StudioContentState state = StudioContentState.published,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (_) => MaterialApp(
            home: StudioContentDetailScreen(item: _item(kind, state: state)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a post offers Edit', (tester) async {
      await pump(tester, StudioContentKind.post);

      expect(find.byKey(const ValueKey('detail-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-manage-web')), findsNothing);
    });

    testWidgets('and is not told its title is edited somewhere else', (
      tester,
    ) async {
      // The footer said "title, description, visibility and series are
      // edited on the web studio" under every kind. On the screen that now
      // edits a post's title, that sends a creator to a desktop for work
      // they can do here.
      await pump(tester, StudioContentKind.post);

      expect(find.text(AppStrings.contentMediaEditWeb), findsNothing);
      expect(find.text(AppStrings.contentPostEditNote), findsOneWidget);
    });

    testWidgets('an event offers Edit', (tester) async {
      await pump(tester, StudioContentKind.event);

      expect(find.byKey(const ValueKey('detail-edit')), findsOneWidget);
    });

    testWidgets('a video offers Edit, now that there is a route', (
      tester,
    ) async {
      // This test used to assert the opposite, and said why: the media
      // guide published create, publish and the live session routes and no
      // update, so a button here would have been one that fails. The
      // guide's 2026-11-14 revision added `PATCH /v1/media/{id}`.
      await pump(tester, StudioContentKind.video);

      expect(find.byKey(const ValueKey('detail-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-manage-web')), findsNothing);
      // And it is told what the phone covers, not sent to a desktop.
      expect(find.text(AppStrings.contentMediaEditNote), findsOneWidget);
      expect(find.text(AppStrings.contentMediaEditWeb), findsNothing);
    });

    testWidgets('so does audio', (tester) async {
      await pump(tester, StudioContentKind.audio);

      expect(find.byKey(const ValueKey('detail-edit')), findsOneWidget);
      expect(find.text(AppStrings.contentMediaEditNote), findsOneWidget);
    });

    testWidgets('a livestream still does not', (tester) async {
      // A broadcast is not an upload. It is configured through
      // `PATCH /v1/media/live/streams/{id}` — a different route with a
      // different shape — and nothing here writes it.
      await pump(tester, StudioContentKind.livestream);

      expect(find.byKey(const ValueKey('detail-edit')), findsNothing);
      expect(find.byKey(const ValueKey('detail-manage-web')), findsOneWidget);
      expect(find.text(AppStrings.contentMediaEditWeb), findsOneWidget);
    });

    testWidgets('nor does a row nobody may change', (tester) async {
      for (final state in [
        StudioContentState.archived,
        StudioContentState.blocked,
        StudioContentState.inReview,
      ]) {
        await pump(tester, StudioContentKind.video, state: state);

        expect(
          find.byKey(const ValueKey('detail-edit')),
          findsNothing,
          reason: '$state is not the creator\'s to edit',
        );
        expect(find.text(AppStrings.editMediaNotEditable), findsOneWidget);
      }
    });
  });
}
