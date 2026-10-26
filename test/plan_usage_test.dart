import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_dashboard_repo.dart';
import 'package:test_app/features/creator/views/widgets/studio_sheets.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// The plan's upload allowance, and the studios a reader can work in.
///
/// Both arrived on 2026-10-26. The quota is said **before** a file is picked
/// because `POST /v1/media` only refuses after one has been uploaded, and the
/// studio list is what turned "Switch studio" from a row that reported itself
/// unimplemented into a real switcher.
class _FakeApi implements ApiService {
  _FakeApi(this.body, {this.fails = false});

  final Object body;
  final bool fails;
  final List<String> got = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    got.add(path);
    if (fails) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 403,
        ),
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {'data': body} as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('the plan', () {
    test('a limit of null is unlimited, not nothing left', () {
      // Read the other way round, every unlimited plan would show its Create
      // sheet as exhausted.
      const unlimited = PlanUsage(uploadsUsed: 40);

      expect(unlimited.hasUploadLimit, isFalse);
      expect(unlimited.uploadsExhausted, isFalse);
    });

    test('the window is a rolling thirty days by default', () {
      expect(const PlanUsage().windowDays, 30);
    });

    test('used beyond the limit still reads as none left, never negative', () {
      const over = PlanUsage(uploadsUsed: 7, uploadLimit: 5);

      expect(over.uploadsLeft, 0);
      expect(over.uploadsExhausted, isTrue);
    });

    test('it reads the usage block, not the plan name', () async {
      final api = _FakeApi(const {
        'plan': {'name': 'Growth'},
        'usage': {
          'uploads': {'usedInWindow': 3, 'limit': 5, 'windowDays': 30},
          'storage': {'usedBytes': 1024, 'limitBytes': 4096},
        },
      });
      final usage = await CreatorDashboardRepo(api).fetchPlanUsage('c1');

      expect(api.got.single, '/v1/creator/c1/settings/plan');
      expect(usage!.uploadsUsed, 3);
      expect(usage.uploadLimit, 5);
      expect(usage.uploadsLeft, 2);
      expect(usage.storageLimitBytes, 4096);
    });

    test('a studio that cannot read its quota shows none', () async {
      // Not worth an error state: the upload itself still refuses when the
      // guard says so, and refusing to open the Create sheet over a quota
      // read would be worse than saying nothing.
      final usage = await CreatorDashboardRepo(
        _FakeApi(const {}, fails: true),
      ).fetchPlanUsage('c1');

      expect(usage, isNull);
    });
  });

  group('the Create sheet', () {
    testWidgets('says what is left before a file is picked', (tester) async {
      await _pump(
        tester,
        CreateSheet(
          kinds: CreateKind.values,
          onPick: (_) {},
          usage: const PlanUsage(uploadsUsed: 3, uploadLimit: 5),
        ),
      );

      expect(find.text(AppStrings.uploadsUsed(3, 5, 30)), findsOneWidget);
    });

    testWidgets('an exhausted plan says so instead of counting', (
      tester,
    ) async {
      await _pump(
        tester,
        CreateSheet(
          kinds: CreateKind.values,
          onPick: (_) {},
          usage: const PlanUsage(uploadsUsed: 5, uploadLimit: 5),
        ),
      );

      expect(find.text(AppStrings.uploadsExhaustedBody(30)), findsOneWidget);
      expect(find.text(AppStrings.uploadsUsed(5, 5, 30)), findsNothing);
    });

    testWidgets('an unlimited plan says nothing at all', (tester) async {
      await _pump(
        tester,
        CreateSheet(
          kinds: CreateKind.values,
          onPick: (_) {},
          usage: const PlanUsage(uploadsUsed: 99),
        ),
      );

      expect(find.textContaining('uploads used'), findsNothing);
      expect(find.text(AppStrings.uploadsExhaustedBody(30)), findsNothing);
    });

    testWidgets('a quota that has not arrived yet is simply absent', (
      tester,
    ) async {
      await _pump(
        tester,
        CreateSheet(kinds: CreateKind.values, onPick: (_) {}),
      );

      expect(find.textContaining('uploads used'), findsNothing);
    });
  });

  group('the studios a reader can work in', () {
    test('a user who belongs to none gets a list, not an error', () async {
      final studios = await CreatorDashboardRepo(
        _FakeApi(const {'items': [], 'total': 0}),
      ).fetchMemberships();

      expect(studios, isEmpty);
    });

    test('the role comes off the membership row', () async {
      final studios = await CreatorDashboardRepo(
        _FakeApi(const {
          'items': [
            {
              'creatorId': 'c1',
              'displayName': 'Grace Chapel',
              'handle': 'grace',
              'role': 'owner',
              'isPrincipalOwner': true,
            },
            {
              'creatorId': 'c2',
              'displayName': 'Hillside',
              'handle': 'hillside',
              'role': 'editor',
            },
          ],
        }),
      ).fetchMemberships();

      expect(studios.map((s) => s.creatorId), ['c1', 'c2']);
      expect(studios.first.isPrincipalOwner, isTrue);
      expect(studios.last.role, 'editor');
    });

    testWidgets('the current studio is ticked, the others are tappable', (
      tester,
    ) async {
      StudiosOutcome? picked;
      await _pump(
        tester,
        StudiosSheet(
          current: const DashboardContext(
            creatorId: 'c1',
            displayName: 'Grace Chapel',
            handle: 'grace',
            role: 'owner',
            capabilities: {},
          ),
          studios: const [
            StudioMembership(
              creatorId: 'c1',
              displayName: 'Grace Chapel',
              handle: 'grace',
              role: 'owner',
            ),
            StudioMembership(
              creatorId: 'c2',
              displayName: 'Hillside Fellowship',
              handle: 'hillside',
              role: 'editor',
            ),
          ],
          onPick: (outcome) => picked = outcome,
        ),
      );

      // The studio already open is not listed twice.
      expect(find.text('Grace Chapel'), findsOneWidget);
      expect(find.byKey(const ValueKey('studio-c1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('studio-c2')));
      await tester.pump();

      expect(picked?.switchTo, 'c2');
    });

    test('a refused dashboard still names the studio that is open', () {
      // `dashboard/context` answers 403 to a streamer, who is nevertheless a
      // member — and is exactly the reader who needs the way out. Without
      // the fallback the pill is blank and the switcher cannot be opened at
      // all.
      const rows = [
        StudioMembership(
          creatorId: 'c1',
          displayName: 'Impact Probe Chapel',
          handle: 'impactprobe',
          role: 'streamer',
        ),
      ];
      final open = openStudio(null, rows, creatorId: 'c1');

      expect(open!.displayName, 'Impact Probe Chapel');
      expect(open.role, 'streamer');
      // Unknown, so nothing is offered rather than something that 403s.
      expect(open.can('canCreateMedia'), isFalse);
    });

    test('a context that exists always wins over the membership row', () {
      const context = DashboardContext(
        creatorId: 'c1',
        displayName: 'From the dashboard',
        handle: 'grace',
        role: 'owner',
        capabilities: {'canCreateMedia': true},
      );
      final open = openStudio(context, const [
        StudioMembership(
          creatorId: 'c1',
          displayName: 'From the membership row',
          handle: 'grace',
          role: 'owner',
        ),
      ], creatorId: 'c1');

      expect(open!.displayName, 'From the dashboard');
      expect(open.can('canCreateMedia'), isTrue);
    });

    test('a studio in no list at all names nothing', () {
      expect(openStudio(null, const [], creatorId: 'c1'), isNull);
    });

    testWidgets('only the studio they own is called personal', (tester) async {
      // "Personal · Editor" on a ministry somebody else runs is simply wrong.
      await _pump(
        tester,
        StudiosSheet(
          current: const DashboardContext(
            creatorId: 'c1',
            displayName: 'Grace Chapel',
            handle: 'grace',
            role: 'owner',
            capabilities: {},
          ),
          studios: const [
            StudioMembership(
              creatorId: 'c2',
              displayName: 'Hillside Fellowship',
              handle: 'hillside',
              role: 'editor',
            ),
          ],
          onPick: (_) {},
        ),
      );

      expect(
        find.text('${AppStrings.studiosPersonal} · Owner'),
        findsOneWidget,
      );
      expect(find.text('@hillside · Editor'), findsOneWidget);
      expect(find.text('${AppStrings.studiosPersonal} · Editor'), findsNothing);
    });
  });
}
