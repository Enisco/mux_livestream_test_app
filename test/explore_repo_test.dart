import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/explore/repo/explore_repo.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';

/// Explore, which is a composition rather than an endpoint.
///
/// Every rail is built from reads that already existed, so most of what can go
/// wrong here is in the joining: a creator lookup that has to be batched, a
/// watch order that search will not preserve, a rail that fails without taking
/// the page down with it.
class _FakeApi implements ApiService {
  _FakeApi({
    this.media = const [],
    this.posts = const [],
    this.devotionals = const [],
    this.creators = const [],
    this.continueWatching = const [],
    this.recommended = const [],
    this.events = const [],
    this.failTrending = false,
    this.failCreatorLookup = false,
  });

  final List<Map<String, dynamic>> media;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> devotionals;
  final List<Map<String, dynamic>> creators;
  final List<Map<String, dynamic>> continueWatching;
  final List<Map<String, dynamic>> recommended;
  final List<Map<String, dynamic>> events;
  final bool failTrending;
  final bool failCreatorLookup;

  final List<Map<String, dynamic>> searches = [];
  final List<String> gets = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final body = (data as Map<String, dynamic>?) ?? const {};
    searches.add(body);
    final types = (body['entityTypes'] as List? ?? const []).cast<String>();
    final filters = (body['filters'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final byId = filters.any((f) => f['field'] == 'entityId');
    final live = filters.any((f) => f['field'] == 'media.isLiveNow');

    if (types.contains('creator')) {
      if (failCreatorLookup) {
        throw DioException(requestOptions: RequestOptions(path: path));
      }
      return _ok(path, {'hits': creators, 'total': creators.length});
    }
    if (types.contains('post')) return _ok(path, {'hits': posts});
    if (types.contains('devotional_series')) {
      return _ok(path, {'hits': devotionals});
    }
    if (live) return _ok(path, {'hits': <dynamic>[]});
    if (byId) return _ok(path, {'hits': continueWatching});
    if (failTrending && body['sort'] == 'trending') {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    return _ok(path, {'hits': media, 'total': media.length});
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    gets.add(path);
    if (path.contains('continue-watching')) {
      return _ok(path, {
        'items': [
          for (final row in continueWatching)
            {'mediaId': row['entityId'], 'positionSeconds': 30},
        ],
      });
    }
    if (path.contains('recommended-creators')) {
      return _ok(path, {'items': recommended});
    }
    if (path.contains('upcoming-events')) return _ok(path, {'items': events});
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

class _FakeTokens implements TokenStorageService {
  _FakeTokens({this.signedIn = true});

  final bool signedIn;

  @override
  Future<bool> get hasSession async => signedIn;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Map<String, dynamic> _mediaHit({
  String id = 'm1',
  String title = 'Sunday Service',
  String creatorId = 'c1',
  double? duration = 150,
}) => {
  'entityType': 'media',
  'entityId': id,
  'title': title,
  'facets': {'mediaType': 'video'},
  'meta': {
    'creatorId': creatorId,
    'thumbnailKey': 'public/thumbnail/$id.jpg',
    'durationSeconds': duration,
  },
};

Map<String, dynamic> _creatorHit({
  String id = 'c1',
  String name = 'Grace Chapel',
}) => {
  'entityType': 'creator',
  'entityId': id,
  'title': name,
  'subtitle': '@gracechapel',
  'meta': {'handle': 'gracechapel', 'creatorType': 'organization'},
};

Future<ExploreRepo> _repo(_FakeApi api, {bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues({});
  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(api);
  GetIt.instance.registerSingleton<TokenStorageService>(
    _FakeTokens(signedIn: signedIn),
  );
  return ExploreRepo(discovery: DiscoveryRepo());
}

void main() {
  tearDown(GetIt.instance.reset);

  group('browsing', () {
    test('every rail browses by sort, never by a wildcard query', () async {
      // An empty `q` with a sort is the supported browse form; `"*"` is not.
      final api = _FakeApi(media: [_mediaHit()]);
      await (await _repo(api)).load();

      expect(api.searches, isNotEmpty);
      for (final body in api.searches) {
        expect(body.containsKey('q'), isFalse, reason: body.toString());
      }
    });

    test('trending is asked for as trending', () async {
      final api = _FakeApi(media: [_mediaHit()]);
      await (await _repo(api)).load();
      expect(api.searches.where((b) => b['sort'] == 'trending'), isNotEmpty);
    });
  });

  group('creators on cards', () {
    test('are resolved in one lookup, not one per card', () async {
      // Search hits carry `meta.creatorId` and nothing else; the index does
      // not denormalise the creator.
      final api = _FakeApi(
        media: [
          _mediaHit(id: 'm1', creatorId: 'c1'),
          _mediaHit(id: 'm2', creatorId: 'c1'),
          _mediaHit(id: 'm3', creatorId: 'c2'),
        ],
        creators: [
          _creatorHit(id: 'c1'),
          _creatorHit(id: 'c2', name: 'Hope'),
        ],
      );
      final page = await (await _repo(api)).load();

      expect(page.trending.first.creator.name, 'Grace Chapel');
      expect(page.trending.last.creator.name, 'Hope');

      // One lookup per rail, carrying both distinct ids — not three.
      final lookup = api.searches.firstWhere(
        (b) => (b['entityTypes'] as List).contains('creator'),
      );
      final ids =
          ((lookup['filters'] as List).first as Map<String, dynamic>)['values'];
      expect(ids, hasLength(2));
    });

    test('a failed lookup still draws the cards, without a byline', () async {
      final api = _FakeApi(media: [_mediaHit()], failCreatorLookup: true);
      final page = await (await _repo(api)).load();

      expect(page.trending, hasLength(1));
      expect(page.trending.single.creator.name, isEmpty);
    });
  });

  group('continue watching', () {
    test('is not even asked for when nobody is signed in', () async {
      final api = _FakeApi(media: [_mediaHit()]);
      final page = await (await _repo(api, signedIn: false)).load();

      expect(page.continueWatching, isEmpty);
      expect(api.gets.where((p) => p.contains('continue-watching')), isEmpty);
    });

    test('keeps the order the viewer watched in', () async {
      // The references come back in watch order; the hydrating search ranks
      // by relevance and will not preserve it.
      final api = _FakeApi(
        media: [_mediaHit()],
        continueWatching: [
          _mediaHit(id: 'm3', title: 'Third'),
          _mediaHit(id: 'm1', title: 'First'),
          _mediaHit(id: 'm2', title: 'Second'),
        ],
        creators: [_creatorHit()],
      );
      final page = await (await _repo(api)).load();

      expect(page.continueWatching.map((c) => c.id).toList(), [
        'm3',
        'm1',
        'm2',
      ]);
    });

    test('carries how far in the viewer got', () async {
      final api = _FakeApi(
        media: [_mediaHit()],
        continueWatching: [_mediaHit(id: 'm1', duration: 120)],
        creators: [_creatorHit()],
      );
      final page = await (await _repo(api)).load();
      // 30s of 120s.
      expect(page.continueWatching.single.progress, closeTo(0.25, 0.001));
    });

    test('a row whose media has gone is dropped, not drawn blank', () async {
      final api = _FakeApi(
        media: [_mediaHit()],
        continueWatching: [_mediaHit(id: 'm1')],
        creators: [_creatorHit()],
      );
      // The hydrating search answers for m1 only; the reference list asks for
      // it plus one the search cannot resolve.
      final page = await (await _repo(api)).load();
      expect(page.continueWatching.map((c) => c.id), ['m1']);
    });
  });

  group('when something is quiet', () {
    test('an empty rail is empty, not an error', () async {
      final api = _FakeApi(media: [_mediaHit()], creators: [_creatorHit()]);
      final page = await (await _repo(api)).load();

      expect(page.live, isEmpty);
      expect(page.trending, isNotEmpty);
      expect(page.isEmpty, isFalse);
    });

    test('one rail failing leaves the others standing', () async {
      final api = _FakeApi(
        media: [_mediaHit()],
        posts: [_mediaHit(id: 'p1', title: 'An article')],
        devotionals: [_mediaHit(id: 'd1', title: 'Seven days')],
        creators: [_creatorHit()],
        failTrending: true,
      );
      final page = await (await _repo(api)).load();

      expect(page.trending, isEmpty);
      expect(page.articles, hasLength(1));
      expect(page.devotionals, hasLength(1));
      expect(page.isEmpty, isFalse);
    });

    test('nothing anywhere reads as empty', () async {
      final page = await (await _repo(_FakeApi())).load();
      expect(page.isEmpty, isTrue);
      expect(page.hero, isNull);
    });
  });

  group('the rails with their own routes', () {
    test(
      'ministries come from recommended-creators, already resolved',
      () async {
        final api = _FakeApi(
          recommended: const [
            {
              'creatorId': 'c9',
              'displayName': 'Hope Assembly',
              'handle': 'hope',
              'type': 'organization',
              'isVerified': true,
            },
          ],
        );
        final page = await (await _repo(api)).load();

        expect(page.ministries.single.name, 'Hope Assembly');
        expect(page.ministries.single.isOrganisation, isTrue);
        expect(page.ministries.single.verified, isTrue);
      },
    );

    test('events carry their own creator and need no second lookup', () async {
      // Unlike every other rail, upcoming-event rows arrive with a creator
      // summary attached.
      final api = _FakeApi(
        events: [
          {
            'entityType': 'event',
            'entityId': 'e1',
            'title': 'Encounter Conference',
            'calendarStartAt': '2026-10-07T18:30:00.000Z',
            'meta': {'locationLabel': 'Lekki Conference Centre'},
            'creator': {
              'creatorId': 'c3',
              'displayName': 'Probe Creator',
              'handle': 'probe',
              'type': 'individual',
            },
          },
        ],
      );
      final page = await (await _repo(api)).load();

      final event = page.events.single;
      expect(event.title, 'Encounter Conference');
      expect(event.venue, 'Lekki Conference Centre');
      expect(event.creator.name, 'Probe Creator');
      expect(event.month, 'OCT');
      expect(
        api.searches.where(
          (b) => (b['entityTypes'] as List?)?.contains('creator') ?? false,
        ),
        isEmpty,
      );
    });

    test(
      'an event with no start time is left out rather than dated wrong',
      () async {
        final api = _FakeApi(
          events: const [
            {'entityType': 'event', 'entityId': 'e1', 'title': 'Someday'},
          ],
        );
        final page = await (await _repo(api)).load();
        expect(page.events, isEmpty);
      },
    );
  });

  group('what the page does not have', () {
    test('no topics rail, so no boost is ever requested', () async {
      // `user-app` has a "topics you follow" rail built on
      // `preferenceBoostCategorySlugs`. This app's design ends at Browse, so
      // asking for the boost would be a read nothing draws.
      final api = _FakeApi(media: [_mediaHit()], creators: [_creatorHit()]);
      await (await _repo(api)).load();

      for (final body in api.searches) {
        expect(
          body.containsKey('preferenceBoostCategorySlugs'),
          isFalse,
          reason: body.toString(),
        );
      }
    });
  });

  group('the banner', () {
    test('is the top trending item, not a sold placement', () async {
      // Search marks a promoted hit but mints no delivery token, so a real
      // sponsored slot here could never record a billable impression.
      final api = _FakeApi(
        media: [
          _mediaHit(id: 'm1', title: 'Most watched'),
          _mediaHit(id: 'm2', title: 'Next'),
        ],
        creators: [_creatorHit()],
      );
      final page = await (await _repo(api)).load();

      expect(page.hero?.id, 'm1');
      expect(page.hero?.title, 'Most watched');
    });
  });

  group('cards', () {
    test(
      'take their artwork from the key, since the url is usually null',
      () async {
        final api = _FakeApi(media: [_mediaHit()], creators: [_creatorHit()]);
        final page = await (await _repo(api)).load();
        // Without CDN config there is nothing to resolve to, and a card with no
        // artwork still renders.
        expect(page.trending.single.title, 'Sunday Service');
      },
    );

    test('a runtime becomes the corner pill', () async {
      final api = _FakeApi(
        media: [_mediaHit(duration: 150)],
        creators: [_creatorHit()],
      );
      final page = await (await _repo(api)).load();
      expect(page.trending.single.badge, '2:30');
    });

    test('and a long one reads in hours', () async {
      final api = _FakeApi(
        media: [_mediaHit(duration: 3900)],
        creators: [_creatorHit()],
      );
      final page = await (await _repo(api)).load();
      expect(page.trending.single.badge, '1h 05m');
    });

    test('keep the row they came from, so a tap can open it', () async {
      final api = _FakeApi(media: [_mediaHit()], creators: [_creatorHit()]);
      final page = await (await _repo(api)).load();
      expect(page.trending.single.source?.entityId, 'm1');
    });
  });
}
