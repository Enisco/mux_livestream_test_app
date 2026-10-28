import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/notifications/data/notification_store.dart';
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
  _FakeApi({required this.steps, this.attention = const []});

  final List<Map<String, dynamic>> steps;
  final List<Map<String, dynamic>> attention;

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
        'data': {'items': attention},
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

/// Where the screen asked the shell to send the reader, if it did.
class _TabJump {
  int? tab;
  int? impactTab;
  bool? openSearch;
}

Future<GoRouter> _pumpStudio(
  WidgetTester tester,
  List<Map<String, dynamic>> steps, {
  List<Map<String, dynamic>> attention = const [],
  _TabJump? jump,
}) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  await LocalStorage.setString(LocalStorage.creatorIdKey, 'c1');

  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(
    _FakeApi(steps: steps, attention: attention),
  );
  // Both bells read one store; the screens listen to it from `initState`.
  // Its first read fails without an ApiService and is swallowed, which is the
  // behaviour under test here — a bell that cannot be counted draws no dot.
  GetIt.instance.registerLazySingleton<NotificationStore>(
    NotificationStore.new,
  );
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => StudioScreen(
          onOpenTab: (tab, {int impactTab = 0, bool openSearch = false}) {
            jump
              ?..tab = tab
              ..impactTab = impactTab
              ..openSearch = openSearch;
          },
        ),
      ),
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

  testWidgets('"Set up giving" opens the Giving tab, not the web studio', (
    tester,
  ) async {
    // It was sent to the web along with team roles, which was true before
    // the Giving tab existed and has been wrong since.
    final jump = _TabJump();
    await _pumpStudio(tester, [
      _step('setup_giving'),
      _step('publish_first_content'),
    ], jump: jump);

    await tester.tap(find.byKey(const ValueKey('step-setup_giving')));
    await tester.pumpAndSettle();

    expect(jump.tab, 3);
    expect(find.text(AppStrings.studioStepOnWeb), findsNothing);
  });

  group('the attention feed', () {
    Map<String, dynamic> row(String key, int count) => {
      'key': key,
      'count': count,
    };

    testWidgets('a prayer row opens the prayers inbox', (tester) async {
      final jump = _TabJump();
      await _pumpStudio(
        tester,
        [_step('publish_first_content', complete: true)],
        attention: [row('open_prayers', 3)],
        jump: jump,
      );

      await tester.tap(find.byKey(const ValueKey('attention-open_prayers')));
      await tester.pumpAndSettle();

      expect(jump.tab, 2);
      expect(jump.impactTab, 0);
    });

    testWidgets('a testimony row opens the testimonies inbox', (tester) async {
      final jump = _TabJump();
      await _pumpStudio(
        tester,
        [_step('publish_first_content', complete: true)],
        attention: [row('pending_testimonies', 2)],
        jump: jump,
      );

      await tester.tap(
        find.byKey(const ValueKey('attention-pending_testimonies')),
      );
      await tester.pumpAndSettle();

      expect(jump.impactTab, 1);
    });

    testWidgets('a flagged-comment row opens the moderation queue', (
      tester,
    ) async {
      final jump = _TabJump();
      await _pumpStudio(
        tester,
        [_step('publish_first_content', complete: true)],
        attention: [row('flagged_comments', 1)],
        jump: jump,
      );

      await tester.tap(
        find.byKey(const ValueKey('attention-flagged_comments')),
      );
      await tester.pumpAndSettle();

      expect(jump.impactTab, 2);
    });

    testWidgets('a key this release does not know still opens Impact', (
      tester,
    ) async {
      // Landing on the first inbox beats doing nothing, which is what a row
      // whose key the client has not seen used to do.
      final jump = _TabJump();
      await _pumpStudio(
        tester,
        [_step('publish_first_content', complete: true)],
        attention: [row('something_new', 4)],
        jump: jump,
      );

      await tester.tap(find.byKey(const ValueKey('attention-something_new')));
      await tester.pumpAndSettle();

      expect(jump.tab, 2);
      expect(jump.impactTab, 0);
    });
  });

  testWidgets('the search icon opens Content with its field up', (
    tester,
  ) async {
    // What it searches is the Content tab's list, so it goes there rather
    // than owning a second search of its own.
    final jump = _TabJump();
    await _pumpStudio(tester, [
      _step('publish_first_content', complete: true),
      _step('complete_profile', complete: true),
    ], jump: jump);

    await tester.tap(find.byKey(const ValueKey('studio-search')));
    await tester.pumpAndSettle();

    expect(jump.tab, 1);
    expect(jump.openSearch, isTrue);
  });

  testWidgets('"Full analytics" names the web studio, not "not built yet"', (
    tester,
  ) async {
    await _pumpStudio(tester, [
      _step('publish_first_content', complete: true),
      _step('complete_profile', complete: true),
    ]);

    await tester.tap(find.text(AppStrings.studioFullAnalytics));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.studioWebAnalyticsNote), findsOneWidget);
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
