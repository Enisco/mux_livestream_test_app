import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/views/studio_screen.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// Where the getting-started rows actually go.
///
/// Every one of them used to answer "not built yet", which was wrong twice
/// over: the destinations all exist, and a checklist whose steps cannot be
/// started is worse than no checklist at all. Reported from the app against
/// "Upload your first sermon", which should open content creation.
///
/// Step keys are `GET /v1/creator/{id}/dashboard/getting-started` on staging,
/// 2026-09-26.
class _FakeApi implements ApiService {
  _FakeApi({required this.steps});

  final List<Map<String, dynamic>> steps;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final body = switch (path) {
      _ when path.contains('getting-started') => {
        'data': {'steps': steps},
      },
      _ when path.contains('attention') => {
        'data': {'items': <dynamic>[]},
      },
      // The Create sheet is gated on these, so a context without them
      // would offer nothing to create and the test would prove nothing.
      _ when path.contains('context') => {
        'data': {
          'creator': {
            'id': 'c1',
            'displayName': 'Food for Thought',
            'handle': 'food',
          },
          'membership': {'role': 'owner', 'isPrincipalOwner': true},
          'capabilities': {'canCreateMedia': true, 'canCreateLivestream': true},
        },
      },
      _ => {'data': <String, dynamic>{}},
    };
    return _ok(path, body);
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => _ok(path, {'data': <String, dynamic>{}});

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: body as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<GoRouter> _pumpStudio(
  WidgetTester tester,
  List<Map<String, dynamic>> steps,
) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  await LocalStorage.setString(LocalStorage.creatorIdKey, 'c1');

  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(_FakeApi(steps: steps));
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const StudioScreen()),
      GoRoute(
        path: AppRouter.creatorPhoto,
        builder: (_, _) => const Text('POLISH FLOW'),
      ),
    ],
  );
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Map<String, dynamic> _step(
  String key, {
  bool complete = false,
  bool applicable = true,
}) => {'key': key, 'complete': complete, 'applicable': applicable};

void main() {
  setUpAll(loadAppFonts);

  testWidgets('"Upload your first sermon" opens content creation', (
    tester,
  ) async {
    // The reported bug: this showed "Upload your first sermon is not built
    // yet" instead of taking the creator anywhere.
    await _pumpStudio(tester, [
      _step('complete_profile', complete: true),
      _step('publish_first_content'),
    ]);

    await tester.tap(find.byKey(const ValueKey('step-publish_first_content')));
    await tester.pumpAndSettle();

    expect(find.textContaining('not built'), findsNothing);
    // The same sheet Quick upload opens, so the choices are the real ones.
    expect(find.text(AppStrings.createVideo), findsOneWidget);
  });

  testWidgets('"Complete your profile" opens the polish flow', (tester) async {
    await _pumpStudio(tester, [
      _step('complete_profile'),
      _step('publish_first_content'),
    ]);

    await tester.tap(find.byKey(const ValueKey('step-complete_profile')));
    await tester.pumpAndSettle();

    expect(find.text('POLISH FLOW'), findsOneWidget);
  });

  testWidgets('a finished profile step still opens it, for editing', (
    tester,
  ) async {
    await _pumpStudio(tester, [
      _step('complete_profile', complete: true),
      _step('publish_first_content'),
    ]);

    await tester.tap(find.byKey(const ValueKey('step-complete_profile')));
    await tester.pumpAndSettle();

    expect(find.text('POLISH FLOW'), findsOneWidget);
  });

  testWidgets('a web-studio step says so rather than "not built yet"', (
    tester,
  ) async {
    await _pumpStudio(tester, [
      _step('invite_team'),
      _step('publish_first_content'),
    ]);

    await tester.tap(find.byKey(const ValueKey('step-invite_team')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.studioStepOnWeb), findsOneWidget);
    expect(find.textContaining('not built'), findsNothing);
  });

  testWidgets('a step that does not apply is not shown at all', (tester) async {
    // `invite_team` comes back complete:true, applicable:false for a solo
    // creator — showing it would read as a step they had finished.
    await _pumpStudio(tester, [
      _step('publish_first_content'),
      _step('invite_team', complete: true, applicable: false),
    ]);

    expect(find.byKey(const ValueKey('step-invite_team')), findsNothing);
    expect(
      find.byKey(const ValueKey('step-publish_first_content')),
      findsOneWidget,
    );
  });

  testWidgets('the checklist is hidden once every step is done', (
    tester,
  ) async {
    await _pumpStudio(tester, [
      _step('complete_profile', complete: true),
      _step('publish_first_content', complete: true),
    ]);

    expect(find.byKey(const ValueKey('step-complete_profile')), findsNothing);
    // The dashboard proper takes over.
    expect(find.text(AppStrings.studioToday), findsOneWidget);
  });
}
