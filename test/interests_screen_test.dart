import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/features/onboarding/views/interests_screen.dart';
import 'package:test_app/features/onboarding/views/widgets/interest_chip.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'helpers/load_app_fonts.dart';

/// The interests step, drawn from the live taxonomy.
///
/// What this is really guarding: a chip's label and the slug it sends are the
/// same row of `GET /v1/user/categories`, so they cannot disagree. The old
/// screen hardcoded the design's eleven labels and kept a hand-written
/// label→slug table; four chips mapped to nothing and sent nothing when
/// picked, and four real categories had no chip at all.
class _FakeApi implements ApiService {
  _FakeApi({required this.rows, this.failCategories = false});

  final List<Map<String, dynamic>> rows;
  final bool failCategories;

  final List<Map<String, dynamic>> patched = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (failCategories) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {'data': rows},
              }
              as T,
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    patched.add(data! as Map<String, dynamic>);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Four rows of the real taxonomy, one of them retired.
const _rows = <Map<String, dynamic>>[
  {'slug': 'sermons', 'name': 'Sermons', 'sortOrder': 2, 'isActive': true},
  {'slug': 'worship', 'name': 'Worship', 'sortOrder': 1, 'isActive': true},
  {
    'slug': 'testimonies',
    'name': 'Testimonies',
    'sortOrder': 7,
    'isActive': true,
  },
  {'slug': 'retired', 'name': 'Retired', 'sortOrder': 3, 'isActive': false},
];

Future<_FakeApi> _pump(
  WidgetTester tester, {
  List<Map<String, dynamic>> rows = _rows,
  bool failCategories = false,
}) async {
  final api = _FakeApi(rows: rows, failCategories: failCategories);
  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(api);
  GetIt.instance.registerLazySingleton<CreatorRepo>(CreatorRepo.new);
  GetIt.instance.registerLazySingleton<OnboardingRepo>(OnboardingRepo.new);
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const InterestsScreen()),
            GoRoute(
              path: AppRouter.discoverySource,
              builder: (_, _) => const Text('NEXT'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Iterable<String> _chipLabels(WidgetTester tester) => tester
    .widgetList<InterestChip>(find.byType(InterestChip))
    .map((c) => c.label);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the chips are the API taxonomy, in its own order', (
    tester,
  ) async {
    await _pump(tester);
    // Worship (1) before Sermons (2) before Testimonies (7) — payload order
    // was Sermons first, so this really is sortOrder and not luck.
    expect(_chipLabels(tester), ['Worship', 'Sermons', 'Testimonies']);
  });

  testWidgets('a retired category is not offered', (tester) async {
    await _pump(tester);
    expect(_chipLabels(tester), isNot(contains('Retired')));
  });

  testWidgets('picking chips sends their slugs, not their labels', (
    tester,
  ) async {
    final api = await _pump(tester);

    await tester.tap(find.text('Worship'));
    await tester.tap(find.text('Testimonies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.patched, hasLength(1));
    expect(api.patched.single['categorySlugs'], ['worship', 'testimonies']);
  });

  testWidgets('testimonies is reachable at all, which it never used to be', (
    tester,
  ) async {
    // It is one of the four categories the design had no chip for.
    final api = await _pump(tester);
    await tester.tap(find.text('Testimonies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(api.patched.single['categorySlugs'], ['testimonies']);
  });

  testWidgets('unpicking a chip takes its slug back off', (tester) async {
    final api = await _pump(tester);
    await tester.tap(find.text('Worship'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worship'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // Nothing picked, so nothing is sent at all.
    expect(api.patched, isEmpty);
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('a failed lookup leaves the step skippable, not stuck', (
    tester,
  ) async {
    await _pump(tester, failCategories: true);
    expect(find.byType(InterestChip), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('NEXT'), findsOneWidget);
  });
}
