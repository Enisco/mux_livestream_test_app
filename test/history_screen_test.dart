import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:dio/dio.dart';
import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/features/history/views/history_screen.dart';
import 'package:test_app/features/history/views/widgets/history_parts.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/fixture_time.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(backgroundColor: AppColors.base1, body: child),
      ),
    ),
  );
  await tester.pump();
}

/// History as the gateway sends it.
///
/// The rows go through the real mapper rather than being hand-built, so what
/// these exercise is the grouping, the per-kind wording and the progress rule
/// as well as the screen.
class _FakeApi implements ApiService {
  _FakeApi({this.items = const [], this.fail = false});

  final List<Map<String, dynamic>> items;
  final bool fail;
  final List<String> deletes = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (fail) throw DioException(requestOptions: RequestOptions(path: path));
    return _ok(path, {'items': items, 'total': items.length});
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    deletes.add(path);
    return _ok(path, const <String, dynamic>{});
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

Map<String, dynamic> _row({
  required String id,
  required String title,
  String creator = 'Grace Community',
  bool verified = true,
  String entityType = 'media',
  String? mediaType = 'video',
  int views = 12000,
  double? duration,
  int? progressPercent,
  bool completed = false,
  required Duration ago,
}) => {
  'entityType': entityType,
  'entityId': id,
  'title': title,
  'historyTargetType': entityType,
  'viewedAt': fixtureAgo(ago),
  'completed': completed,
  'creator': {
    'id': 'c1',
    'displayName': creator,
    'handle': 'grace',
    'verifiedAt': verified ? '2026-01-01T00:00:00.000Z' : null,
  },
  // Counts and media type live in `facets`; the artwork, runtime and
  // progress live in `meta`. Reading a count from the wrong half prints
  // nothing at all.
  'facets': {'mediaType': mediaType, 'analyticsViews': views},
  'meta': {
    'durationSeconds': duration,
    'progressPercent': progressPercent,
    'thumbnailUrl': null,
  },
};

/// A day's worth of plausible history, spanning three day groups.
List<Map<String, dynamic>> _history() => [
  _row(
    id: 'h1',
    title: 'Romans, chapter',
    ago: const Duration(hours: 2),
    progressPercent: 28,
  ),
  _row(
    id: 'h2',
    title: 'Sunday Worship',
    ago: const Duration(hours: 5),
    views: 12000,
  ),
  _row(
    id: 'h3',
    title: 'When Mountains Move',
    creator: 'Horizon Chapel',
    ago: const Duration(days: 1, hours: 2),
    mediaType: 'music',
    views: 10,
    duration: 25,
  ),
  _row(
    id: 'h4',
    title: 'Why we fast',
    entityType: 'post',
    mediaType: null,
    ago: const Duration(days: 3),
    views: 12,
  ),
];

Future<_FakeApi> _pumpScreen(
  WidgetTester tester, {
  List<Map<String, dynamic>>? items,
  bool fail = false,
  Size size = const Size(390, 2400),
}) async {
  final api = _FakeApi(items: items ?? _history(), fail: fail);
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        home: HistoryScreen(repo: ViewerLibraryRepo(api: api)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  group('the screen', () {
    testWidgets('groups by the day each thing was watched', (tester) async {
      await _pumpScreen(tester);

      expect(find.text('Continue watching'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      // Twice over: once in the resume rail, because it was part-watched,
      // and once in its day group.
      expect(find.text('Romans, chapter'), findsNWidgets(2));
    });

    testWidgets('typing narrows to matching rows and drops empty days', (
      tester,
    ) async {
      // There is no `q` on the history route, so this narrows what has been
      // loaded rather than asking the server again.
      await _pumpScreen(tester, size: const Size(390, 844));

      await tester.enterText(find.byType(TextField), 'romans');
      await tester.pump();

      expect(find.text('Romans, chapter'), findsOneWidget);
      expect(find.text('Sunday Worship'), findsNothing);
      expect(find.text('Yesterday'), findsNothing);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('a search matches the creator as well as the title', (
      tester,
    ) async {
      await _pumpScreen(tester, size: const Size(390, 844));

      await tester.enterText(find.byType(TextField), 'horizon');
      await tester.pump();

      expect(find.text('When Mountains Move'), findsOneWidget);
      expect(find.text('Romans, chapter'), findsNothing);
    });

    testWidgets('the resume rail is hidden while searching', (tester) async {
      // It is not a search result, so leaving it up would look like one.
      await _pumpScreen(tester, size: const Size(390, 844));
      expect(find.text('Continue watching'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'romans');
      await tester.pump();

      expect(find.text('Continue watching'), findsNothing);
    });

    testWidgets('a query nothing matches explains itself', (tester) async {
      await _pumpScreen(tester, size: const Size(390, 844));

      await tester.enterText(find.byType(TextField), 'zzzzzz');
      await tester.pump();

      expect(find.text('Nothing matched'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsNothing);
    });

    testWidgets('an empty history says so', (tester) async {
      await _pumpScreen(tester, items: const []);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      await _pumpScreen(tester, fail: true);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('clearing asks first, then calls the route', (tester) async {
      final api = await _pumpScreen(tester, size: const Size(390, 844));

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('Clear your history?'), findsOneWidget);

      // Backing out leaves the list alone and sends nothing.
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Romans, chapter'), findsWidgets);
      expect(api.deletes, isEmpty);

      await tester.tap(find.text('Clear all').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear all'));
      await tester.pumpAndSettle();

      expect(api.deletes, ['/v1/discovery/viewer/history']);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('and says it hides rather than deleting for ever', (
      tester,
    ) async {
      // The route suppresses history up to an instant; anything watched
      // again comes back, so promising permanence would be a lie.
      await _pumpScreen(tester, size: const Size(390, 844));
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(find.textContaining('reappear'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsNothing);
    });
  });

  group('a history row', () {
    testWidgets('counts each kind in its own words', (tester) async {
      await _pumpScreen(tester);

      // Video is counted in views, audio in plays, a blog in opens.
      expect(find.textContaining('12K views'), findsWidgets);
      expect(find.textContaining('10 plays'), findsOneWidget);
      expect(find.textContaining('12 opens'), findsOneWidget);
    });

    testWidgets('a runtime is printed as a clock, not as seconds', (
      tester,
    ) async {
      await _pumpScreen(tester);
      expect(find.text('0:25'), findsOneWidget);
    });

    testWidgets('a row with no count does not print a bare zero', (
      tester,
    ) async {
      await _pump(
        tester,
        const ContentListRow(
          title: 'Untouched',
          creatorName: 'Someone',
          meta: 'Video · 6d',
        ),
      );
      expect(find.textContaining('0 views'), findsNothing);
    });

    testWidgets('a part-watched row draws its progress bar', (tester) async {
      await _pump(
        tester,
        const ContentListRow(
          title: 'Half seen',
          creatorName: 'Someone',
          progress: 0.4,
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.4, 0.001));
    });

    testWidgets('an unwatched row draws no bar at all', (tester) async {
      await _pump(
        tester,
        const ContentListRow(title: 'Fresh', creatorName: 'Someone'),
      );
      expect(find.byType(FractionallySizedBox), findsNothing);
    });
  });

  group('a resume card', () {
    testWidgets('shows how far in the reader got', (tester) async {
      await _pump(
        tester,
        const HistoryResumeCard(
          item: HistoryResumeItem(
            id: 'r',
            title: 'Half seen',
            creatorName: 'Grace Community',
            progress: 0.59,
          ),
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, closeTo(0.59, 0.001));
    });

    testWidgets('a progress value beyond the end cannot overrun', (
      tester,
    ) async {
      await _pump(
        tester,
        const HistoryResumeCard(
          item: HistoryResumeItem(
            id: 'r',
            title: 'Done',
            creatorName: 'C',
            progress: 2,
          ),
        ),
      );

      final bar = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(bar.widthFactor, 1);
    });
  });

  group('every kind is reachable', () {
    test('each kind knows what it counts', () {
      expect(HistoryKind.video.countNoun, 'views');
      expect(HistoryKind.audio.countNoun, 'plays');
      expect(HistoryKind.blog.countNoun, 'opens');
      expect(HistoryKind.event.countNoun, isEmpty);
    });

    test('every entity type one list can hold names itself', () {
      // A history list mixes every type. A kind the mapper does not know
      // must still land somewhere sensible rather than crashing the row.
      const cases = {
        'post': HistoryKind.blog,
        'event': HistoryKind.event,
        'devotional_series': HistoryKind.devotional,
        'devotional_entry': HistoryKind.devotional,
        'media': HistoryKind.video,
        'something_new': HistoryKind.video,
      };
      cases.forEach((entityType, expected) {
        final page = ViewerLibraryRepo.debugMap([
          {
            'entityType': entityType,
            'entityId': 'x',
            'title': 'A thing',
            'viewedAt': '2026-10-05T10:00:00.000Z',
            'meta': const <String, dynamic>{},
          },
        ]);
        expect(page.single.kind, expected, reason: entityType);
      });
    });

    test('and audio is told apart from video by its media type', () {
      final page = ViewerLibraryRepo.debugMap([
        {
          'entityType': 'media',
          'entityId': 'x',
          'title': 'A song',
          'viewedAt': '2026-10-05T10:00:00.000Z',
          'meta': const {'mediaType': 'music'},
        },
      ]);
      expect(page.single.kind, HistoryKind.audio);
    });
  });
}
