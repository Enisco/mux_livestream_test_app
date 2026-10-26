import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/settings/views/hidden_creators_screen.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// Muted and blocked, and the only way back from either.
///
/// **The blocked list is not optional.** A blocked creator is hidden from
/// every surface a viewer could rediscover them on — feeds, Explore, search,
/// even their own channel page — so without this screen the `DELETE` is
/// unreachable and a block can never be lifted.
///
/// The asymmetry between the two halves is what these pin: mute keeps the
/// follow and leaves the channel reachable, block drops the follow and takes
/// the channel away, and **unblocking does not re-follow**.
class _FakeApi implements ApiService {
  _FakeApi({this.listFails = false, this.deleteFails = false});

  final bool listFails;
  final bool deleteFails;

  final List<String> got = [];
  final List<String> deleted = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    got.add(path);
    if (listFails) throw _boom(path);
    final blocked = path.contains('blocked');
    return _ok(path, {
      'items': [
        for (final name
            in blocked
                ? const ['Bad Actor Ministries']
                : const ['Grace Chapel', 'Hillside Fellowship', 'Rock City'])
          {
            'creatorId': 'c-${name.hashCode}',
            'creator': {
              'displayName': name,
              'handle': name.toLowerCase().replaceAll(' ', ''),
            },
            blocked ? 'blockedAt' : 'mutedAt': '2026-10-20T09:00:00.000Z',
          },
      ],
    });
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    deleted.add(path);
    if (deleteFails) throw _boom(path);
    return _ok(path, const <String, dynamic>{});
  }

  DioException _boom(String path) => DioException(
    requestOptions: RequestOptions(path: path),
    response: Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 500,
    ),
  );

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

EngagementStore _store() => EngagementStore(
  toggle:
      ({
        required String targetType,
        required String targetId,
        required String interactionType,
      }) async => true,
  setFollowing: (String creatorId, {required bool follow}) async {},
);

Future<(_FakeApi, EngagementStore)> _pump(
  WidgetTester tester, {
  bool listFails = false,
  bool deleteFails = false,
  Size size = const Size(390, 844),
}) async {
  final api = _FakeApi(listFails: listFails, deleteFails: deleteFails);
  final store = _store();

  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: HiddenCreatorsScreen(
          repo: EngagementRepo(api: api),
          store: store,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (api, store);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('both lists are read at once, so the tabs do not wait', (
    tester,
  ) async {
    final (api, _) = await _pump(tester);

    expect(api.got, [
      '/v1/discovery/muted-creators',
      '/v1/discovery/blocked-creators',
    ]);
  });

  testWidgets('it opens on muted and switches to blocked', (tester) async {
    await _pump(tester);

    expect(find.text('Grace Chapel'), findsOneWidget);
    expect(find.text('Bad Actor Ministries'), findsNothing);

    await tester.tap(find.text(AppStrings.hiddenBlockedTab));
    await tester.pumpAndSettle();

    expect(find.text('Bad Actor Ministries'), findsOneWidget);
    expect(find.text('Grace Chapel'), findsNothing);
  });

  testWidgets('every row of a list is seeded, not just the first', (
    tester,
  ) async {
    // The store is what every other surface reads, so a partial seed leaves
    // cards offering to mute a creator who is already muted.
    final (_, store) = await _pump(tester);

    expect(store.isMuted('c-${'Grace Chapel'.hashCode}'), isTrue);
    expect(store.isMuted('c-${'Hillside Fellowship'.hashCode}'), isTrue);
    expect(store.isMuted('c-${'Rock City'.hashCode}'), isTrue);
  });

  testWidgets('unmuting calls the delete and drops the row', (tester) async {
    final (api, store) = await _pump(tester);
    final id = 'c-${'Grace Chapel'.hashCode}';

    await tester.tap(find.byKey(ValueKey('restore-$id')));
    await tester.pumpAndSettle();

    expect(api.deleted.single, '/v1/discovery/muted-creators/$id');
    expect(find.text('Grace Chapel'), findsNothing);
    expect(store.isMuted(id), isFalse);
  });

  testWidgets('unblocking does not re-follow', (tester) async {
    final (api, store) = await _pump(tester);
    final id = 'c-${'Bad Actor Ministries'.hashCode}';

    await tester.tap(find.text(AppStrings.hiddenBlockedTab));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('restore-$id')));
    await tester.pumpAndSettle();

    expect(api.deleted.single, '/v1/discovery/blocked-creators/$id');
    expect(store.isBlocked(id), isFalse);
    // Making them visible again is all it does; the viewer never asked to
    // follow them twice.
    expect(store.isFollowing(id, fallback: false), isFalse);
  });

  testWidgets('a refused restore puts the row back', (tester) async {
    final (_, store) = await _pump(tester, deleteFails: true);
    final id = 'c-${'Grace Chapel'.hashCode}';

    await tester.tap(find.byKey(ValueKey('restore-$id')));
    await tester.pumpAndSettle();

    expect(find.text('Grace Chapel'), findsOneWidget);
    expect(store.isMuted(id), isTrue);
    expect(find.text(AppStrings.cardActionFailed), findsOneWidget);
  });

  testWidgets('and puts it back where it was, not at the end', (tester) async {
    await _pump(tester, deleteFails: true);
    final id = 'c-${'Hillside Fellowship'.hashCode}';

    await tester.tap(find.byKey(ValueKey('restore-$id')));
    await tester.pumpAndSettle();

    // The middle row of three stays the middle row.
    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where(
          (t) => const [
            'Grace Chapel',
            'Hillside Fellowship',
            'Rock City',
          ].contains(t),
        )
        .toList();
    expect(rows, ['Grace Chapel', 'Hillside Fellowship', 'Rock City']);
  });

  testWidgets('a read that fails offers a retry rather than an empty list', (
    tester,
  ) async {
    // "Nobody is muted" and "we could not find out" are different answers,
    // and only one of them has a way forward.
    await _pump(tester, listFails: true);

    expect(find.byType(ErrorStateView), findsOneWidget);
    expect(find.text(AppStrings.hiddenMutedEmptyTitle), findsNothing);
  });

  testWidgets('long ministry names do not burst the row on a 320pt phone', (
    tester,
  ) async {
    await _pump(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
  });
}
