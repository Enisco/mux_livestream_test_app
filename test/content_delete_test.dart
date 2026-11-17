import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/event_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/repo/post_repo.dart';
import 'package:test_app/features/creator/services/content_delete.dart';
import 'package:test_app/features/creator/views/studio_content_detail_screen.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// Records what was deleted, and refuses with whatever status is set.
class _FakeApi implements ApiService {
  _FakeApi({this.status});

  /// The HTTP status to refuse with, or null to succeed.
  final int? status;

  final List<String> deleted = [];

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    deleted.add(path);
    if (status == null) {
      return Response<T>(requestOptions: RequestOptions(path: path));
    }
    throw DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: status,
        data: const {'success': false, 'error': 'no'},
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

StudioContentItem _media({
  String type = 'video',
  String status = 'published',
  bool live = false,
}) => StudioContentItem.fromMedia({
  'id': 'm1',
  'type': type,
  'title': 'The Prodigal Returns',
  'status': status,
  'isLiveNow': live,
  'visibility': 'public',
  'publishedAt': '2026-06-06T00:00:00.000Z',
});

StudioContentItem _post() => StudioContentItem.fromPost({
  'id': 'p1',
  'title': 'On waiting',
  'status': 'published',
});

StudioContentItem _event() => StudioContentItem.fromEvent({
  'id': 'e1',
  'title': 'Night of worship',
  'status': 'published',
});

/// The outcomes the screen was handed, and what it did about them.
Future<List<StudioContentItem>> _pump(
  WidgetTester tester,
  StudioContentItem item, {
  ContentDeleteOutcome outcome = ContentDeleteOutcome.done,
  List<bool>? popped,
}) async {
  final asked = <StudioContentItem>[];
  tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Builder(
          builder: (pageContext) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    pageContext,
                    MaterialPageRoute(
                      builder: (_) => StudioContentDetailScreen(
                        item: item,
                        delete: (row) async {
                          asked.add(row);
                          return outcome;
                        },
                      ),
                    ),
                  );
                  popped?.add(result ?? false);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return asked;
}

void main() {
  setUpAll(loadAppFonts);

  group('the one action on the screen that cannot be taken back', () {
    testWidgets('every kind of row offers it', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      for (final item in [_media(), _media(type: 'music'), _post(), _event()]) {
        await tester.pumpWidget(
          SizingBuilder(
            baseSize: const Size(390, 844),
            builder: (context) => MaterialApp(
              key: ValueKey(item.kind),
              home: StudioContentDetailScreen(item: item),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('detail-delete')),
          findsOneWidget,
          reason: '${item.kind} has no way to be deleted',
        );
      }
    });

    testWidgets('and asks before it does anything', (tester) async {
      final asked = await _pump(tester, _media());

      await tester.tap(find.byKey(const ValueKey('detail-delete')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.contentDeleteTitle), findsOneWidget);
      expect(
        find.textContaining('The Prodigal Returns'),
        findsWidgets,
        reason: 'the dialog names what is about to go',
      );
      expect(asked, isEmpty, reason: 'nothing is deleted on the first tap');
    });

    testWidgets('backing out of that question deletes nothing', (tester) async {
      final asked = await _pump(tester, _media());

      await tester.tap(find.byKey(const ValueKey('detail-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-cancel')));
      await tester.pumpAndSettle();

      expect(asked, isEmpty);
      expect(find.byKey(const ValueKey('detail-delete')), findsOneWidget);
    });

    testWidgets('confirming removes it and leaves the screen', (tester) async {
      final popped = <bool>[];
      final asked = await _pump(tester, _media(), popped: popped);

      await tester.tap(find.byKey(const ValueKey('detail-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();

      expect(asked.single.id, 'm1');
      expect(find.text(AppStrings.contentDeleted), findsOneWidget);
      expect(popped, [
        true,
      ], reason: 'the list behind this has to reload without the row');
    });

    testWidgets('a row already gone counts as done', (tester) async {
      // Deleted from the web studio, or by another member, while this screen
      // held it. The creator wanted it gone and it is gone.
      final popped = <bool>[];
      await _pump(
        tester,
        _media(),
        outcome: ContentDeleteOutcome.gone,
        popped: popped,
      );

      await tester.tap(find.byKey(const ValueKey('detail-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.contentDeleteGone), findsOneWidget);
      expect(popped, [true]);
    });

    testWidgets('a refusal says whose permission it needs and stays put', (
      tester,
    ) async {
      // `DELETE /v1/media/:id` is owners and admins only: an editor who may
      // upload and edit is still refused, and "try again" would be a lie.
      final popped = <bool>[];
      await _pump(
        tester,
        _media(),
        outcome: ContentDeleteOutcome.notAllowed,
        popped: popped,
      );

      await tester.tap(find.byKey(const ValueKey('detail-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.contentDeleteNotAllowed), findsOneWidget);
      expect(popped, isEmpty, reason: 'nothing was deleted, so nothing moved');
      expect(find.byKey(const ValueKey('detail-delete')), findsOneWidget);
    });

    testWidgets('and a lost connection says nothing was deleted', (
      tester,
    ) async {
      await _pump(tester, _media(), outcome: ContentDeleteOutcome.network);

      await tester.tap(find.byKey(const ValueKey('detail-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.contentDeleteNetwork), findsOneWidget);
    });

    testWidgets('a broadcast on air is ended first, not deleted', (
      tester,
    ) async {
      // The route would take the stream out from under whoever is watching.
      final asked = await _pump(tester, _media(type: 'livestream', live: true));

      await tester.tap(find.byKey(const ValueKey('detail-delete')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.contentDeleteTitle), findsNothing);
      expect(find.text(AppStrings.contentDeleteLive), findsOneWidget);
      expect(asked, isEmpty);
    });
  });

  group('which route a row is deleted through', () {
    test('a video and a track go to the media service', () async {
      for (final type in ['video', 'music', 'livestream']) {
        final api = _FakeApi();
        final outcome = await ContentDelete.run(
          _media(type: type),
          media: MediaUploadRepo(api),
        );
        expect(outcome, ContentDeleteOutcome.done);
        expect(api.deleted, ['/v1/media/m1'], reason: type);
      }
    });

    test('a written post goes to the content service', () async {
      final api = _FakeApi();
      final outcome = await ContentDelete.run(_post(), posts: PostRepo(api));
      expect(outcome, ContentDeleteOutcome.done);
      expect(api.deleted, ['/v1/content/posts/p1']);
    });

    test('and an event to the calendar', () async {
      final api = _FakeApi();
      final outcome = await ContentDelete.run(_event(), events: EventRepo(api));
      expect(outcome, ContentDeleteOutcome.done);
      expect(api.deleted, ['/v1/content/calendar/events/e1']);
    });
  });

  group('what the three services say no with', () {
    // Each one has its own exception and its own failure words; a screen
    // showing a row should not have to know which of the three it drew.
    test('403 is the same refusal whichever service answered it', () async {
      expect(
        await ContentDelete.run(
          _media(),
          media: MediaUploadRepo(_FakeApi(status: 403)),
        ),
        ContentDeleteOutcome.notAllowed,
      );
      expect(
        await ContentDelete.run(
          _post(),
          posts: PostRepo(_FakeApi(status: 403)),
        ),
        ContentDeleteOutcome.notAllowed,
      );
      expect(
        await ContentDelete.run(
          _event(),
          events: EventRepo(_FakeApi(status: 403)),
        ),
        ContentDeleteOutcome.notAllowed,
      );
    });

    test('and so is 404', () async {
      expect(
        await ContentDelete.run(
          _media(),
          media: MediaUploadRepo(_FakeApi(status: 404)),
        ),
        ContentDeleteOutcome.gone,
      );
      expect(
        await ContentDelete.run(
          _post(),
          posts: PostRepo(_FakeApi(status: 404)),
        ),
        ContentDeleteOutcome.gone,
      );
      expect(
        await ContentDelete.run(
          _event(),
          events: EventRepo(_FakeApi(status: 404)),
        ),
        ContentDeleteOutcome.gone,
      );
    });

    test('anything else is a plain refusal', () async {
      expect(
        await ContentDelete.run(
          _media(),
          media: MediaUploadRepo(_FakeApi(status: 500)),
        ),
        ContentDeleteOutcome.refused,
      );
    });
  });
}
