import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/mobile_checkout_repo.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/features/creator/views/widgets/creator_profile_parts.dart';
import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/giving/data/give_action.dart';
import 'package:test_app/features/giving/data/giving_capability_store.dart';
import 'package:test_app/features/giving/repo/donor_giving_repo.dart';
import 'package:test_app/features/giving/views/give_fund_sheet.dart';
import 'package:test_app/features/giving/views/giving_status_screen.dart';
import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/models/library_models/give_flow_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/pending_checkout_store.dart';
import 'package:test_app/shared/services/pending_giving_store.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// What a giver actually sees: where Give is offered, what it asks, and what
/// it says afterwards.
///
/// The amount step is deliberately missing from all of this — it lives on the
/// web surface, so there is no screen here that could name a figure the server
/// has not computed.

const _funds = [
  GivingFundOption(id: 'f1', slug: 'general', name: 'General support'),
  GivingFundOption(
    id: 'f2',
    slug: 'building',
    name: 'Building Fund',
    description: 'New sanctuary',
  ),
];

class _FakeApi implements ApiService {
  _FakeApi(this.statuses, {this.withCharge = true});

  /// One body per read, so a poll can be watched changing.
  final List<String> statuses;

  /// A gift that settled before the charge was echoed back.
  final bool withCharge;
  int _reads = 0;
  final List<String> paths = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    final status = statuses[_reads.clamp(0, statuses.length - 1)];
    _reads++;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'success': true,
                'data': {
                  'session': {
                    'id': 'g1',
                    'purpose': 'giving',
                    'status': status,
                    'subscription': null,
                    'giving': {
                      'givingPaymentId': 'gp1',
                      'paymentStatus': status,
                      'charge': status == 'succeeded' && withCharge
                          ? {
                              'currency': 'NGN',
                              'amountMinor': 2000000,
                              'amount': '₦20,000.00',
                            }
                          : null,
                      'creatorNet': null,
                    },
                  },
                },
              }
              as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// The three reads and one write that stand between tapping Give and the
/// browser opening, each one holdable so the wait itself can be inspected.
class _GiveApi implements ApiService {
  _GiveApi({this.available = true, this.gate});

  final bool available;

  /// Completed by the test to let every pending call through at once.
  final Completer<void>? gate;

  final List<String> gets = [];
  final List<String> posts = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    gets.add(path);
    if (gate != null) await gate!.future;
    final data = switch (path) {
      final p when p.endsWith('/funds') => {
        'funds': [
          {'id': 'f1', 'slug': 'general', 'name': 'General support'},
        ],
      },
      final p when p.endsWith('/capability') => {
        'creatorId': 'c1',
        'available': available,
      },
      _ => {
        'platformSubscription': {'available': false},
        'giving': {'available': available},
      },
    };
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data} as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add(path);
    if (gate != null) await gate!.future;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          {
                'success': true,
                'data': {
                  'session': {
                    'id': 'g1',
                    'purpose': 'giving',
                    'creatorId': 'c1',
                    'status': 'created',
                    'subscription': null,
                    'giving': {'charge': null},
                  },
                  'launchUrl':
                      'https://auth.gospeltube.tv/api/auth/'
                      'browser-handoff?ticket=x',
                  'launchExpiresAt': '2999-01-01T00:00:00.000Z',
                },
              }
              as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A Give button wired to [api], so a tap runs the real flow.
///
/// [taps] stands in for the race a modal barrier cannot catch: two taps
/// delivered in the same frame, before anything is on screen to absorb the
/// second.
Widget _giveButton(_GiveApi api, {List<Uri>? opened, int taps = 1}) {
  final repo = DonorGivingRepo(api: api);
  final handoff = CheckoutHandoffService(
    repo: MobileCheckoutRepo(api: api),
    store: InMemoryPendingCheckoutStore(),
    givingStore: InMemoryPendingGivingStore(),
    opener: (uri) async {
      opened?.add(uri);
      return true;
    },
  );
  return Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            for (var i = 0; i < taps; i++) {
              unawaited(
                startGive(
                  context,
                  creatorId: 'c1',
                  ministryName: 'Grace Chapel',
                  capabilities: GivingCapabilityStore(repo: repo),
                  repo: repo,
                  handoff: handoff,
                ),
              );
            }
          },
          child: const Text('tap me'),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget child, {Size? size}) async {
  tester.view.physicalSize = (size ?? const Size(390, 900)) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (_) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.noScaling),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CreatorProfile _profile({bool owned = false}) => CreatorProfile(
  id: 'c1',
  displayName: 'Grace Chapel',
  handle: 'grace',
  isOwnedByViewer: owned,
);

void main() {
  setUpAll(loadAppFonts);

  group('Give on a channel header', () {
    testWidgets('appears when the ministry can receive', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: CreatorProfileHeader(
            profile: _profile(),
            busy: false,
            canGive: true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('profile-give')), findsOneWidget);
    });

    testWidgets('is withheld, not greyed, when it cannot', (tester) async {
      // A disabled Give Now invites a tap that can only be refused, and the
      // refusal carries no reason — so the action is absent instead.
      await _pump(
        tester,
        SingleChildScrollView(
          child: CreatorProfileHeader(profile: _profile(), busy: false),
        ),
      );
      expect(find.byKey(const ValueKey('profile-give')), findsNothing);
      expect(find.byKey(const ValueKey('profile-follow')), findsOneWidget);
    });

    testWidgets('your own channel offers the studio instead', (tester) async {
      await _pump(
        tester,
        SingleChildScrollView(
          child: CreatorProfileHeader(
            profile: _profile(owned: true),
            busy: false,
            canGive: true,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('profile-give')), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-open-own-studio')),
        findsOneWidget,
      );
    });

    testWidgets('header and its three buttons fit a narrow phone', (
      tester,
    ) async {
      // Follow + Give + the overflow on one row is the widest this gets.
      await _pump(
        tester,
        SingleChildScrollView(
          child: CreatorProfileHeader(
            profile: CreatorProfile(
              id: 'c1',
              displayName: 'The Redeemed Christian Church of God, Lagos',
              handle: 'rccglagos',
            ),
            busy: false,
            canGive: true,
          ),
        ),
        size: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Give on a content page', () {
    testWidgets('takes the fourth slot of the impact row', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: DetailImpactActions(likes: '12', saves: '3', canGive: true),
        ),
      );
      expect(find.byKey(const ValueKey('detail-give')), findsOneWidget);
      expect(find.text(AppStrings.give), findsOneWidget);
    });

    testWidgets('and the row goes back to three without it', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: DetailImpactActions(likes: '12', saves: '3'),
        ),
      );
      expect(find.byKey(const ValueKey('detail-give')), findsNothing);
      expect(find.text(AppStrings.share), findsOneWidget);
    });

    testWidgets('four actions still fit a narrow phone', (tester) async {
      await _pump(
        tester,
        const Scaffold(
          body: DetailImpactActions(
            likes: '12.9K',
            saves: '1.2K',
            canGive: true,
          ),
        ),
        size: const Size(320, 900),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the fund picker', () {
    Future<String?> open(
      WidgetTester tester, {
      List<GivingFundOption> funds = _funds,
      String? initial,
    }) async {
      String? picked;
      var done = false;
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await GiveFundSheet.show(
                    context,
                    ministry: 'Grace Chapel',
                    funds: funds,
                    initialSlug: initial,
                  );
                  done = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return done ? picked : null;
    }

    testWidgets('names the ministry the gift is for', (tester) async {
      await open(tester);
      expect(find.text(AppStrings.giveFundsTitle), findsOneWidget);
      expect(find.text('Give to Grace Chapel'), findsOneWidget);
    });

    testWidgets('lists every fund by name', (tester) async {
      await open(tester);
      expect(find.text('General support'), findsOneWidget);
      expect(find.text('Building Fund'), findsOneWidget);
      expect(find.text('New sanctuary'), findsOneWidget);
    });

    testWidgets('a fund with no description falls back to the ministry', (
      tester,
    ) async {
      // An empty caption line reads as a rendering fault rather than as an
      // absent description — and the fallback is worded shorter than the
      // header so the two do not read as one line printed twice.
      await open(tester);
      expect(find.text('To Grace Chapel'), findsOneWidget);
      expect(find.text('Give to Grace Chapel'), findsOneWidget);
    });

    testWidgets('general is preselected', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('give-fund-continue')));
      await tester.pumpAndSettle();
      // Nothing was chosen by hand, so Continue returns the default.
      expect(find.byKey(const ValueKey('give-fund-continue')), findsNothing);
    });

    testWidgets('a shared link’s fund wins over general', (tester) async {
      String? picked;
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => picked = await GiveFundSheet.show(
                  context,
                  ministry: 'Grace Chapel',
                  funds: _funds,
                  initialSlug: 'building',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('give-fund-continue')));
      await tester.pumpAndSettle();
      expect(picked, 'building');
    });

    testWidgets('an unknown slug falls back rather than selecting nothing', (
      tester,
    ) async {
      String? picked;
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => picked = await GiveFundSheet.show(
                  context,
                  ministry: 'Grace Chapel',
                  funds: _funds,
                  initialSlug: 'no-such-fund',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('give-fund-continue')));
      await tester.pumpAndSettle();
      expect(picked, 'general');
    });

    testWidgets('choosing another fund returns its slug', (tester) async {
      String? picked;
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => picked = await GiveFundSheet.show(
                  context,
                  ministry: 'Grace Chapel',
                  funds: _funds,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('give-fund-building')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('give-fund-continue')));
      await tester.pumpAndSettle();
      expect(picked, 'building');
    });

    testWidgets('closing it returns nothing, which abandons the gift', (
      tester,
    ) async {
      String? picked = 'untouched';
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => picked = await GiveFundSheet.show(
                  context,
                  ministry: 'Grace Chapel',
                  funds: _funds,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('give-fund-close')));
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });

    testWidgets('a long ministry name does not overflow a narrow phone', (
      tester,
    ) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => GiveFundSheet.show(
                  context,
                  ministry:
                      'The Redeemed Christian Church of God, Lagos Province 14',
                  funds: const [
                    GivingFundOption(
                      id: 'f1',
                      slug: 'general',
                      name: 'General ministry support and building maintenance',
                      description:
                          'Everything the ministry needs week to week, '
                          'including the building and the outreach teams',
                    ),
                    ..._funds,
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        size: const Size(320, 700),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the gift status screen', () {
    Future<void> show(WidgetTester tester, List<String> statuses) async {
      final api = _FakeApi(statuses);
      await GetIt.instance.reset();
      GetIt.instance.registerSingleton<ApiService>(api);
      addTearDown(GetIt.instance.reset);
      await _pump(
        tester,
        GivingStatusScreen(
          sessionId: 'g1',
          repo: MobileCheckoutRepo(api: api),
          store: InMemoryPendingGivingStore(),
        ),
      );
    }

    testWidgets('thanks the giver, naming what the server charged', (
      tester,
    ) async {
      await show(tester, ['succeeded']);
      expect(
        find.text(AppStrings.giftConfirmedAmount('₦20,000.00')),
        findsOneWidget,
      );
    });

    testWidgets('never claims the ministry has the money', (tester) async {
      // Settlement follows on its own schedule, and on a provider-held rail
      // after a hold window. The giver is thanked for the gift, not told a
      // transfer happened.
      await show(tester, ['succeeded']);
      expect(find.textContaining('sent to'), findsNothing);
      expect(find.textContaining('paid out'), findsNothing);
    });

    testWidgets('thanks without a figure when none came back', (tester) async {
      // The server formats money; the app never composes an amount of its
      // own, so a settled gift with no echoed charge thanks the giver plainly
      // rather than printing a blank or a rebuilt figure.
      final api = _FakeApi(['succeeded'], withCharge: false);
      await GetIt.instance.reset();
      GetIt.instance.registerSingleton<ApiService>(api);
      addTearDown(GetIt.instance.reset);
      await _pump(
        tester,
        GivingStatusScreen(
          sessionId: 'g1',
          repo: MobileCheckoutRepo(api: api),
          store: InMemoryPendingGivingStore(),
        ),
      );
      expect(find.text(AppStrings.giftConfirmed), findsOneWidget);
    });

    testWidgets('a failed gift says so and offers another try', (tester) async {
      await show(tester, ['failed']);
      expect(find.text(AppStrings.giftDeclined), findsOneWidget);
      expect(find.text(AppStrings.giftDone), findsOneWidget);
    });

    testWidgets('a cancelled gift is not called a failure', (tester) async {
      await show(tester, ['canceled']);
      expect(find.text(AppStrings.giftCanceled), findsOneWidget);
    });

    testWidgets('an expired session says to start a new one', (tester) async {
      await show(tester, ['expired']);
      expect(find.text(AppStrings.giftExpired), findsOneWidget);
    });

    testWidgets('a settled gift offers no way back into the browser', (
      tester,
    ) async {
      // There is nothing left to pay, so offering the browser would be an
      // invitation to give twice by accident.
      await show(tester, ['succeeded']);
      expect(find.text(AppStrings.giftResume), findsNothing);
      expect(
        find.byKey(const ValueKey('giving-status-secondary')),
        findsNothing,
      );
    });

    testWidgets('the screen stops polling once the gift is terminal', (
      tester,
    ) async {
      final api = _FakeApi(['failed']);
      await GetIt.instance.reset();
      GetIt.instance.registerSingleton<ApiService>(api);
      addTearDown(GetIt.instance.reset);
      await _pump(
        tester,
        GivingStatusScreen(
          sessionId: 'g1',
          repo: MobileCheckoutRepo(api: api),
          store: InMemoryPendingGivingStore(),
        ),
      );
      expect(api.paths, hasLength(1));
    });
  });

  group('tapping Give', () {
    // The guard outlives a call on purpose, so a case that leaves a gift
    // hanging must not disable Give for the next one.
    setUp(resetGiveGuard);

    /// Found on the device on 2026-10-29: the tap at 08:28:44 reached the
    /// browser at 08:28:57. Three round trips, and nothing on screen for any
    /// of them — a button that looked broken for thirteen seconds.
    testWidgets('says what is happening instead of looking broken', (
      tester,
    ) async {
      final gate = Completer<void>();
      await _pump(tester, _giveButton(_GiveApi(gate: gate)));
      await tester.tap(find.text('tap me'));
      await tester.pump();

      expect(find.text(AppStrings.giveOpening), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Seen on the device on 2026-10-29: a dialog route carries no Material
      // of its own, and the message came out in the debug fallback style —
      // yellow, double-underlined.
      expect(
        find.ancestor(
          of: find.text(AppStrings.giveOpening),
          matching: find.byType(Material),
        ),
        findsWidgets,
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.giveOpening), findsNothing);
    });

    testWidgets('a second tap does not buy a second gift', (tester) async {
      // Giving sessions coexist — probed on 2026-10-29, a second
      // idempotency key answers 201 — so an unguarded double tap is two
      // things to pay for, not one request deduped by the server.
      final gate = Completer<void>();
      final api = _GiveApi(gate: gate);
      // Two in the same frame: the barrier is not up yet, so only the guard
      // can stop the second one.
      await _pump(tester, _giveButton(api, taps: 2));

      await tester.tap(find.text('tap me'));
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();
      expect(api.posts, hasLength(1));
    });

    testWidgets('the browser opens and nothing is left on screen', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pump(tester, _giveButton(_GiveApi(), opened: opened));
      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a ministry that cannot receive is told, not left spinning', (
      tester,
    ) async {
      // The barrier must come down on the refusal too: a spinner that cannot
      // be dismissed is worse than the message it is hiding.
      await _pump(tester, _giveButton(_GiveApi(available: false)));
      await tester.tap(find.text('tap me'));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(AppStrings.giveUnavailable), findsOneWidget);
    });
  });
}
