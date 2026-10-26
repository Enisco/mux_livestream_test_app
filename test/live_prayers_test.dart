import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/views/widgets/live_prayers_sheet.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// The prayer requests sent during a broadcast, so the broadcaster can pray
/// for them on air.
///
/// Until 2026-10-26 the studio reported `metrics.prayers.count` and nothing
/// readable. Two things shape the sheet:
///
/// - **There is no `isAnonymous`.** The whole point is to pray for a *named*
///   person; a missing name is failed hydration, not a choice, so it falls
///   back neutrally rather than being labelled anonymous.
/// - **The count arrives by socket, the bodies do not** — so the panel is a
///   request of its own, and it is keyset, newest first.
class _FakeApi implements ApiService {
  _FakeApi({this.fails = false});

  final bool fails;
  final List<({String path, Map<String, dynamic>? query})> gets = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    gets.add((path: path, query: queryParameters));
    if (fails) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 403,
        ),
      );
    }
    final second = queryParameters?['cursor'] != null;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data:
          {
                'data': {
                  'items': second
                      ? [_row('p99', 'A later page', name: 'Tunde')]
                      : [
                          _row('p1', 'Please pray for my mother', name: 'Ada'),
                          // Hydration can fail; the name is absent, not false.
                          _row('p2', 'Pray for my exams'),
                        ],
                  'total': 3,
                  'nextCursor': second ? null : 'p2',
                },
              }
              as T,
    );
  }

  static Map<String, dynamic> _row(String id, String body, {String? name}) => {
    'id': id,
    'body': body,
    'status': 'open',
    'createdAt': '2026-10-26T09:00:00.000Z',
    'requester': name == null ? null : {'displayName': name},
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<_FakeApi> _open(WidgetTester tester, {bool fails = false}) async {
  final api = _FakeApi(fails: fails);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLivePrayersSheet(
                context,
                mediaId: 'm1',
                repo: LivestreamRepo(api),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('it reads the live namespace, not the creator inbox', (
    tester,
  ) async {
    // The inbox is authorised for owner | admin | editor; the studio is also
    // held by a streamer, so filtering the inbox would ship a list the
    // person actually broadcasting cannot open.
    final api = await _open(tester);

    expect(api.gets.single.path, '/v1/media/live/streams/m1/prayers');
    expect(api.gets.single.query!['limit'], 25);
  });

  testWidgets('the bodies are shown, with the count beside the title', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text(AppStrings.livePrayersTitle), findsOneWidget);
    expect(find.text(AppStrings.livePrayersCount(3)), findsOneWidget);
    expect(find.text('Please pray for my mother'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('a missing name is not called anonymous', (tester) async {
    // There is no anonymous submission on the platform, so labelling one
    // would promise a feature that does not exist.
    await _open(tester);

    expect(find.text(AppStrings.livePrayersAnonymous), findsOneWidget);
    expect(find.textContaining('Anonymous'), findsNothing);
  });

  testWidgets('a refusal offers a retry rather than an empty panel', (
    tester,
  ) async {
    await _open(tester, fails: true);

    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.text(AppStrings.livePrayersEmpty), findsNothing);
  });

  testWidgets('the next page is asked for with the cursor, once', (
    tester,
  ) async {
    final api = await _open(tester);

    await tester.drag(find.text('Pray for my exams'), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(api.gets.length, 2);
    expect(api.gets.last.query!['cursor'], 'p2');
    expect(find.text('A later page'), findsOneWidget);
  });
}
