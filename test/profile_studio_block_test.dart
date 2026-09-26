import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/profile/views/profile_screen.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// What the You tab offers depends on one question the server answers, and
/// getting it wrong is costly in both directions: a reader who already has
/// a channel must not be invited to start another (the API refuses with a
/// 409), and a reader who has one must not be hidden from their own studio.
///
/// These drive the block through every answer, including the one a live
/// server will not produce on demand — a lookup that simply failed.
class _FakeApi implements ApiService {
  _FakeApi({required this.onGet});

  /// Answers, or throws, per path.
  final Future<Response<dynamic>> Function(String path) onGet;

  final List<String> paths = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    final response = await onGet(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: response.statusCode,
      data: response.data as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Response<dynamic> _ok(Object body) => Response<dynamic>(
  requestOptions: RequestOptions(path: '/'),
  statusCode: 200,
  data: body,
);

DioException _status(int code, String error) => DioException(
  requestOptions: RequestOptions(path: '/'),
  response: Response(
    requestOptions: RequestOptions(path: '/'),
    statusCode: code,
    data: {'success': false, 'data': null, 'error': error},
  ),
);

const _creatorBody = {
  'data': {
    'creator': {
      'id': 'c1',
      'type': 'individual',
      'handle': 'gracechapel',
      'displayName': 'Grace Chapel',
      'status': 'active',
    },
  },
};

Future<void> _pumpProfile(
  WidgetTester tester, {
  required Future<Response<dynamic>> Function(String path) onGet,
}) async {
  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(_FakeApi(onGet: onGet));
  GetIt.instance.registerLazySingleton<CreatorRepo>(CreatorRepo.new);
  GetIt.instance.registerLazySingleton<DiscoveryRepo>(DiscoveryRepo.new);
  GetIt.instance.registerLazySingleton<AuthRepo>(AuthRepo.new);
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => BlocProvider(
        create: (_) => AuthBloc(repo: GetIt.instance<AuthRepo>()),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
              GoRoute(
                path: AppRouter.creatorType,
                builder: (_, _) => const Text('ONBOARDING'),
              ),
              GoRoute(
                path: AppRouter.studio,
                builder: (_, _) => const Text('STUDIO'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  testWidgets('a reader with no channel is invited to start one', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      onGet: (path) async => path.contains('/creator/profile')
          ? throw _status(404, 'Creator profile not found')
          : _ok(const {'data': <String, dynamic>{}}),
    );

    expect(
      find.byKey(const ValueKey('profile-become-creator')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-open-studio')), findsNothing);
  });

  testWidgets('tapping the invitation opens onboarding', (tester) async {
    await _pumpProfile(
      tester,
      onGet: (path) async => path.contains('/creator/profile')
          ? throw _status(404, 'Creator profile not found')
          : _ok(const {'data': <String, dynamic>{}}),
    );

    await tester.tap(find.byKey(const ValueKey('profile-become-creator')));
    await tester.pumpAndSettle();

    expect(find.text('ONBOARDING'), findsOneWidget);
  });

  testWidgets('a reader with a channel is shown their studio instead', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      onGet: (path) async => path.contains('/creator/profile')
          ? _ok(_creatorBody)
          : _ok(const {'data': <String, dynamic>{}}),
    );

    expect(find.byKey(const ValueKey('profile-open-studio')), findsOneWidget);
    // Offering this reader a second channel would walk them into a 409.
    expect(find.byKey(const ValueKey('profile-become-creator')), findsNothing);
  });

  testWidgets('opening the studio goes there', (tester) async {
    await _pumpProfile(
      tester,
      onGet: (path) async => path.contains('/creator/profile')
          ? _ok(_creatorBody)
          : _ok(const {'data': <String, dynamic>{}}),
    );

    await tester.tap(find.byKey(const ValueKey('profile-open-studio')));
    await tester.pumpAndSettle();

    expect(find.text('STUDIO'), findsOneWidget);
  });

  testWidgets('a cached channel needs no lookup at all', (tester) async {
    await LocalStorage.setString(LocalStorage.creatorIdKey, 'c1');

    await _pumpProfile(
      tester,
      onGet: (path) async => path.contains('/creator/profile')
          ? throw _status(500, 'should not be asked')
          : _ok(const {'data': <String, dynamic>{}}),
    );

    expect(find.byKey(const ValueKey('profile-open-studio')), findsOneWidget);
  });

  testWidgets('a lookup that failed offers nothing either way', (tester) async {
    await _pumpProfile(
      tester,
      onGet: (path) async => path.contains('/creator/profile')
          ? throw _status(500, 'Internal error')
          : _ok(const {'data': <String, dynamic>{}}),
    );

    // Neither the invitation, which could end in a 409, nor a studio this
    // reader may not have.
    expect(find.byKey(const ValueKey('profile-become-creator')), findsNothing);
    expect(find.byKey(const ValueKey('profile-open-studio')), findsNothing);
    // And no empty heading left standing over nothing.
    expect(find.text(AppStrings.profileStudio), findsNothing);
  });

  testWidgets('a body carrying no creator is no channel, and lays out', (
    tester,
  ) async {
    // A 200 with nothing under `creator` is the same answer as a 404.
    await _pumpProfile(
      tester,
      onGet: (path) async => _ok(const {'data': <String, dynamic>{}}),
    );

    expect(
      find.byKey(const ValueKey('profile-become-creator')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
