import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/library/repo/playlist_repo.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/models/library_models/playlist_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/features/library/views/playlist_add_screen.dart';
import 'package:test_app/features/library/views/playlist_detail_screen.dart';
import 'package:test_app/features/library/views/playlist_form_screen.dart';
import 'package:test_app/features/library/views/playlists_screen.dart';
import 'helpers/load_app_fonts.dart';

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
      builder: (context) => MaterialApp(home: child),
    ),
  );
  await tester.pump();
}

/// Playlists as staging actually answers.
///
/// Worth stating because the integration guide says otherwise: `visibility`
/// is refused on create and on update, the detail read returns
/// `orderedMediaIds` rather than ready-to-render `items`, and there is no
/// public read at all. These feed the real repo so the hydration — one search
/// over the ids, then the playlist's own order restored — is exercised too.
class _FakeApi implements ApiService {
  _FakeApi({this.rows = const [], this.ids = const [], this.hits = const []});

  /// Playlist summaries for the list read.
  final List<Map<String, dynamic>> rows;

  /// `orderedMediaIds` on the detail read.
  final List<String> ids;

  /// What the hydrating search answers with.
  final List<Map<String, dynamic>> hits;

  final List<(String, Object?)> posts = [];
  final List<(String, Object?)> patches = [];
  final List<String> deletes = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add((path, data));
    if (path.contains('search/public/query')) {
      // Search ranks by relevance; it will not hand back playlist order.
      return _ok(path, {'hits': hits.reversed.toList(), 'total': hits.length});
    }
    if (path.contains('playlists/search')) {
      return _ok(path, {
        'data': rows,
        'meta': {'total': rows.length, 'next': null},
      });
    }
    if (path.contains('content-suggestions')) {
      return _ok(path, {'items': hits});
    }
    return _ok(path, _playlistJson());
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => _ok(path, _playlistJson());

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    patches.add((path, data));
    return _ok(path, _playlistJson());
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

  Map<String, dynamic> _playlistJson() => {
    'id': 'p1',
    'title': 'Sunday drive worship',
    'visibility': 'private',
    'itemCount': ids.length,
    'orderedMediaIds': ids,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  };

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Map<String, dynamic> _summaryJson({
  String id = 'p1',
  String title = 'Sunday drive worship',
  int itemCount = 2,
}) => {
  'id': id,
  'title': title,
  'visibility': 'private',
  'itemCount': itemCount,
  'updatedAt': DateTime.now().toUtc().toIso8601String(),
};

Map<String, dynamic> _mediaHit(String id, String title) => {
  'entityType': 'media',
  'entityId': id,
  'title': title,
  'facets': const {'mediaType': 'video', 'analyticsViews': 10},
  'meta': const {'durationSeconds': 60.0},
  'creator': const {'creatorId': 'c1', 'displayName': 'Grace Chapel'},
};

/// A list row, as the list screen hands one to the detail screen.
Playlist _summary({String id = 'p1', String name = 'Sunday drive worship'}) =>
    Playlist(
      id: id,
      name: name,
      updatedAgo: '2h',
      covers: const [],
      items: const [],
      declaredCount: 2,
    );

_FakeApi _register({
  List<Map<String, dynamic>> rows = const [],
  List<String> ids = const [],
  List<Map<String, dynamic>> hits = const [],
}) {
  final api = _FakeApi(rows: rows, ids: ids, hits: hits);
  // `GetIt.reset()` is asynchronous, so resetting in a cascade races the
  // registrations that follow it and leaves the locator half empty.
  GetIt.instance
    ..allowReassignment = true
    ..registerSingleton<ApiService>(api)
    ..registerSingleton<DiscoveryRepo>(DiscoveryRepo());
  addTearDown(GetIt.instance.reset);
  return api;
}

/// Tall enough that the lazy lists build every row at once.
const _tall = Size(390, 3200);

void main() {
  setUpAll(loadAppFonts);

  group('the playlist list', () {
    testWidgets('names every playlist and what is in it', (tester) async {
      final api = _register(
        rows: [
          _summaryJson(),
          _summaryJson(id: 'p2', title: 'Late night prayers', itemCount: 0),
        ],
      );
      await _pump(
        tester,
        PlaylistsScreen(repo: PlaylistRepo(api: api)),
        size: _tall,
      );

      expect(find.text('Sunday drive worship'), findsOneWidget);
      expect(find.text('Late night prayers'), findsOneWidget);
    });

    testWidgets('the count is the server\'s, not the rows on hand', (
      tester,
    ) async {
      // The list read carries no items at all, so counting an array would
      // say every playlist is empty.
      final api = _register(rows: [_summaryJson(itemCount: 12)]);
      await _pump(
        tester,
        PlaylistsScreen(repo: PlaylistRepo(api: api)),
        size: _tall,
      );
      expect(find.textContaining('12'), findsWidgets);
    });

    testWidgets('searching asks the server, not the page in hand', (
      tester,
    ) async {
      // A reader with fifty playlists would otherwise only ever find the
      // ones already loaded.
      final api = _register(rows: [_summaryJson()]);
      await _pump(
        tester,
        PlaylistsScreen(repo: PlaylistRepo(api: api)),
        size: _tall,
      );

      await tester.enterText(find.byType(TextField), 'prayer');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final body = api.posts.last.$2! as Map<String, dynamic>;
      expect(body['filters'], {
        'title': {'contains': 'prayer'},
      });
    });

    testWidgets('creating one posts it and reloads', (tester) async {
      final api = _register(rows: [_summaryJson()]);
      await _pump(
        tester,
        PlaylistsScreen(repo: PlaylistRepo(api: api)),
        size: _tall,
      );

      await tester.tap(find.text('New playlist').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Road trip');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create new playlist'));
      await tester.pumpAndSettle();

      final created = api.posts.firstWhere(
        (c) => c.$1 == '/v1/media/playlists',
      );
      expect(created.$2, {'title': 'Road trip'});
    });

    testWidgets('and never sends a visibility the API refuses', (tester) async {
      // Staging answers "property visibility should not exist" on create and
      // on update alike.
      final api = _register(rows: [_summaryJson()]);
      await _pump(
        tester,
        PlaylistsScreen(repo: PlaylistRepo(api: api)),
        size: _tall,
      );

      await tester.tap(find.text('New playlist').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Road trip');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create new playlist'));
      await tester.pumpAndSettle();

      for (final call in api.posts) {
        final body = call.$2;
        if (body is Map<String, dynamic>) {
          expect(body.containsKey('visibility'), isFalse, reason: '$call');
        }
      }
    });

    testWidgets('deleting one calls the route', (tester) async {
      final api = _register(rows: [_summaryJson()]);
      await _pump(
        tester,
        PlaylistsScreen(repo: PlaylistRepo(api: api)),
        size: _tall,
      );

      await tester.tap(find.byKey(const ValueKey('row-more-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE').last);
      await tester.pumpAndSettle();

      expect(api.deletes, ['/v1/media/playlists/p1']);
    });
  });

  group('the form', () {
    testWidgets('will not submit an empty name', (tester) async {
      _register();
      await _pump(tester, const PlaylistFormScreen());

      await tester.tap(find.text('Create new playlist'));
      await tester.pumpAndSettle();
      // Still on the form: nothing was handed back.
      expect(find.text('New playlist'), findsOneWidget);
    });

    testWidgets('says plainly that a public playlist is not possible', (
      tester,
    ) async {
      // The design offers the choice; the API has no way to honour it, so
      // the control is inert and the screen explains why.
      _register();
      await _pump(tester, const PlaylistFormScreen());

      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.textContaining('stay private'), findsOneWidget);

      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();
      // Still private: the tap does nothing rather than lying.
      expect(find.textContaining('stay private'), findsOneWidget);
    });

    testWidgets('editing arrives with the name already in it', (tester) async {
      _register();
      await _pump(tester, PlaylistFormScreen(existing: _summary()));

      expect(find.text('Edit playlist'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Sunday drive worship',
      );
    });
  });

  group('the detail screen', () {
    testWidgets('hydrates its ids and keeps the playlist\'s own order', (
      tester,
    ) async {
      // The read returns `orderedMediaIds` only, and the hydrating search
      // ranks by relevance — so the order has to be put back.
      _register(
        ids: const ['m1', 'm2', 'm3'],
        hits: [
          _mediaHit('m1', 'First'),
          _mediaHit('m2', 'Second'),
          _mediaHit('m3', 'Third'),
        ],
      );
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: _summary(), repo: PlaylistRepo()),
        size: _tall,
      );

      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((t) => ['First', 'Second', 'Third'].contains(t))
          .toList();
      expect(titles, ['First', 'Second', 'Third']);
    });

    testWidgets('an id the search cannot resolve is counted, not drawn', (
      tester,
    ) async {
      // Content deleted or made private since it was added.
      _register(
        ids: const ['m1', 'gone'],
        hits: [_mediaHit('m1', 'Still here')],
      );
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: _summary(), repo: PlaylistRepo()),
        size: _tall,
      );

      expect(find.text('Still here'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty playlist says so and offers no suggestions', (
      tester,
    ) async {
      // There is nothing to anchor suggestions on, and a generic list under
      // an empty playlist is just the feed again.
      _register();
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: _summary(), repo: PlaylistRepo()),
        size: _tall,
      );

      expect(find.text('Recommended for you'), findsNothing);
    });

    testWidgets('removing an item calls the route', (tester) async {
      final api = _register(
        ids: const ['m1'],
        hits: [_mediaHit('m1', 'First')],
      );
      await _pump(
        tester,
        PlaylistDetailScreen(
          playlist: _summary(),
          repo: PlaylistRepo(api: api),
        ),
        size: _tall,
      );

      await tester.tap(find.byKey(const ValueKey('more-m1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();

      expect(api.deletes, contains('/v1/media/playlists/p1/items/m1'));
    });
  });

  group('adding content', () {
    testWidgets('offers suggestions anchored on what is already in it', (
      tester,
    ) async {
      final api = _register(hits: [_mediaHit('m9', 'Suggested')]);
      await _pump(
        tester,
        PlaylistAddScreen(
          playlistName: 'Sunday drive worship',
          anchorMediaId: 'm1',
          discovery: DiscoveryRepo(),
        ),
        size: _tall,
      );

      expect(find.text('Suggested'), findsOneWidget);
      expect(
        api.posts.any((c) => c.$1.contains('content-suggestions')),
        isTrue,
      );
    });

    testWidgets('an empty playlist falls back to what is popular', (
      tester,
    ) async {
      // There is nothing to anchor on, and offering nothing at all would
      // leave the reader stuck.
      final api = _register(hits: [_mediaHit('m9', 'Popular')]);
      await _pump(
        tester,
        PlaylistAddScreen(
          playlistName: 'Sunday drive worship',
          discovery: DiscoveryRepo(),
        ),
        size: _tall,
      );

      expect(find.text('Popular'), findsOneWidget);
      final search = api.posts.firstWhere(
        (c) => c.$1.contains('search/public/query'),
      );
      expect((search.$2! as Map<String, dynamic>)['sort'], 'popular');
    });

    testWidgets('something already in it cannot be picked again', (
      tester,
    ) async {
      // A duplicate add answers 409 rather than quietly doing nothing.
      _register(hits: [_mediaHit('m9', 'Already in')]);
      await _pump(
        tester,
        PlaylistAddScreen(
          playlistName: 'Sunday drive worship',
          anchorMediaId: 'm1',
          alreadyIn: const {'m9'},
          discovery: DiscoveryRepo(),
        ),
        size: _tall,
      );

      expect(find.byKey(const ValueKey('added')), findsOneWidget);
    });
  });

  group('the repo', () {
    test('a runtime is the sum of what it holds', () {
      final page = PlaylistRepo.debugDetail(
        {'id': 'p', 'title': 'x', 'itemCount': 2},
        const [
          HistoryEntry(
            id: '1',
            kind: HistoryKind.video,
            title: 'a',
            creatorName: '',
            age: '',
            duration: '40:00',
          ),
          HistoryEntry(
            id: '2',
            kind: HistoryKind.video,
            title: 'b',
            creatorName: '',
            age: '',
            duration: '30:00',
          ),
        ],
      );
      expect(page.runtime, '1h 10m');
    });

    test('and is left out when something has no runtime at all', () {
      // Better no total than one quietly short of the truth.
      final page = PlaylistRepo.debugDetail(
        {'id': 'p', 'title': 'x', 'itemCount': 2},
        const [
          HistoryEntry(
            id: '1',
            kind: HistoryKind.video,
            title: 'a',
            creatorName: '',
            age: '',
            duration: '40:00',
          ),
          HistoryEntry(
            id: '2',
            kind: HistoryKind.video,
            title: 'b',
            creatorName: '',
            age: '',
          ),
        ],
      );
      expect(page.runtime, isEmpty);
    });

    test('what the search could not resolve is counted as unavailable', () {
      final page = PlaylistRepo.debugDetail(
        {'id': 'p', 'title': 'x', 'itemCount': 5},
        const [
          HistoryEntry(
            id: '1',
            kind: HistoryKind.video,
            title: 'a',
            creatorName: '',
            age: '',
          ),
        ],
      );
      expect(page.unavailableCount, 4);
      expect(page.itemCount, 5);
    });
  });
}
