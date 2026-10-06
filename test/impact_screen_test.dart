import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/impact_repo.dart';
import 'package:test_app/features/creator/views/impact_screen.dart';
import 'package:test_app/features/creator/views/widgets/impact_parts.dart';
import 'package:test_app/features/creator/views/widgets/impact_sheets.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/models/creator_models/impact_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// The creator's Impact inbox — prayers, testimonies and the comment
/// moderation queue.
///
/// The contracts under test are the creator-side ones in
/// `docs/API_INTEGRATION_GUIDES/client-creator-and-dashboard-integration.md`,
/// which are a different family from the viewer-side engagement routes. Most
/// of what these guard is the handful of places where doing the obvious thing
/// would be wrong: a status slug that is not the one the design says, an
/// unassign that must travel as an explicit `null`, a queue that holds only
/// two of a comment's states, and an identity the gateway has deliberately
/// masked.
class _FakeApi implements ApiService {
  _FakeApi({
    this.prayers = const [],
    this.testimonies = const [],
    this.comments = const [],
    this.assignees = const [],
    this.prayerSummary = const {},
    this.testimonySummary = const {},
    this.prayerNextCursor,
    this.nextPage,
    this.failList = false,
    this.failWrite = false,
    this.failSummary = false,
    this.total,
  });

  final List<Map<String, dynamic>> prayers;
  final List<Map<String, dynamic>> testimonies;
  final List<Map<String, dynamic>> comments;
  final List<Map<String, dynamic>> assignees;
  final Map<String, dynamic> prayerSummary;
  final Map<String, dynamic> testimonySummary;
  final String? prayerNextCursor;
  final int? nextPage;
  final bool failList;
  bool failWrite;
  final bool failSummary;

  /// `meta.total` — how many rows match in all, not how many this page holds.
  final int? total;

  /// Every call, so a test can assert what was asked and what was sent.
  final List<(String, Map<String, dynamic>?)> gets = [];
  final List<(String, Object?)> patches = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    gets.add((path, queryParameters));
    if (failList && !path.endsWith('summary') && !path.endsWith('assignees')) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    if (path.endsWith('summary') && failSummary) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    if (path.endsWith('prayers/summary')) return _ok(path, prayerSummary);
    if (path.endsWith('testimonies/summary')) {
      return _ok(path, testimonySummary);
    }
    if (path.endsWith('assignees')) return _ok(path, {'items': assignees});
    if (path.endsWith('/prayers')) {
      return _ok(path, {
        'items': prayers,
        'total': prayers.length,
        'nextCursor': prayerNextCursor,
      });
    }
    if (path.endsWith('/testimonies')) return _paged(path, testimonies);
    if (path.endsWith('/comments')) return _paged(path, comments);
    return _ok(path, const <String, dynamic>{});
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    patches.add((path, data));
    if (failWrite) {
      throw DioException(requestOptions: RequestOptions(path: path));
    }
    return _ok(path, const <String, dynamic>{});
  }

  Response<T> _ok<T>(String path, Object body) => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: {'data': body} as T,
  );

  Response<T> _paged<T>(String path, List<Map<String, dynamic>> rows) =>
      _ok(path, {
        'data': rows,
        'meta': {'total': total ?? rows.length, 'next': nextPage},
      });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Map<String, dynamic> _prayer({
  String id = 'p1',
  String status = 'open',
  Map<String, dynamic>? assignee,
  Map<String, dynamic>? contentRef,
  String? contentRefTitle,
}) => {
  'id': id,
  'body': 'Please pray for my mother.',
  'status': status,
  'assignedToUserId': assignee?['userId'],
  'contentRef': contentRef,
  'contentRefTitle': contentRefTitle,
  'createdAt': DateTime.now()
      .subtract(const Duration(hours: 2))
      .toIso8601String(),
  'requester': {'userId': 'u1', 'displayName': 'Ada O.'},
  'assignee': assignee,
};

Map<String, dynamic> _testimony({
  String id = 't1',
  String status = 'pending',
  bool anonymous = false,
  List<String> tags = const ['healing'],
}) => {
  'id': id,
  'body': 'God restored what I thought was gone.',
  'status': status,
  'displayAsAnonymous': anonymous,
  'impactTags': tags,
  'createdAt': DateTime.now()
      .subtract(const Duration(hours: 3))
      .toIso8601String(),
  'author': anonymous
      ? {'userId': null, 'displayName': 'Anonymous user', 'anonymous': true}
      : {'userId': 'u1', 'displayName': 'Cynthia Morgan', 'anonymous': false},
};

Map<String, dynamic> _comment({
  String id = 'c1',
  String status = 'flagged',
  String? targetTitle = 'Walking by faith',
  int replyCount = 0,
  String? parentCommentId,
}) => {
  'parentCommentId': parentCommentId,
  'id': id,
  'body': 'This blessed me so much this morning.',
  'status': status,
  'targetType': 'media',
  'targetId': 'm1',
  'targetTitle': targetTitle,
  'replyCount': replyCount,
  'createdAt': DateTime.now()
      .subtract(const Duration(hours: 1))
      .toIso8601String(),
  'author': {'userId': 'u2', 'displayName': 'Sarah A.'},
};

DashboardContext _context() => const DashboardContext(
  creatorId: 'c1',
  displayName: 'Grace Chapel',
  handle: 'gracechapel',
  role: 'owner',
  isPrincipalOwner: true,
  capabilities: {},
);

Future<_FakeApi> _pump(
  WidgetTester tester,
  _FakeApi api, {
  bool withContext = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  await LocalStorage.setString(LocalStorage.creatorIdKey, 'c1');

  await GetIt.instance.reset();
  GetIt.instance.registerSingleton<ApiService>(api);
  addTearDown(GetIt.instance.reset);

  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (_) => MaterialApp(
        home: ImpactScreen(
          repo: ImpactRepo(api: api),
          context: withContext ? _context() : null,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

/// Open the filter sheet and pick [label].
Future<void> _filter(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('impact-filter')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('choice-$label')));
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('impact-tab-$label')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the shell', () {
    testWidgets('leads with the three things a congregation sends', (
      tester,
    ) async {
      await _pump(tester, _FakeApi());
      expect(find.text(AppStrings.impactTitle), findsOneWidget);
      expect(find.text(AppStrings.impactSubtitle), findsOneWidget);
      for (final label in ImpactTabs.labels) {
        expect(find.textContaining(label), findsWidgets, reason: label);
      }
      expect(find.text('Grace Chapel'), findsOneWidget);
    });

    testWidgets('a count that could not be read shows no number at all', (
      tester,
    ) async {
      // Losing the summary must not lose the list, and a pill that cannot be
      // counted shows its label rather than a zero it cannot stand behind.
      await _pump(tester, _FakeApi(prayers: [_prayer()], failSummary: true));
      expect(find.text(AppStrings.impactTabPrayer), findsOneWidget);
      expect(find.textContaining('· 0'), findsNothing);
      expect(find.byType(PrayerRequestCard), findsOneWidget);
    });

    testWidgets('a real zero is shown as a zero', (tester) async {
      await _pump(tester, _FakeApi(prayerSummary: const {'open': 0}));
      expect(find.text('${AppStrings.impactTabPrayer} · 0'), findsOneWidget);
    });

    testWidgets('the prayer pill counts open ones, not every one', (
      tester,
    ) async {
      // `summary.open` is the attention number; `closed` is history and
      // would make a cleared inbox look like forty things to do.
      await _pump(
        tester,
        _FakeApi(
          prayers: [_prayer()],
          prayerSummary: const {'open': 12, 'closed': 40, 'assigned': 9},
        ),
      );
      expect(find.text('${AppStrings.impactTabPrayer} · 12'), findsOneWidget);
    });

    testWidgets('and the testimony pill counts what is waiting', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeApi(
          testimonies: [_testimony()],
          testimonySummary: const {
            'received': 47,
            'pending': 7,
            'approved': 14,
          },
        ),
      );
      await _tab(tester, AppStrings.impactTabTestimony);
      expect(find.text('${AppStrings.impactTabTestimony} · 7'), findsOneWidget);
    });

    testWidgets('only the tab in view is fetched', (tester) async {
      final api = await _pump(tester, _FakeApi());
      expect(api.gets.where((g) => g.$1.endsWith('/comments')), isEmpty);

      await _tab(tester, AppStrings.impactTabComments);
      expect(api.gets.where((g) => g.$1.endsWith('/comments')), isNotEmpty);
    });

    testWidgets('pull-to-refresh refetches, even on an empty tab', (
      tester,
    ) async {
      // An empty list is shorter than the viewport, so without
      // AlwaysScrollableScrollPhysics a creator waiting on their first
      // prayer could not pull to refresh at all.
      final api = await _pump(tester, _FakeApi());
      final before = api.gets.where((g) => g.$1.endsWith('/prayers')).length;

      final pull = await tester.startGesture(
        tester.getCenter(find.text(AppStrings.impactSubtitle)),
      );
      // RefreshIndicator fires past a quarter of the viewport, which is tall
      // in this test view.
      for (var i = 0; i < 16; i++) {
        await pull.moveBy(const Offset(0, 40));
        await tester.pump();
      }
      await pull.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        api.gets.where((g) => g.$1.endsWith('/prayers')).length,
        greaterThan(before),
      );
    });

    testWidgets('a failed load can be retried', (tester) async {
      await _pump(tester, _FakeApi(failList: true));
      expect(find.text(AppStrings.feedRetry), findsOneWidget);
    });
  });

  group('prayers', () {
    testWidgets('render body, sender and age from the gateway', (tester) async {
      await _pump(tester, _FakeApi(prayers: [_prayer()]));
      expect(find.text('Please pray for my mother.'), findsOneWidget);
      expect(find.text('Ada O.'), findsOneWidget);
      expect(find.text('2 hours ago'), findsOneWidget);
    });

    testWidgets('an unassigned one says so', (tester) async {
      await _pump(tester, _FakeApi(prayers: [_prayer()]));
      expect(find.text(AppStrings.prayerNotAssigned), findsOneWidget);
    });

    testWidgets('an assigned one names who has it, and their role', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeApi(
          prayers: [
            _prayer(
              assignee: const {
                'userId': 'u9',
                'displayName': 'Pastor Grace',
                'role': 'editor',
              },
            ),
          ],
        ),
      );
      expect(
        find.text(AppStrings.prayerAssignedTo('Pastor Grace (editor)')),
        findsOneWidget,
      );
    });

    testWidgets('one with no contentRef came from the wall', (tester) async {
      await _pump(tester, _FakeApi(prayers: [_prayer()]));
      expect(find.text(AppStrings.prayerFromWall), findsOneWidget);
    });

    testWidgets('one raised on a sermon names the sermon', (tester) async {
      await _pump(
        tester,
        _FakeApi(
          prayers: [
            _prayer(
              contentRef: const {'targetType': 'media', 'targetId': 'm1'},
              contentRefTitle: 'Walking by Faith',
            ),
          ],
        ),
      );
      expect(
        find.text(AppStrings.prayerOnContent('Walking by Faith')),
        findsOneWidget,
      );
    });

    testWidgets('an unresolved title falls back to the kind of thing', (
      tester,
    ) async {
      // The title goes missing when the content was deleted or belongs to
      // another creator. That is normal — the row must not blank or error.
      await _pump(
        tester,
        _FakeApi(
          prayers: [
            _prayer(contentRef: const {'targetType': 'post', 'targetId': 'x1'}),
          ],
        ),
      );
      expect(find.text(AppStrings.prayerFromType('post')), findsOneWidget);
      expect(find.byType(PrayerRequestCard), findsOneWidget);
    });

    testWidgets('the filter asks the server for that status', (tester) async {
      final api = await _pump(tester, _FakeApi(prayers: [_prayer()]));
      await _filter(tester, AppStrings.prayerStatePrayed);

      final asked = api.gets.lastWhere((g) => g.$1.endsWith('/prayers'));
      expect(asked.$2?['status'], 'prayed_for');
    });

    testWidgets('and the closed filter sends the slug the API uses', (
      tester,
    ) async {
      // The design calls this "Resolved" in the sheet and "Closed" above the
      // list; the API calls it `closed` and accepts nothing else.
      final api = await _pump(tester, _FakeApi(prayers: [_prayer()]));
      await _filter(tester, AppStrings.prayerStateResolved);

      final asked = api.gets.lastWhere((g) => g.$1.endsWith('/prayers'));
      expect(asked.$2?['status'], 'closed');
    });

    testWidgets('an empty inbox says so rather than looking broken', (
      tester,
    ) async {
      await _pump(tester, _FakeApi());
      expect(find.text(AppStrings.impactNoPrayers), findsOneWidget);
    });

    testWidgets('the next page follows nextCursor, never an offset', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        _FakeApi(prayers: [_prayer()], prayerNextCursor: 'cur-1'),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final asked = api.gets.lastWhere((g) => g.$1.endsWith('/prayers'));
      expect(asked.$2?['cursor'], 'cur-1');
      expect(asked.$2?.containsKey('page'), isFalse);
    });
  });

  group('deciding on a prayer', () {
    testWidgets('an open one is marked prayed for', (tester) async {
      final api = await _pump(tester, _FakeApi(prayers: [_prayer()]));
      await tester.tap(find.text(AppStrings.prayerMarkPrayed));
      await tester.pumpAndSettle();

      expect(api.patches.single.$1, '/v1/creator/engagement/prayers/p1');
      expect(api.patches.single.$2, {'status': 'prayed_for'});
      expect(find.text(AppStrings.prayerMarkedPrayed), findsOneWidget);
      // The list is filtered to open, so the row leaves it.
      expect(find.byType(PrayerRequestCard), findsNothing);
    });

    testWidgets('a prayed-for one is resolved, not prayed for again', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        _FakeApi(prayers: [_prayer(status: 'prayed_for')]),
      );
      expect(find.text(AppStrings.prayerResolve), findsOneWidget);

      await tester.tap(find.text(AppStrings.prayerResolve));
      await tester.pumpAndSettle();
      expect(api.patches.single.$2, {'status': 'closed'});
    });

    testWidgets('a closed one offers no button at all', (tester) async {
      await _pump(tester, _FakeApi(prayers: [_prayer(status: 'closed')]));
      expect(find.byType(ImpactAction), findsNothing);
      expect(find.byKey(const ValueKey('prayer-more-p1')), findsOneWidget);
    });

    testWidgets('and the design\'s Undo writes the old status back', (
      tester,
    ) async {
      final api = await _pump(tester, _FakeApi(prayers: [_prayer()]));
      await tester.tap(find.text(AppStrings.prayerMarkPrayed));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerRequestCard), findsNothing);

      await tester.tap(find.text(AppStrings.impactUndo));
      await tester.pumpAndSettle();

      expect(api.patches.map((p) => p.$2).toList(), [
        {'status': 'prayed_for'},
        {'status': 'open'},
      ]);
      expect(find.byType(PrayerRequestCard), findsOneWidget);
      expect(find.text(AppStrings.prayerUndone), findsOneWidget);
    });

    testWidgets('an Undo that fails leaves the row where the server has it', (
      tester,
    ) async {
      // The first write landed; only the reversal failed, so putting the
      // card back would show a state the server does not have.
      final api = _FakeApi(prayers: [_prayer()]);
      await _pump(tester, api);
      await tester.tap(find.text(AppStrings.prayerMarkPrayed));
      await tester.pumpAndSettle();

      api.failWrite = true;
      await tester.tap(find.text(AppStrings.impactUndo));
      await tester.pumpAndSettle();

      expect(find.byType(PrayerRequestCard), findsNothing);
      expect(find.text(AppStrings.impactActionFailed), findsOneWidget);
    });

    testWidgets('a write that fails puts the row back and says so', (
      tester,
    ) async {
      await _pump(tester, _FakeApi(prayers: [_prayer()], failWrite: true));
      await tester.tap(find.text(AppStrings.prayerMarkPrayed));
      await tester.pumpAndSettle();

      expect(find.byType(PrayerRequestCard), findsOneWidget);
      expect(find.text(AppStrings.impactActionFailed), findsOneWidget);
    });

    testWidgets('the menu offers only the steps this state can take', (
      tester,
    ) async {
      await _pump(tester, _FakeApi(prayers: [_prayer()]));
      await tester.tap(find.byKey(const ValueKey('prayer-more-p1')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.prayerMenuAssign), findsOneWidget);
      expect(find.text(AppStrings.prayerMenuResolve), findsOneWidget);
      expect(find.text(AppStrings.prayerMenuReopen), findsNothing);
    });

    testWidgets('a closed one can be re-opened but not resolved', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        _FakeApi(prayers: [_prayer(status: 'closed')]),
      );
      await tester.tap(find.byKey(const ValueKey('prayer-more-p1')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.prayerMenuResolve), findsNothing);

      await tester.tap(find.text(AppStrings.prayerMenuReopen));
      await tester.pumpAndSettle();
      expect(api.patches.single.$2, {'status': 'open'});
    });
  });

  group('assigning a prayer', () {
    const team = [
      {'userId': 'u9', 'displayName': 'Pastor Grace', 'role': 'editor'},
    ];

    testWidgets('the picker comes from the assignees route', (tester) async {
      // Not the general member list: only owners, admins and editors can be
      // assigned, so the team route would offer people the write refuses.
      final api = await _pump(
        tester,
        _FakeApi(prayers: [_prayer()], assignees: team),
      );
      expect(
        api.gets.where((g) => g.$1.endsWith('prayers/assignees')),
        isNotEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('prayer-more-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.prayerMenuAssign));
      await tester.pumpAndSettle();
      expect(find.text('Pastor Grace'), findsOneWidget);
      expect(find.text('editor'), findsOneWidget);
    });

    testWidgets('picking someone sends their user id', (tester) async {
      final api = await _pump(
        tester,
        _FakeApi(prayers: [_prayer()], assignees: team),
      );
      await tester.tap(find.byKey(const ValueKey('prayer-more-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.prayerMenuAssign));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-u9')));
      await tester.pumpAndSettle();

      expect(api.patches.single.$2, {'assignedToUserId': 'u9'});
      expect(
        find.text(AppStrings.prayerAssignedTo('Pastor Grace (editor)')),
        findsOneWidget,
      );
    });

    testWidgets('removing an assignment sends an explicit null', (
      tester,
    ) async {
      // `null` and absent are different: omitting the key leaves the stale
      // assignee in place, which is the silent bug the guide warns about.
      final api = await _pump(
        tester,
        _FakeApi(
          prayers: [
            _prayer(
              assignee: const {
                'userId': 'u9',
                'displayName': 'Pastor Grace',
                'role': 'editor',
              },
            ),
          ],
          assignees: team,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('prayer-more-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.prayerMenuAssign));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assign-clear')));
      await tester.pumpAndSettle();

      final sent = api.patches.single.$2! as Map<String, dynamic>;
      expect(sent.containsKey('assignedToUserId'), isTrue);
      expect(sent['assignedToUserId'], isNull);
      expect(find.text(AppStrings.prayerNotAssigned), findsOneWidget);
    });

    testWidgets('a ministry with no assignable team says why', (tester) async {
      await _pump(tester, _FakeApi(prayers: [_prayer()]));
      await tester.tap(find.byKey(const ValueKey('prayer-more-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.prayerMenuAssign));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.prayerAssignNoTeamBody), findsOneWidget);
    });
  });

  group('testimonies', () {
    testWidgets('the pending queue is what the tab opens on', (tester) async {
      final api = await _pump(tester, _FakeApi(testimonies: [_testimony()]));
      await _tab(tester, AppStrings.impactTabTestimony);

      final asked = api.gets.lastWhere((g) => g.$1.endsWith('/testimonies'));
      expect(asked.$2?['status'], 'pending');
      expect(
        find.text('God restored what I thought was gone.'),
        findsOneWidget,
      );
    });

    testWidgets('an impact tag renders as a label, not its slug', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeApi(
          testimonies: [
            _testimony(tags: ['answered_prayer']),
          ],
        ),
      );
      await _tab(tester, AppStrings.impactTabTestimony);
      expect(find.text('Answered prayer'), findsOneWidget);
    });

    testWidgets('a tag this app has not heard of still renders', (
      tester,
    ) async {
      // The vocabulary can grow before this app's next release; a new tag
      // must not vanish off the card.
      await _pump(
        tester,
        _FakeApi(
          testimonies: [
            _testimony(tags: ['new_mercy']),
          ],
        ),
      );
      await _tab(tester, AppStrings.impactTabTestimony);
      expect(find.text('New mercy'), findsOneWidget);
    });

    testWidgets('an anonymous submitter is shown as the gateway masked', (
      tester,
    ) async {
      await _pump(tester, _FakeApi(testimonies: [_testimony(anonymous: true)]));
      await _tab(tester, AppStrings.impactTabTestimony);
      expect(find.text('Anonymous user'), findsOneWidget);
      expect(find.text('Cynthia Morgan'), findsNothing);
    });

    testWidgets('approving shares it, and says that is what happened', (
      tester,
    ) async {
      final api = await _pump(tester, _FakeApi(testimonies: [_testimony()]));
      await _tab(tester, AppStrings.impactTabTestimony);
      await tester.tap(find.text(AppStrings.testimonyApprove));
      await tester.pumpAndSettle();

      expect(
        api.patches.single.$1,
        '/v1/creator/engagement/testimonies/t1/moderate',
      );
      expect(api.patches.single.$2, {'status': 'approved'});
      expect(find.text(AppStrings.testimonyNowLive), findsOneWidget);
    });

    testWidgets('removing an approved one turns it down', (tester) async {
      // There is no "unpublish" state — off the wall means rejected.
      final api = await _pump(
        tester,
        _FakeApi(testimonies: [_testimony(status: 'approved')]),
      );
      await _tab(tester, AppStrings.impactTabTestimony);
      await _filter(tester, AppStrings.testimonyStateApproved);
      await tester.tap(find.text(AppStrings.testimonyRemove));
      await tester.pumpAndSettle();

      expect(api.patches.single.$2, {'status': 'rejected'});
    });

    testWidgets('restoring a rejected one returns it for review', (
      tester,
    ) async {
      final api = await _pump(
        tester,
        _FakeApi(testimonies: [_testimony(status: 'rejected')]),
      );
      await _tab(tester, AppStrings.impactTabTestimony);
      await _filter(tester, AppStrings.testimonyStateRejected);
      expect(find.text(AppStrings.testimonyRestore), findsOneWidget);
      expect(find.byKey(const ValueKey('testimony-reject-t1')), findsNothing);

      await tester.tap(find.text(AppStrings.testimonyRestore));
      await tester.pumpAndSettle();
      expect(api.patches.single.$2, {'status': 'pending'});
      expect(find.text(AppStrings.testimonyRestoredToast), findsOneWidget);
    });

    testWidgets('pages with meta.next, not a cursor', (tester) async {
      final api = await _pump(
        tester,
        _FakeApi(testimonies: [_testimony()], nextPage: 2),
      );
      await _tab(tester, AppStrings.impactTabTestimony);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final asked = api.gets.lastWhere((g) => g.$1.endsWith('/testimonies'));
      expect(asked.$2?['page'], 2);
      expect(asked.$2?.containsKey('cursor'), isFalse);
    });
  });

  group('the comment moderation queue', () {
    testWidgets('says it is not every comment on your content', (tester) async {
      // "Comments" in a tab reads like the whole conversation, and a busy
      // ministry seeing an empty queue would think the screen is broken.
      await _pump(tester, _FakeApi());
      await _tab(tester, AppStrings.impactTabComments);
      expect(find.byType(ImpactQueueNote), findsOneWidget);
      expect(find.text(AppStrings.commentQueueNote), findsOneWidget);
    });

    testWidgets('"All" omits status rather than asking for visible', (
      tester,
    ) async {
      // `status=visible` is rejected by the gateway; omitting it means both
      // moderation states.
      final api = await _pump(tester, _FakeApi(comments: [_comment()]));
      await _tab(tester, AppStrings.impactTabComments);

      final asked = api.gets.lastWhere((g) => g.$1.endsWith('/comments'));
      expect(asked.$2?.containsKey('status'), isFalse);
    });

    testWidgets('and no path anywhere asks for visible', (tester) async {
      final api = await _pump(tester, _FakeApi(comments: [_comment()]));
      await _tab(tester, AppStrings.impactTabComments);
      for (final label in const [
        AppStrings.commentStateFlagged,
        AppStrings.commentStateHidden,
        AppStrings.commentStateAll,
      ]) {
        await _filter(tester, label);
      }
      expect(api.gets.where((g) => g.$2?['status'] == 'visible'), isEmpty);
    });

    testWidgets('a flagged comment is kept public or hidden', (tester) async {
      await _pump(tester, _FakeApi(comments: [_comment()]));
      await _tab(tester, AppStrings.impactTabComments);

      expect(find.text(AppStrings.commentFlaggedPill), findsOneWidget);
      expect(find.text(AppStrings.commentKeepPublic), findsOneWidget);
      expect(find.text(AppStrings.commentHide), findsOneWidget);
    });

    testWidgets('keeping it public removes it from the queue, and says so', (
      tester,
    ) async {
      final api = await _pump(tester, _FakeApi(comments: [_comment()]));
      await _tab(tester, AppStrings.impactTabComments);
      await tester.tap(find.text(AppStrings.commentKeepPublic));
      await tester.pumpAndSettle();

      expect(
        api.patches.single.$1,
        '/v1/creator/engagement/comments/c1/moderate',
      );
      expect(api.patches.single.$2, {'status': 'visible'});
      expect(find.byType(ImpactCommentCard), findsNothing);
      expect(find.text(AppStrings.commentLeavesQueue), findsOneWidget);
    });

    testWidgets('a hidden one is restored instead', (tester) async {
      final api = await _pump(
        tester,
        _FakeApi(comments: [_comment(status: 'hidden')]),
      );
      await _tab(tester, AppStrings.impactTabComments);
      expect(find.text(AppStrings.commentHiddenPill), findsOneWidget);
      expect(find.text(AppStrings.commentUnhide), findsOneWidget);

      await tester.tap(find.text(AppStrings.commentUnhide));
      await tester.pumpAndSettle();
      expect(api.patches.single.$2, {'status': 'visible'});
    });

    testWidgets('restoring a hidden one is not called "kept public"', (
      tester,
    ) async {
      // Both write `visible`, but clearing a report and putting back
      // something the team took down are different acts.
      await _pump(tester, _FakeApi(comments: [_comment(status: 'hidden')]));
      await _tab(tester, AppStrings.impactTabComments);
      await tester.tap(find.text(AppStrings.commentUnhide));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.commentUnhidden), findsOneWidget);
      expect(find.text(AppStrings.commentKeptPublic), findsNothing);
    });

    testWidgets('a failed decision puts the comment back', (tester) async {
      await _pump(tester, _FakeApi(comments: [_comment()], failWrite: true));
      await _tab(tester, AppStrings.impactTabComments);
      await tester.tap(find.text(AppStrings.commentKeepPublic));
      await tester.pumpAndSettle();

      expect(find.byType(ImpactCommentCard), findsOneWidget);
      expect(find.text(AppStrings.impactActionFailed), findsOneWidget);
    });

    testWidgets('names the content it sits under', (tester) async {
      await _pump(tester, _FakeApi(comments: [_comment(replyCount: 3)]));
      await _tab(tester, AppStrings.impactTabComments);
      expect(
        find.textContaining('Walking by faith', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(AppStrings.impactReplyCount(3)), findsOneWidget);
    });

    testWidgets('an unresolved title still identifies the row', (tester) async {
      await _pump(tester, _FakeApi(comments: [_comment(targetTitle: null)]));
      await _tab(tester, AppStrings.impactTabComments);
      expect(
        find.textContaining(
          AppStrings.prayerFromType('media'),
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.byType(ImpactCommentCard), findsOneWidget);
    });

    testWidgets('the tab count is meta.total, not the page length', (
      tester,
    ) async {
      // The queue has no summary route; the page's own total is the count.
      await _pump(
        tester,
        _FakeApi(comments: [_comment()], total: 12, nextPage: 2),
      );
      await _tab(tester, AppStrings.impactTabComments);
      expect(find.text('${AppStrings.impactTabComments} · 12'), findsOneWidget);
    });

    testWidgets('and it drops by one when a row leaves the queue', (
      tester,
    ) async {
      await _pump(tester, _FakeApi(comments: [_comment()], total: 12));
      await _tab(tester, AppStrings.impactTabComments);
      await tester.tap(find.text(AppStrings.commentKeepPublic));
      await tester.pumpAndSettle();
      expect(find.text('${AppStrings.impactTabComments} · 11'), findsOneWidget);
    });

    testWidgets('a reply says it is one, without inventing the parent', (
      tester,
    ) async {
      // The design quotes the comment being answered; the queue sends only
      // `parentCommentId`, and nothing fetches one comment by id.
      await _pump(
        tester,
        _FakeApi(comments: [_comment(parentCommentId: 'c0')]),
      );
      await _tab(tester, AppStrings.impactTabComments);
      expect(find.text(AppStrings.commentIsReply), findsOneWidget);
    });

    testWidgets('a top-level one says nothing of the sort', (tester) async {
      await _pump(tester, _FakeApi(comments: [_comment()]));
      await _tab(tester, AppStrings.impactTabComments);
      expect(find.text(AppStrings.commentIsReply), findsNothing);
    });

    testWidgets('an empty queue is good news, not an error', (tester) async {
      await _pump(tester, _FakeApi());
      await _tab(tester, AppStrings.impactTabComments);
      expect(find.text(AppStrings.impactNoComments), findsOneWidget);
    });
  });

  group('reporting a comment', () {
    testWidgets('carries the reason and what was typed', (tester) async {
      final outcome = await _report(tester, AppStrings.reportSpam, 'Bot link');
      expect(outcome?.reason, ReportReason.spam);
      expect(outcome?.detail, 'Bot link');
    });

    testWidgets('"Copyright or impersonation" travels as other', (
      tester,
    ) async {
      // The API has no such reason. The row stays because the design asks for
      // it; whoever reviews the report loses the distinction.
      final outcome = await _report(tester, AppStrings.reportImpersonation, '');
      expect(outcome?.reason, ReportReason.other);
    });

    testWidgets('every row the design offers maps onto a reason', (_) async {
      expect(reportChoices, hasLength(8));
      for (final (_, label) in reportChoices) {
        expect(label, isNotEmpty);
      }
    });
  });
}

/// Walk the report sheet on its own: pick [reason], type [detail], send.
Future<ReportOutcome?> _report(
  WidgetTester tester,
  String reason,
  String detail,
) async {
  ReportOutcome? outcome;
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (_) => MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.base1,
          body: Builder(
            builder: (context) => GestureDetector(
              key: const ValueKey('open-report'),
              behavior: HitTestBehavior.opaque,
              onTap: () async => outcome = await showReportSheet(context),
              child: const SizedBox(width: 200, height: 60),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('open-report')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('choice-$reason')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.reportNext));
  await tester.pumpAndSettle();

  if (detail.isNotEmpty) {
    await tester.enterText(find.byKey(const ValueKey('report-detail')), detail);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(AppStrings.reportSubmit));
  await tester.pumpAndSettle();
  return outcome;
}
