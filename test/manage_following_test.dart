import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/subscriptions/repo/following_repo.dart';
import 'package:test_app/features/subscriptions/views/manage_following_screen.dart';
import 'package:test_app/models/subscription_models/subscription_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// Who the reader follows.
///
/// This screen ran on a hardcoded list, two entries of which carried
/// `isLive: true` for ever — which is why ministries showed as broadcasting
/// when they were not. The badge had no source at all. It has one now, and
/// it is a different question from the following list, so it is asked
/// separately: `web-feed` with `liveOnly: true`.
///
/// Shapes below are `GET /v1/discovery/following-creators` and the feed,
/// as read off staging on 2026-09-26.
class _FakeApi implements ApiService {
  _FakeApi({
    this.following = const [],
    this.liveRows = const [],
    this.recommended = const [],
    this.failFollowing = false,
    this.failLive = false,
    this.failWrite = false,
  });

  final List<Map<String, dynamic>> following;
  final List<Map<String, dynamic>> liveRows;
  final List<Map<String, dynamic>> recommended;
  final bool failFollowing;
  final bool failLive;
  final bool failWrite;

  final List<String> deleted = [];
  final List<({String path, Object? body})> posted = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.contains('following-creators')) {
      if (failFollowing) {
        throw DioException(requestOptions: RequestOptions(path: path));
      }
      return _ok(path, {
        'data': {'items': following, 'total': following.length},
      });
    }
    if (path.contains('recommended-creators')) {
      return _ok(path, {
        'data': {'items': recommended},
      });
    }
    return _ok(path, {'data': <String, dynamic>{}});
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path.contains('web-feed')) {
      if (failLive) {
        throw DioException(requestOptions: RequestOptions(path: path));
      }
      return _ok(path, {
        'data': {'items': liveRows},
      });
    }
    if (failWrite) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    posted.add((path: path, body: data));
    return _ok(path, {'data': <String, dynamic>{}});
  }

  @override
  Future<Response<T>> delete<T>(String path, {Options? options}) async {
    if (failWrite) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    deleted.add(path);
    return _ok(path, {'data': null});
  }

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: body as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Map<String, dynamic> _row(
  String id,
  String name, {
  String? latestContentAt,
  bool verified = true,
  bool upload = true,
  bool post = true,
  bool event = true,
  bool live = true,
}) => {
  'creatorId': id,
  'displayName': name,
  'handle': name.toLowerCase().replaceAll(' ', ''),
  'isVerified': verified,
  'latestContentAt': latestContentAt,
  'notifyOnUpload': upload,
  'notifyOnPost': post,
  'notifyOnEvent': event,
  'notifyOnLive': live,
};

Future<_FakeApi> _pump(WidgetTester tester, _FakeApi api) async {
  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(api);
  GetIt.instance.registerLazySingleton<FollowingRepo>(FollowingRepo.new);
  GetIt.instance.registerLazySingleton<DiscoveryRepo>(DiscoveryRepo.new);
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => const MaterialApp(home: ManageFollowingScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('lists everyone the reader actually follows', (tester) async {
    await _pump(
      tester,
      _FakeApi(following: [_row('c1', 'Living Faith'), _row('c2', 'Petra CC')]),
    );
    expect(find.text('Living Faith'), findsOneWidget);
    expect(find.text('Petra CC'), findsOneWidget);
  });

  testWidgets('nobody is live unless the feed says so', (tester) async {
    // The bug: two ministries were permanently "Live now" because the list
    // was invented. An empty live feed must mean no badges at all.
    await _pump(
      tester,
      _FakeApi(following: [_row('c1', 'Living Faith'), _row('c2', 'Petra CC')]),
    );
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('Live now'), findsNothing);
  });

  testWidgets('and the one who is live is the one the feed named', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeApi(
        following: [_row('c1', 'Living Faith'), _row('c2', 'Petra CC')],
        liveRows: [
          {
            'entityType': 'media',
            'entityId': 'm1',
            'title': 'Sunday',
            'meta': {'creatorId': 'c2'},
            'facets': {'isLiveNow': true},
          },
        ],
      ),
    );
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.textContaining('Live now'), findsOneWidget);
  });

  testWidgets('a live lookup that fails costs the badges, not the list', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeApi(following: [_row('c1', 'Living Faith')], failLive: true),
    );
    expect(find.text('Living Faith'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
  });

  testWidgets('last activity is read from latestContentAt', (tester) async {
    final threeHoursAgo = DateTime.now()
        .subtract(const Duration(hours: 3))
        .toIso8601String();
    await _pump(
      tester,
      _FakeApi(
        following: [_row('c1', 'Living Faith', latestContentAt: threeHoursAgo)],
      ),
    );
    expect(find.textContaining('Posted 3h ago'), findsOneWidget);
  });

  testWidgets('a ministry that has never posted says so', (tester) async {
    await _pump(tester, _FakeApi(following: [_row('c1', 'Living Faith')]));
    expect(find.textContaining('No posts yet'), findsOneWidget);
  });

  testWidgets('unfollowing calls the route and drops the row', (tester) async {
    final api = await _pump(
      tester,
      _FakeApi(following: [_row('c1', 'Living Faith'), _row('c2', 'Petra CC')]),
    );
    await tester.tap(find.byKey(const ValueKey('unfollow-c1')));
    await tester.pumpAndSettle();

    expect(api.deleted.single, contains('c1'));
    expect(find.text('Living Faith'), findsNothing);
    expect(find.text('Petra CC'), findsOneWidget);
  });

  testWidgets('a refused unfollow puts the row back', (tester) async {
    await _pump(
      tester,
      _FakeApi(following: [_row('c1', 'Living Faith')], failWrite: true),
    );
    await tester.tap(find.byKey(const ValueKey('unfollow-c1')));
    await tester.pumpAndSettle();
    // Still there, rather than silently gone until the next load.
    expect(find.text('Living Faith'), findsOneWidget);
  });

  testWidgets('following nobody offers real ministries to start with', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeApi(
        recommended: const [
          {
            'creatorId': 's1',
            'displayName': 'CCI International',
            'handle': 'cciinternational',
            'isVerified': true,
          },
        ],
      ),
    );
    // From recommended-creators, not a hardcoded trio.
    expect(find.text('CCI International'), findsOneWidget);
  });

  testWidgets('a failed load can be retried and left', (tester) async {
    await _pump(tester, _FakeApi(failFollowing: true));
    expect(find.text(AppStrings.feedRetry), findsOneWidget);
    expect(find.text(AppStrings.followingLoadFailed), findsOneWidget);
  });

  group('notification levels map onto the four flags', () {
    test('all four on is All', () {
      expect(
        NotifyLevel.fromFlags(
          upload: true,
          post: true,
          event: true,
          live: true,
        ),
        NotifyLevel.all,
      );
    });

    test('live alone is Live', () {
      expect(
        NotifyLevel.fromFlags(
          upload: false,
          post: false,
          event: false,
          live: true,
        ),
        NotifyLevel.live,
      );
    });

    test('all four off is None', () {
      expect(
        NotifyLevel.fromFlags(
          upload: false,
          post: false,
          event: false,
          live: false,
        ),
        NotifyLevel.none,
      );
    });

    test('anything else is Personalized, the server default', () {
      expect(
        NotifyLevel.fromFlags(
          upload: true,
          post: false,
          event: false,
          live: true,
        ),
        NotifyLevel.personalized,
      );
    });

    test('and each level round-trips through its flags', () {
      for (final level in NotifyLevel.values) {
        final f = level.toFlags();
        expect(
          NotifyLevel.fromFlags(
            upload: f['notifyOnUpload']!,
            post: f['notifyOnPost']!,
            event: f['notifyOnEvent']!,
            live: f['notifyOnLive']!,
          ),
          level,
          reason: '$level did not survive the round trip',
        );
      }
    });
  });
}
