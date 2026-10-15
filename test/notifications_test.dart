import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/notifications/data/notification_store.dart';
import 'package:test_app/features/notifications/repo/notification_repo.dart';
import 'package:test_app/features/notifications/views/notifications_screen.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/device_info_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// The bell, and what is behind it.
///
/// Shapes are `POST /v1/notification/search` as staging answered on
/// 2026-10-14 — a page-number `{data, meta}` envelope, `readAt` as the only
/// read signal, and `status` left at `pending` whether or not a row has been
/// read. Reading `status` instead of `readAt` would mark every row unread
/// for ever, which is the mistake these pin against.
class _FakeApi implements ApiService {
  _FakeApi({this.pages = const [], this.fail = false});

  /// One entry per page, in order.
  final List<List<Map<String, dynamic>>> pages;
  final bool fail;

  final List<String> posted = [];
  final List<Object?> bodies = [];
  final List<String> deleted = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (fail) throw DioException(requestOptions: RequestOptions(path: path));
    posted.add(path);
    bodies.add(data);

    if (path.contains('mark-all-read')) return _ok(path, {'updatedCount': 2});
    if (path.contains('mark-read')) return _ok(path, <String, dynamic>{});
    if (path.contains('device-token')) return _ok(path, <String, dynamic>{});

    final page =
        int.tryParse(RegExp(r'page=(\d+)').firstMatch(path)?.group(1) ?? '1') ??
        1;
    final rows = page <= pages.length ? pages[page - 1] : const [];
    return _ok(path, {
      'data': rows,
      'meta': {
        'total': pages.fold<int>(0, (n, p) => n + p.length),
        'lastPage': pages.length,
        'currentPage': page,
        'perPage': rows.length,
        'prev': page > 1 ? page - 1 : null,
        'next': page < pages.length ? page + 1 : null,
      },
    });
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    deleted.add(path);
    bodies.add(data);
    return _ok(path, <String, dynamic>{});
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

class _FakeDevice implements DeviceInfoService {
  @override
  String get deviceId => 'device-1';

  @override
  String get platform => 'android';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

String _ago(Duration d) => DateTime.now().toUtc().subtract(d).toIso8601String();

Map<String, dynamic> _row({
  required String id,
  String title = 'Upload complete',
  String type = 'FILE_UPLOAD_COMPLETE',
  String? readAt,
  Duration ago = const Duration(minutes: 5),
}) => {
  'id': id,
  'type': type,
  'templateKey': type,
  // Always `pending`, read or not — it is delivery state, not read state.
  'status': 'pending',
  'title': title,
  'body': 'Your file is ready.',
  'actionUrl': null,
  'readAt': readAt,
  'createdAt': _ago(ago),
};

Future<_FakeApi> _pump(
  WidgetTester tester, {
  List<List<Map<String, dynamic>>> pages = const [],
  bool fail = false,
  NotificationStore? store,
}) async {
  final api = _FakeApi(pages: pages, fail: fail);
  GetIt.instance
    ..allowReassignment = true
    ..registerSingleton<ApiService>(api)
    ..registerSingleton<DeviceInfoService>(_FakeDevice());
  final used = store ?? NotificationStore(repo: NotificationRepo(api: api));
  GetIt.instance.registerSingleton<NotificationStore>(used);
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (_) => MaterialApp(
        home: NotificationsScreen(
          repo: NotificationRepo(api: api),
          store: used,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  group('the list', () {
    testWidgets('pages on the query string, not in the body', (tester) async {
      // `{"page":1}` in the body is refused outright — "property page should
      // not exist" — so this pins where the paging actually goes.
      final api = await _pump(
        tester,
        pages: [
          [_row(id: 'n1')],
        ],
      );

      expect(api.posted.single, contains('page=1'));
      expect(api.posted.single, contains('limit=30'));
      expect(api.bodies.single, {
        'sort': [
          {'field': 'createdAt', 'direction': 'desc'},
        ],
      });
    });

    testWidgets('groups by the day each arrived', (tester) async {
      await _pump(
        tester,
        pages: [
          [
            _row(id: 'n1', title: 'Today thing'),
            _row(
              id: 'n2',
              title: 'Yesterday thing',
              ago: const Duration(days: 1, hours: 2),
            ),
          ],
        ],
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('an empty list says so', (tester) async {
      await _pump(tester, pages: const [[]]);
      expect(find.text(AppStrings.notificationsEmptyTitle), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      await _pump(tester, fail: true);
      expect(find.text(AppStrings.feedRetry), findsOneWidget);
    });

    testWidgets('a second page is fetched by number', (tester) async {
      final api = await _pump(
        tester,
        pages: [
          [_row(id: 'n1')],
          [_row(id: 'n2', title: 'Older thing')],
        ],
      );

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(api.posted.last, contains('page=2'));
      expect(find.text('Older thing'), findsOneWidget);
    });
  });

  group('read state', () {
    testWidgets('comes from readAt, never from status', (tester) async {
      // Both rows carry `status: pending`; only one is read.
      final store = NotificationStore();
      await _pump(
        tester,
        store: store,
        pages: [
          [
            _row(id: 'n1', title: 'Unread one'),
            _row(id: 'n2', title: 'Read one', readAt: _ago(Duration.zero)),
          ],
        ],
      );

      expect(store.unread, 1);
      expect(store.hasUnread, isTrue);
    });

    testWidgets('tapping a row marks it read and drops the count', (
      tester,
    ) async {
      final store = NotificationStore();
      final api = await _pump(
        tester,
        store: store,
        pages: [
          [_row(id: 'n1', title: 'Unread one')],
        ],
      );
      expect(store.unread, 1);

      await tester.tap(find.byKey(const ValueKey('notification-n1')));
      await tester.pumpAndSettle();

      expect(api.posted.last, contains('mark-read'));
      expect(api.bodies.last, {'notificationId': 'n1'});
      expect(store.unread, 0);
    });

    testWidgets('Mark all read is offered only when something is unread', (
      tester,
    ) async {
      await _pump(
        tester,
        pages: [
          [_row(id: 'n1', readAt: _ago(Duration.zero))],
        ],
      );
      expect(find.text(AppStrings.notificationsMarkAll), findsNothing);
    });

    testWidgets('and clears everything when it is', (tester) async {
      final store = NotificationStore();
      final api = await _pump(
        tester,
        store: store,
        pages: [
          [_row(id: 'n1'), _row(id: 'n2')],
        ],
      );

      await tester.tap(find.text(AppStrings.notificationsMarkAll));
      await tester.pumpAndSettle();

      expect(api.posted.last, contains('mark-all-read'));
      expect(store.unread, 0);
      expect(find.text(AppStrings.notificationsMarkedAll(2)), findsOneWidget);
    });
  });

  group('signing in', () {
    test('drops the previous account\'s studio', () async {
      // A session that expires never runs `logout`, so without this the next
      // person to sign in on the device inherited the last one's `creatorId`
      // — and the studio screens key off nothing else.
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      await LocalStorage.setString(LocalStorage.creatorIdKey, 'someone-else');

      final api = _LoginApi();
      GetIt.instance
        ..allowReassignment = true
        ..registerSingleton<ApiService>(api)
        ..registerSingleton<TokenStorageService>(_FakeTokens());
      addTearDown(GetIt.instance.reset);

      await AuthRepo().login(email: 'new@mail.com', password: 'x');

      expect(LocalStorage.creatorId, isNull);
      expect(LocalStorage.cachedEmail, 'new@mail.com');
    });
  });

  group('the device token', () {
    test('carries the platform and the install id', () async {
      final api = _FakeApi();
      await NotificationRepo(
        api: api,
        device: _FakeDevice(),
      ).registerDevice('fcm-token');

      expect(api.posted.single, '/v1/notification/device-token');
      expect(api.bodies.single, {
        'token': 'fcm-token',
        'platform': 'android',
        'deviceId': 'device-1',
      });
    });

    test('is removed by device id, in the body', () async {
      // Unusual for a DELETE, which is why `ApiService.delete` had to learn
      // to send one.
      final api = _FakeApi();
      await NotificationRepo(
        api: api,
        device: _FakeDevice(),
      ).unregisterDevice();

      expect(api.deleted.single, '/v1/notification/device-token');
      expect(api.bodies.single, {'deviceId': 'device-1'});
    });
  });
}

/// A login that answers the real envelope, so `AuthRepo.login` parses it.
class _LoginApi implements ApiService {
  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data:
        {
              'data': {
                'accessToken': 'a',
                'refreshToken': 'r',
                'session': {
                  'id': 's1',
                  'userId': 'u2',
                  'familyId': 'f1',
                  'expiresAt': '2026-12-01T00:00:00.000Z',
                  'createdAt': '2026-10-14T00:00:00.000Z',
                  'lastUsedAt': '2026-10-14T00:00:00.000Z',
                },
                'user': {
                  'id': 'u2',
                  'email': 'new@mail.com',
                  'firstName': 'New',
                  'lastName': 'Person',
                  'role': 'user',
                  'status': 'active',
                  'createdAt': '2026-10-14T00:00:00.000Z',
                  'updatedAt': '2026-10-14T00:00:00.000Z',
                },
              },
            }
            as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeTokens implements TokenStorageService {
  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? sessionId,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
