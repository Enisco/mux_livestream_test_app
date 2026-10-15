import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/library/repo/playlist_repo.dart';
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

/// Playlists as staging answers them since 2026-10-15.
///
/// Three things changed that day and all three are encoded here: `visibility`
/// is writable, the detail read carries hydrated `items` (so the client no
/// longer runs a second search over `orderedMediaIds`), and the server counts
/// `unavailableCount` itself.
class _FakeApi implements ApiService {
  _FakeApi({
    this.rows = const [],
    this.ids = const [],
    this.hits = const [],
    this.unavailable = 0,
  });

  /// Playlist summaries for the list read.
  final List<Map<String, dynamic>> rows;

  /// Which ids the playlist holds, in its own order.
  final List<String> ids;

  /// The hydrated rows the detail read returns, keyed by `entityId`.
  final List<Map<String, dynamic>> hits;

  /// What the server says has gone since it was added.
  final int unavailable;

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
      return _ok(path, {'hits': hits, 'total': hits.length});
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

  Map<String, dynamic> _playlistJson() {
    final byId = {for (final h in hits) h['entityId'] as String? ?? '': h};
    return {
      'id': 'p1',
      'title': 'Sunday drive worship',
      'visibility': 'private',
      'itemCount': ids.length + unavailable,
      'orderedMediaIds': ids,
      // In the playlist's own order, already hydrated — no second search.
      'items': [for (final id in ids) ?byId[id]],
      'unavailableCount': unavailable,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
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
  int unavailable = 0,
}) {
  final api = _FakeApi(
    rows: rows,
    ids: ids,
    hits: hits,
    unavailable: unavailable,
  );
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
      expect(created.$2, {'title': 'Road trip', 'visibility': 'private'});
    });

    testWidgets('and a public one is created public', (tester) async {
      // `visibility` was refused on create and update until 2026-10-15. It
      // is writable now, so the choice on the form has to reach the route.
      final api = _register(rows: [_summaryJson()]);
      await _pump(
        tester,
        PlaylistsScreen(repo: PlaylistRepo(api: api)),
        size: _tall,
      );

      await tester.tap(find.text('New playlist').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Road trip');
      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create new playlist'));
      await tester.pumpAndSettle();

      final created = api.posts.firstWhere(
        (c) => c.$1 == '/v1/media/playlists',
      );
      expect(created.$2, {'title': 'Road trip', 'visibility': 'public'});
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

    testWidgets('offers a real choice of visibility', (tester) async {
      // The control was inert until 2026-10-15, with a line saying sharing
      // was unavailable. Both halves of that are now false.
      _register();
      await _pump(tester, const PlaylistFormScreen());

      expect(find.text(AppStrings.playlistPrivateNote), findsOneWidget);

      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.playlistPublicNote), findsOneWidget);
      expect(find.text(AppStrings.playlistPrivateNote), findsNothing);
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
    testWidgets('draws its items in the playlist\'s own order', (tester) async {
      // The read carries `items` already hydrated and already in order, so
      // nothing is fetched twice and nothing is re-sorted. It used to cost a
      // second search whose relevance ranking had to be undone.
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

    testWidgets('content that has gone is counted, not drawn', (tester) async {
      // Deleted or made private since it was added. The server leaves it out
      // of `items` and says so in `unavailableCount`.
      _register(
        ids: const ['m1'],
        hits: [_mediaHit('m1', 'Still here')],
        unavailable: 1,
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
    /// One `items` entry, as the detail read now sends it: a media search
    /// hit, `meta` and `creator` included. Before 2026-10-15 the read gave
    /// `orderedMediaIds` alone and the client hydrated them with a second
    /// search; it does not any more.
    Map<String, dynamic> item(String id, {double? seconds, String? title}) => {
      'entityType': 'media',
      'entityId': id,
      'title': title ?? id,
      'facets': const {'mediaType': 'video'},
      'meta': {'durationSeconds': seconds},
      'creator': const {'id': 'c1', 'displayName': 'Grace Community'},
    };

    testWidgets('a cover URL is fetched, not looked up as an asset', (
      tester,
    ) async {
      // `covers` holds URLs. The mosaic drew them with `Image.asset`, left
      // over from the dummy artwork, so every real cover threw "Unable to
      // load asset" and painted a red plate over the card.
      _register();
      await _pump(
        tester,
        const PlaylistMosaic(
          covers: ['https://cdn.example/cover.jpg'],
          width: 100,
          height: 100,
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
      expect(tester.takeException(), isNull);
    });

    test('items are read straight off the detail payload', () {
      final page = PlaylistRepo.debugDetail({
        'id': 'p',
        'title': 'x',
        'itemCount': 1,
        'items': [item('m1', seconds: 60, title: 'Romans')],
      });

      expect(page.items.single.title, 'Romans');
      expect(page.items.single.creatorName, 'Grace Community');
      // Carried whole so a tap can open it — the same hit the feeds send.
      expect(page.items.single.source?.entityId, 'm1');
    });

    test('a runtime is the sum of what it holds', () {
      final page = PlaylistRepo.debugDetail({
        'id': 'p',
        'title': 'x',
        'itemCount': 2,
        'items': [item('1', seconds: 2400), item('2', seconds: 1800)],
      });
      expect(page.runtime, '1h 10m');
    });

    test('and is left out when something has no runtime at all', () {
      // Better no total than one quietly short of the truth.
      final page = PlaylistRepo.debugDetail({
        'id': 'p',
        'title': 'x',
        'itemCount': 2,
        'items': [item('1', seconds: 2400), item('2')],
      });
      expect(page.runtime, isEmpty);
    });

    test('the server says how many have gone', () {
      // It used to be inferred from how many ids the hydrating search could
      // not resolve; `unavailableCount` is authoritative now.
      final page = PlaylistRepo.debugDetail({
        'id': 'p',
        'title': 'x',
        'itemCount': 5,
        'unavailableCount': 4,
        'items': [item('1')],
      });
      expect(page.unavailableCount, 4);
      expect(page.itemCount, 5);
    });

    test('and is inferred only when it does not', () {
      final page = PlaylistRepo.debugDetail({
        'id': 'p',
        'title': 'x',
        'itemCount': 5,
        'items': [item('1')],
      });
      expect(page.unavailableCount, 4);
    });
  });
}
