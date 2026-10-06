import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/features/library/views/liked_saved_screens.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'helpers/load_app_fonts.dart';

/// Liked and Saved, which are one screen reading two routes.
///
/// Both return enriched search hits — one list mixing media, posts, events and
/// devotionals — so what matters is that each row names its own kind, that the
/// grouping follows when the viewer acted rather than when the thing was
/// published, and that taking a row out sends the right target type.
class _FakeApi implements ApiService {
  _FakeApi({this.items = const [], this.total, this.fail = false});

  final List<Map<String, dynamic>> items;
  final int? total;
  final bool fail;

  final List<String> gets = [];
  final List<Object?> posts = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    gets.add(path);
    if (fail) throw DioException(requestOptions: RequestOptions(path: path));
    return _ok(path, {'items': items, 'total': total ?? items.length});
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add(data);
    return _ok(path, {'active': false});
  }

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

String _ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();

Map<String, dynamic> _hit({
  String id = 'e1',
  String title = 'Sunday Service',
  String entityType = 'media',
  String? mediaType = 'video',
  String? creator = 'Grace Chapel',
  Duration ago = const Duration(hours: 2),
  int views = 1200,
}) => {
  'entityType': entityType,
  'entityId': id,
  'title': title,
  'engagementTargetType': entityType == 'devotional_series'
      ? 'devotional'
      : entityType,
  'interactionAt': _ago(ago),
  if (creator != null)
    'creator': {
      'id': 'c1',
      'displayName': creator,
      'handle': 'grace',
      'verifiedAt': '2026-01-01T00:00:00.000Z',
    },
  // Counts and media type live in `facets`; the artwork and runtime live in
  // `meta`. Reading a count from the wrong half silently prints nothing.
  'facets': {'mediaType': mediaType, 'analyticsViews': views},
  'meta': const <String, dynamic>{},
};

Future<_FakeApi> _pump(
  WidgetTester tester,
  Widget Function(ViewerLibraryRepo) build, {
  List<Map<String, dynamic>>? items,
  int? total,
  bool fail = false,
}) async {
  final api = _FakeApi(items: items ?? [_hit()], total: total, fail: fail);
  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(api);
  GetIt.instance.registerSingleton<EngagementRepo>(EngagementRepo());
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(home: build(ViewerLibraryRepo(api: api))),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  group('liked', () {
    testWidgets('reads the liked route, not the saved one', (tester) async {
      final api = await _pump(tester, (r) => LikedScreen(repo: r));
      expect(api.gets.single, '/v1/engagement/interactions/me/liked');
    });

    testWidgets('groups by when the viewer acted, not when it was made', (
      tester,
    ) async {
      // `interactionAt` is the sort key; using the publish date would
      // scramble the list.
      await _pump(
        tester,
        (r) => LikedScreen(repo: r),
        items: [
          _hit(id: 'a', title: 'Liked today'),
          _hit(
            id: 'b',
            title: 'Liked yesterday',
            ago: const Duration(days: 1, hours: 3),
          ),
        ],
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('a row whose creator could not be resolved still renders', (
      tester,
    ) async {
      // The byline may be absent when the lookup degraded; dropping the row
      // would hide something the viewer actually liked.
      await _pump(
        tester,
        (r) => LikedScreen(repo: r),
        items: [_hit(creator: null, title: 'Orphaned')],
      );
      expect(find.text('Orphaned'), findsOneWidget);
    });

    testWidgets('a library of one does not read as "1 things"', (tester) async {
      await _pump(tester, (r) => LikedScreen(repo: r), items: [_hit()]);
      expect(find.text("1 thing you've appreciated"), findsOneWidget);
    });

    testWidgets('a row counts in the words its kind uses', (tester) async {
      await _pump(
        tester,
        (r) => LikedScreen(repo: r),
        items: [_hit(views: 1200)],
      );
      expect(find.textContaining('1.2K views'), findsOneWidget);
    });

    testWidgets('the count is the library total, not the page length', (
      tester,
    ) async {
      await _pump(
        tester,
        (r) => LikedScreen(repo: r),
        items: [_hit()],
        total: 132,
      );
      expect(find.textContaining('132'), findsOneWidget);
    });

    testWidgets('un-liking sends the row\'s own target type', (tester) async {
      // Mapping it from the entity type on the client is what the guide
      // warns against — a devotional entry is not a devotional series.
      final api = await _pump(
        tester,
        (r) => LikedScreen(repo: r),
        items: [_hit(id: 'd1', entityType: 'devotional_series')],
      );
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pumpAndSettle();

      expect(api.posts.single, {
        'targetType': 'devotional',
        'targetId': 'd1',
        'interactionType': 'like',
      });
    });

    testWidgets('an empty library says so', (tester) async {
      await _pump(tester, (r) => LikedScreen(repo: r), items: const []);
      expect(find.text('Nothing liked yet'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      await _pump(tester, (r) => LikedScreen(repo: r), fail: true);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('saved', () {
    testWidgets('reads the saved route and saves, not likes', (tester) async {
      final api = await _pump(tester, (r) => SavedScreen(repo: r));
      expect(api.gets.single, '/v1/engagement/interactions/me/saved');

      await tester.tap(find.byType(GestureDetector).last);
      await tester.pumpAndSettle();
      expect(
        (api.posts.single! as Map<String, dynamic>)['interactionType'],
        'favorite',
      );
    });

    testWidgets('filters by kind, which Liked does not offer', (tester) async {
      // One Saved list mixes every type, so it needs a way to see one at a
      // time; Liked is media-shaped enough not to.
      await _pump(
        tester,
        (r) => SavedScreen(repo: r),
        items: [
          _hit(id: 'v', title: 'A video'),
          _hit(
            id: 'p',
            title: 'An article',
            entityType: 'post',
            mediaType: null,
          ),
        ],
      );
      expect(find.text('A video'), findsOneWidget);
      expect(find.text('An article'), findsOneWidget);

      await tester.tap(find.text('Articles/Blog'));
      await tester.pumpAndSettle();
      expect(find.text('An article'), findsOneWidget);
      expect(find.text('A video'), findsNothing);
    });
  });

  group('the shared mapper', () {
    test('names each entity type in its own words', () {
      final rows = ViewerLibraryRepo.debugMap([
        {
          'entityType': 'post',
          'entityId': 'p',
          'title': 'An article',
          'viewedAt': _ago(const Duration(hours: 1)),
          'meta': const <String, dynamic>{},
        },
      ]);
      expect(rows.single.kind, HistoryKind.blog);
      expect(rows.single.kind.countNoun, 'opens');
    });

    test('a finished row draws no progress bar', () {
      // A full bar on something already watched reads as "nearly done".
      final rows = ViewerLibraryRepo.debugMap([
        {
          'entityType': 'media',
          'entityId': 'm',
          'title': 'Seen it',
          'viewedAt': _ago(const Duration(hours: 1)),
          'completed': true,
          'meta': const {'progressPercent': 100},
        },
      ]);
      expect(rows.single.progress, isNull);
    });

    test('and neither does one never started', () {
      final rows = ViewerLibraryRepo.debugMap([
        {
          'entityType': 'media',
          'entityId': 'm',
          'title': 'Opened once',
          'viewedAt': _ago(const Duration(hours: 1)),
          'meta': const {'progressPercent': 0},
        },
      ]);
      expect(rows.single.progress, isNull);
    });

    test('a part-watched row does', () {
      final rows = ViewerLibraryRepo.debugMap([
        {
          'entityType': 'media',
          'entityId': 'm',
          'title': 'Halfway',
          'viewedAt': _ago(const Duration(hours: 1)),
          'meta': const {'progressPercent': 40},
        },
      ]);
      expect(rows.single.progress, closeTo(0.4, 0.001));
    });

    test('a day spanning two pages is headed once, not twice', () {
      // Pages are joined, not concatenated: the same heading twice would
      // read as two different days.
      final a = [
        const HistoryDay(
          label: 'Today',
          entries: [
            HistoryEntry(
              id: '1',
              kind: HistoryKind.video,
              title: 'A',
              creatorName: '',
              age: '',
            ),
          ],
        ),
      ];
      final b = [
        const HistoryDay(
          label: 'Today',
          entries: [
            HistoryEntry(
              id: '2',
              kind: HistoryKind.video,
              title: 'B',
              creatorName: '',
              age: '',
            ),
          ],
        ),
        const HistoryDay(
          label: 'Yesterday',
          entries: [
            HistoryEntry(
              id: '3',
              kind: HistoryKind.video,
              title: 'C',
              creatorName: '',
              age: '',
            ),
          ],
        ),
      ];
      final merged = mergeDays(a, b);
      expect(merged.map((d) => d.label), ['Today', 'Yesterday']);
      expect(merged.first.entries, hasLength(2));
    });
  });
}
