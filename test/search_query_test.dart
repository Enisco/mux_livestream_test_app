import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/features/discovery/data/search_query.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/shared/services/api_service.dart';

/// What a search actually asks the server for.
///
/// Matching used to happen on the device, against whatever page of the mixed
/// feed happened to be in hand — so a query only ever found things already
/// loaded. `POST /v1/search/public/query` does it properly now, which moves
/// the interesting behaviour from "did this row match" to "did we ask the
/// right question". These pin the request.
class _FakeApi implements ApiService {
  final List<(String, Object?)> posts = [];
  final List<(String, Map<String, dynamic>?)> gets = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add((path, data));
    return _ok(path, {'hits': <dynamic>[], 'total': 0});
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    gets.add((path, queryParameters));
    return _ok(path, {'hits': <dynamic>[]});
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

/// The filters sent on the last search, by field.
Map<String, Object?> _filtersOf(_FakeApi api) {
  final body = api.posts.last.$2! as Map<String, dynamic>;
  final filters = (body['filters'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
  return {
    for (final f in filters) f['field'] as String: f['values'] ?? f['value'],
  };
}

Map<String, dynamic> _bodyOf(_FakeApi api) =>
    api.posts.last.$2! as Map<String, dynamic>;

void main() {
  late _FakeApi api;
  late DiscoveryRepo repo;

  setUp(() async {
    api = _FakeApi();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<ApiService>(api);
    repo = DiscoveryRepo();
  });

  tearDown(GetIt.instance.reset);

  group('the type tabs, as requests', () {
    test('All asks for nothing in particular', () {
      expect(SearchFilter.all.entityTypes, isEmpty);
      expect(SearchFilter.all.liveOnly, isFalse);
      expect(SearchFilter.all.mediaType, isNull);
    });

    test('Live is the only one that sets the live flag', () {
      for (final filter in SearchFilter.values) {
        expect(
          filter.liveOnly,
          filter == SearchFilter.live,
          reason: filter.name,
        );
      }
    });

    test('Videos and Audio split one entity type by media type', () {
      expect(SearchFilter.videos.entityTypes, ['media']);
      expect(SearchFilter.audio.entityTypes, ['media']);
      expect(SearchFilter.videos.mediaType, 'video');
      expect(SearchFilter.audio.mediaType, 'music');
    });

    test('and that split is a server filter, not a client sift', () async {
      await repo.searchPublic(q: 'worship', mediaType: 'music');
      expect(_filtersOf(api)['media.mediaType'], 'music');
    });

    test('non-media tabs carry their own entity types', () {
      expect(SearchFilter.creators.entityTypes, ['creator']);
      expect(SearchFilter.blogs.entityTypes, ['post']);
      expect(SearchFilter.events.entityTypes, ['event']);
      expect(SearchFilter.series.entityTypes, ['media_series']);
      expect(SearchFilter.devotionals.entityTypes, [
        'devotional_series',
        'devotional_entry',
      ]);
    });
  });

  group('building a search', () {
    test('a query goes to the public search route', () async {
      await repo.searchPublic(q: 'worship night');
      expect(api.posts.single.$1, '/v1/search/public/query');
      expect(_bodyOf(api)['q'], 'worship night');
    });

    test('a blank query is omitted, not sent as a wildcard', () async {
      // An empty `q` with a sort is the supported browse form; `"*"` is not,
      // and does not behave.
      await repo.searchPublic(q: '   ', sort: 'trending');
      final body = _bodyOf(api);
      expect(body.containsKey('q'), isFalse);
      expect(body['sort'], 'trending');
    });

    test('the live tab asks the server, not the page', () async {
      await repo.searchPublic(q: 'service', liveOnly: true);
      expect(_filtersOf(api)['media.isLiveNow'], true);
    });

    test('ids narrow to exactly those rows, for hydrating a rail', () async {
      await repo.searchPublic(entityIds: const ['a', 'b']);
      expect(_filtersOf(api)['entityId'], ['a', 'b']);
    });

    test('no filters at all means no filters key', () async {
      await repo.searchPublic(q: 'worship');
      expect(_bodyOf(api).containsKey('filters'), isFalse);
    });

    test('a cursor pages, and is sent only when there is one', () async {
      await repo.searchPublic(q: 'worship');
      expect(_bodyOf(api).containsKey('cursor'), isFalse);

      await repo.searchPublic(q: 'worship', cursor: 'abc');
      expect(_bodyOf(api)['cursor'], 'abc');
    });
  });

  group('browsing a topic', () {
    test('narrows by slug, with no query and no wildcard', () async {
      // A Browse chip is a category. Searching for the words "Bible study"
      // would match whatever contains them and miss everything tagged with
      // the slug but titled otherwise.
      await repo.searchPublic(
        categorySlugs: const ['bible-study'],
        sort: 'recent',
      );
      final body = _bodyOf(api);
      expect(body.containsKey('q'), isFalse);
      expect(body['sort'], 'recent');
      expect(_filtersOf(api)['categorySlugs'], ['bible-study']);
    });
  });

  group('autocomplete', () {
    test('offers nothing for an empty query, without asking', () async {
      expect(await repo.autocomplete('   '), isEmpty);
      expect(api.gets, isEmpty);
    });

    test('asks the index, trimmed', () async {
      await repo.autocomplete('  wor ');
      expect(api.gets.single.$1, '/v1/search/public/autocomplete');
      expect(api.gets.single.$2?['q'], 'wor');
    });

    test('size is clamped to what the route accepts', () async {
      // The gateway refuses anything outside 1–20.
      await repo.autocomplete('wor', size: 99);
      expect(api.gets.last.$2?['size'], 20);

      await repo.autocomplete('wor', size: 0);
      expect(api.gets.last.$2?['size'], 1);
    });

    test('entity types travel comma-separated, not bracketed', () async {
      // The bracket form is rejected by the gateway's query DTOs.
      await repo.autocomplete('grace', entityTypes: const ['creator', 'post']);
      expect(api.gets.last.$2?['entityTypes'], 'creator,post');
    });
  });
}
