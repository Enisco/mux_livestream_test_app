import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/views/go_live_setup_screen.dart';
import 'package:test_app/features/creator/views/widgets/creator_topics_sheet.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/services/api_service.dart';

import 'helpers/load_app_fonts.dart';

/// `GET /v1/user/categories` as staging answers it, 2026-11-13.
///
/// Trimmed to the fields that matter and to the rows that settle something:
/// `devotionals` is the one that takes no media, `live-services` the one
/// that takes the fewest kinds otherwise.
const _taxonomy = {
  'data': {
    'data': [
      {
        'slug': 'worship',
        'name': 'Worship',
        'contentTypes': ['media', 'media_series', 'post', 'event', 'creator'],
        'sortOrder': 1,
        'isActive': true,
      },
      {
        'slug': 'live-services',
        'name': 'Live Services',
        'contentTypes': ['media', 'event', 'creator'],
        'sortOrder': 6,
        'isActive': true,
      },
      {
        'slug': 'testimonies',
        'name': 'Testimonies',
        'contentTypes': ['media', 'post', 'event', 'creator'],
        'sortOrder': 7,
        'isActive': true,
      },
      {
        'slug': 'devotionals',
        'name': 'Devotionals',
        'contentTypes': [
          'post',
          'devotional_series',
          'devotional_entry',
          'creator',
        ],
        'sortOrder': 10,
        'isActive': true,
      },
    ],
  },
};

class _FakeApi implements ApiService {
  _FakeApi([this.body = _taxonomy]);

  final Map<String, dynamic> body;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    data: body as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<String> _slugs(List<ContentCategory> rows) => [
  for (final row in rows) row.slug,
];

Future<void> _pumpSheet(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(home: child),
    ),
  );
  await tester.pump();
}

void main() {
  group('what a category may be filed against', () {
    test('a livestream is not offered the written-only ones', () async {
      // The bug: the Go Live form offered every category, and the session
      // route answered "Categories not supported for media: devotionals".
      final rows = await CreatorRepo(
        api: _FakeApi(),
      ).fetchCategories(forContent: CategoryScope.media);

      expect(_slugs(rows), isNot(contains('devotionals')));
      expect(_slugs(rows), contains('live-services'));
    });

    test('nor is an event, which devotionals also does not take', () async {
      final rows = await CreatorRepo(
        api: _FakeApi(),
      ).fetchCategories(forContent: CategoryScope.event);

      expect(_slugs(rows), isNot(contains('devotionals')));
      expect(_slugs(rows), contains('live-services'));
    });

    test('a written post still gets it', () async {
      final rows = await CreatorRepo(
        api: _FakeApi(),
      ).fetchCategories(forContent: CategoryScope.post);

      expect(_slugs(rows), contains('devotionals'));
      // And loses the one that is media and events only.
      expect(_slugs(rows), isNot(contains('live-services')));
    });

    test('and a channel gets all of them, which is what it had', () async {
      final rows = await CreatorRepo(
        api: _FakeApi(),
      ).fetchCategories(forContent: CategoryScope.creator);

      expect(rows, hasLength(4));
    });

    test('asking for no particular kind still answers the taxonomy', () async {
      final rows = await CreatorRepo(api: _FakeApi()).fetchCategories();

      expect(rows, hasLength(4));
    });

    test('a retired category is dropped whatever it supports', () async {
      final rows = await CreatorRepo(
        api: _FakeApi({
          'data': {
            'data': [
              {
                'slug': 'worship',
                'name': 'Worship',
                'contentTypes': ['media'],
                'isActive': false,
              },
              {
                'slug': 'sermons',
                'name': 'Sermons',
                'contentTypes': ['media'],
                'isActive': true,
              },
            ],
          },
        }),
      ).fetchCategories(forContent: CategoryScope.media);

      expect(_slugs(rows), ['sermons']);
    });

    test('a taxonomy that does not say is not second-guessed', () async {
      // An older API, or a payload without the field: hiding rows on a
      // guess would leave a creator unable to categorise anything.
      final rows = await CreatorRepo(
        api: _FakeApi({
          'data': {
            'data': [
              {'slug': 'worship', 'name': 'Worship', 'isActive': true},
            ],
          },
        }),
      ).fetchCategories(forContent: CategoryScope.media);

      expect(_slugs(rows), ['worship']);
    });
  });

  group('the sheet does not put one back', () {
    testWidgets('its fallback list hides them too', (tester) async {
      // The list the sheet falls back to when the call failed was written
      // out by hand, so filtering the repo alone would not have been
      // enough: the form would offer devotionals again the moment the
      // taxonomy did not load.
      await _pumpSheet(
        tester,
        const Scaffold(body: CreatorTopicsSheet(scope: CategoryScope.media)),
      );

      expect(find.text('Devotionals'), findsNothing);
      expect(find.text('Worship'), findsOneWidget);
    });

    testWidgets('and keeps everything when nothing was said', (tester) async {
      await _pumpSheet(tester, const Scaffold(body: CreatorTopicsSheet()));

      expect(find.text('Devotionals'), findsOneWidget);
    });

    testWidgets('a scoped sheet filters rows it was handed as well', (
      tester,
    ) async {
      // Belt and braces: a caller that forgets to scope the fetch is still
      // safe, because the sheet checks what it draws.
      await _pumpSheet(
        tester,
        const Scaffold(
          body: CreatorTopicsSheet(
            scope: CategoryScope.media,
            categories: [
              ContentCategory(
                slug: 'devotionals',
                name: 'Devotionals',
                contentTypes: ['post', 'creator'],
              ),
              ContentCategory(
                slug: 'sermons',
                name: 'Sermons',
                contentTypes: ['media'],
              ),
            ],
          ),
        ),
      );

      expect(find.text('Devotionals'), findsNothing);
      expect(find.text('Sermons'), findsOneWidget);
    });

    test('every fallback row says what it may be filed against', () {
      // A new row added to one list and not the other would be offered
      // everywhere, which is the bug all over again.
      for (final (slug, _) in CreatorTopicsSheet.fallback) {
        expect(
          CreatorTopicsSheet.fallbackContentTypes[slug],
          isNotNull,
          reason: '$slug has no content types beside it',
        );
      }
    });
  });

  group('the form the creator actually saw', () {
    // The real fonts, or the test font's one-em glyphs invent overflows in
    // the thumbnail row and the screen never finishes laying out.
    setUpAll(loadAppFonts);

    testWidgets('Go Live offers no category the session route refuses', (
      tester,
    ) async {
      final api = _FakeApi();
      await _pumpSheet(
        tester,
        GoLiveSetupScreen(
          creatorId: 'c1',
          live: LivestreamRepo(api),
          uploads: MediaUploadRepo(api),
          creators: CreatorRepo(api: api),
        ),
        size: const Size(390, 1100),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('live-category')));
      await tester.pumpAndSettle();

      expect(find.text('Devotionals'), findsNothing);
      expect(find.text('Live Services'), findsOneWidget);
    });
  });
}
