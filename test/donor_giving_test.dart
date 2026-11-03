import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/repo/mobile_checkout_repo.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/features/creator/services/checkout_link_listener.dart';
import 'package:test_app/features/giving/data/giving_capability_store.dart';
import 'package:test_app/features/giving/repo/donor_giving_repo.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/pending_checkout_store.dart';
import 'package:test_app/shared/services/pending_giving_store.dart';

/// The reader's side of Giving: deciding whether to offer a gift, and handing
/// the gift itself to the web surface.
///
/// Every response below was captured from staging on 2026-10-29 rather than
/// written from the guide — the giving half of a checkout session is not
/// documented anywhere, and two of its refusals are not what the guide would
/// lead you to expect.

/// `POST /v1/payment/mobile-web-checkouts` with `purpose: giving`.
const _createGiving = {
  'success': true,
  'data': {
    'session': {
      'id': 'cmvt659c601f9ku13r9zw0uen',
      'purpose': 'giving',
      'platform': 'android',
      'storefrontCountry': 'NG',
      'creatorId': '6a2423ae0e90471cdcb3af5d',
      'preferredFundSlug': null,
      'sourceMediaId': null,
      'status': 'created',
      'paymentProvider': null,
      'mobileReturnUrl':
          'https://app.staging.gospeltube.tv/mobile/payments/return'
          '?session=cmvt659c601f9ku13r9zw0uen',
      'expiresAt': '2026-10-30T06:35:04.709Z',
      'subscription': null,
      // Every key present, every value null, on a session nobody has paid
      // for yet. This is the normal shape, not a degraded one.
      'giving': {
        'givingPaymentId': null,
        'paymentStatus': null,
        'reconciliationStatus': null,
        'settlementStatus': null,
        'charge': null,
        'creatorNet': null,
      },
    },
    'launchUrl':
        'https://auth.staging.gospeltube.tv/api/auth/browser-handoff?ticket=x',
    'launchExpiresAt': '2999-01-01T00:00:00.000Z',
  },
};

Map<String, dynamic> _givingSession(
  String status, {
  Map<String, dynamic>? charge,
}) => {
  'success': true,
  'data': {
    'session': {
      'id': 'cmvt659c601f9ku13r9zw0uen',
      'purpose': 'giving',
      'creatorId': '6a2423ae0e90471cdcb3af5d',
      'status': status,
      'paymentProvider': 'paystack',
      'subscription': null,
      'giving': {
        'givingPaymentId': 'gp_1',
        'paymentStatus': status,
        'settlementStatus': 'pending',
        'charge': charge,
        'creatorNet': null,
      },
    },
  },
};

const _capabilities = {
  'success': true,
  'data': {
    'platform': 'android',
    'storefrontCountry': 'NG',
    'platformSubscription': {'available': true, 'reason': 'available'},
    'giving': {'available': true, 'reason': 'available'},
  },
};

const _givingClosed = {
  'success': true,
  'data': {
    'platformSubscription': {'available': true, 'reason': 'available'},
    'giving': {'available': false, 'reason': 'storefront_not_allowed'},
  },
};

const _capability = {
  'success': true,
  'data': {'creatorId': 'c1', 'available': true},
};

const _funds = {
  'success': true,
  'data': {
    'funds': [
      {
        'id': 'f1',
        'creatorId': 'c1',
        'slug': 'general',
        'name': 'General ministry support',
        'description': null,
        'active': true,
      },
      {
        'id': 'f2',
        'creatorId': 'c1',
        'slug': 'building',
        'name': 'Building Fund',
        'description': 'New sanctuary',
        'active': true,
      },
    ],
  },
};

class _FakeApi implements ApiService {
  _FakeApi({this.getBody, this.postBody, this.getError});

  Map<String, dynamic>? getBody;
  Map<String, dynamic>? postBody;
  DioException? postError;
  DioException? getError;

  /// Thrown once, then cleared — for the source-media retry.
  DioException? postErrorOnce;

  final List<String> paths = [];
  final List<Map<String, dynamic>> bodies = [];
  Map<String, dynamic>? lastQuery;

  /// Per-path responses, for a flow that reads more than one route.
  final Map<String, Map<String, dynamic>> routes = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    lastQuery = queryParameters;
    if (getError != null) throw getError!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (_match(path) ?? getBody) as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    if (data is Map<String, dynamic>) bodies.add(data);
    if (postErrorOnce != null) {
      final e = postErrorOnce!;
      postErrorOnce = null;
      throw e;
    }
    if (postError != null) throw postError!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (_match(path) ?? postBody ?? getBody) as T,
    );
  }

  Map<String, dynamic>? _match(String path) {
    for (final entry in routes.entries) {
      if (path.contains(entry.key)) return entry.value;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

DioException _refusal(int status, String error, {String? sessionId}) =>
    DioException(
      requestOptions: RequestOptions(path: '/'),
      response: Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: status,
        data: {
          'success': false,
          'error': error,
          'details': {'sessionId': ?sessionId},
        },
      ),
    );

/// The two refusals probing turned up, verbatim.
DioException get _ineligible =>
    _refusal(409, 'This creator cannot receive Givings right now.');
DioException get _badSource =>
    _refusal(403, 'Giving source media is not accessible.');

class _Opened {
  final List<Uri> uris = [];
  Future<bool> call(Uri uri) async {
    uris.add(uri);
    return true;
  }
}

CheckoutHandoffService _service(
  _FakeApi api, {
  PendingGivingStore? giving,
  _Opened? opener,
}) => CheckoutHandoffService(
  repo: MobileCheckoutRepo(api: api),
  store: InMemoryPendingCheckoutStore(),
  givingStore: giving ?? InMemoryPendingGivingStore(),
  opener: (opener ?? _Opened()).call,
);

void main() {
  group('capabilities', () {
    test('giving is read from its own flag, not the subscription one', () {
      final caps = CheckoutCapabilities.fromJson(_givingClosed);
      expect(caps.subscriptionAvailable, isTrue);
      expect(caps.givingAvailable, isFalse);
      expect(caps.givingReason, 'storefront_not_allowed');
    });

    test('a capabilities payload with no giving block reads as closed', () {
      // Fail closed: an older gateway that does not mention giving must not
      // be read as permitting it.
      final caps = CheckoutCapabilities.fromJson(const {
        'data': {
          'platformSubscription': {'available': true},
        },
      });
      expect(caps.givingAvailable, isFalse);
    });
  });

  group('public capability', () {
    test('asks the public route and reads the flag', () async {
      final api = _FakeApi(getBody: _capability);
      final available = await DonorGivingRepo(api: api).fetchCapability('c1');
      expect(available, isTrue);
      expect(
        api.paths.single,
        '/v1/public/payment/giving/creators/c1/capability',
      );
    });

    test('an ineligible ministry answers false, not an error', () async {
      final api = _FakeApi(
        getBody: const {
          'success': true,
          'data': {'creatorId': 'c1', 'available': false},
        },
      );
      expect(await DonorGivingRepo(api: api).fetchCapability('c1'), isFalse);
    });

    test('a batch answer is keyed by creator, not by position', () async {
      // The route preserves order, but a dropped row would shift every answer
      // after it onto the wrong ministry — and the wrong Give button sends a
      // giver at a ministry that cannot be paid.
      final api = _FakeApi(
        postBody: const {
          'success': true,
          'data': {
            'items': [
              {'creatorId': 'b', 'available': true},
              {'creatorId': 'a', 'available': false},
            ],
          },
        },
      );
      final answers = await DonorGivingRepo(
        api: api,
      ).fetchCapabilities(['a', 'b']);
      expect(answers['a'], isFalse);
      expect(answers['b'], isTrue);
    });

    test('more than fifty creators is split, not truncated', () async {
      final api = _FakeApi(
        postBody: const {
          'success': true,
          'data': {'items': []},
        },
      );
      final ids = [for (var i = 0; i < 51; i++) 'c$i'];
      await DonorGivingRepo(api: api).fetchCapabilities(ids);
      expect(api.paths, hasLength(2));
      expect((api.bodies.first['creatorIds'] as List), hasLength(50));
      expect((api.bodies.last['creatorIds'] as List), hasLength(1));
    });

    test('a repeated creator is asked about once', () async {
      final api = _FakeApi(
        postBody: const {
          'success': true,
          'data': {'items': []},
        },
      );
      await DonorGivingRepo(api: api).fetchCapabilities(['a', 'a', 'b', '']);
      expect((api.bodies.single['creatorIds'] as List), ['a', 'b']);
    });
  });

  group('the capability store', () {
    test('unknown is not false', () {
      final store = GivingCapabilityStore(
        repo: DonorGivingRepo(api: _FakeApi()),
      );
      // A surface that cannot tell these apart either never fetches, or
      // withholds Give from every ministry it has not met.
      expect(store.known('c1'), isNull);
      store.seed('c1', false);
      expect(store.known('c1'), isFalse);
    });

    test('a known answer is not re-fetched', () async {
      final api = _FakeApi(getBody: _capability);
      final store = GivingCapabilityStore(repo: DonorGivingRepo(api: api));
      await store.ensure('c1');
      await store.ensure('c1');
      expect(api.paths, hasLength(1));
    });

    test('two surfaces asking at once share one request', () async {
      final api = _FakeApi(getBody: _capability);
      final store = GivingCapabilityStore(repo: DonorGivingRepo(api: api));
      await Future.wait([store.ensure('c1'), store.ensure('c1')]);
      expect(api.paths, hasLength(1));
    });

    test('a failed lookup answers false and is not cached', () async {
      final api = _FakeApi(getError: _refusal(500, 'boom'));
      final store = GivingCapabilityStore(repo: DonorGivingRepo(api: api));
      expect(await store.ensure('c1'), isFalse);
      // Caching the failure would withhold Give for the rest of the session
      // over one bad request.
      expect(store.known('c1'), isNull);
    });

    test('priming skips what is already known', () async {
      final api = _FakeApi(
        postBody: const {
          'success': true,
          'data': {
            'items': [
              {'creatorId': 'b', 'available': true},
            ],
          },
        },
      );
      final store = GivingCapabilityStore(repo: DonorGivingRepo(api: api));
      store.seed('a', true);
      await store.prime(['a', 'b']);
      expect((api.bodies.single['creatorIds'] as List), ['b']);
      expect(store.known('b'), isTrue);
    });

    test('an empty creator id is never asked about', () async {
      // A row whose ministry could not be resolved would otherwise send an
      // empty id into a batch the server rejects whole.
      final api = _FakeApi();
      final store = GivingCapabilityStore(repo: DonorGivingRepo(api: api));
      await store.prime(['', '']);
      expect(api.paths, isEmpty);
    });

    test('priming nothing new makes no request', () async {
      final api = _FakeApi();
      final store = GivingCapabilityStore(repo: DonorGivingRepo(api: api));
      store.seed('a', true);
      await store.prime(['a']);
      expect(api.paths, isEmpty);
    });
  });

  group('funds', () {
    test('reads the donor route, not the creator management one', () async {
      // The documented `/v1/payment/giving/funds?creatorId=` answers 403 to
      // anyone but the owner, so a giver cannot use it.
      final api = _FakeApi(getBody: _funds);
      final funds = await DonorGivingRepo(api: api).fetchFunds('c1');
      expect(api.paths.single, '/v1/payment/giving/creators/c1/funds');
      expect(funds.map((f) => f.slug), ['general', 'building']);
      expect(funds.first.isGeneral, isTrue);
    });
  });

  group('starting a gift', () {
    test('sends the giving purpose, not the subscription one', () async {
      final api = _FakeApi(getBody: _capabilities, postBody: _createGiving);
      await _service(api).startGiving(creatorId: 'c1');
      final body = api.bodies.single;
      expect(body['purpose'], 'giving');
      expect(body['creatorId'], 'c1');
    });

    test('the idempotency key is fresh each time, so gifts do not merge', () {
      final a = CheckoutHandoffService.newGivingKey('c1');
      final b = CheckoutHandoffService.newGivingKey('c1');
      expect(a, isNot(b));
      expect(a, startsWith('giving:creator:c1:attempt:'));
    });

    test('the idempotency key satisfies the server\'s own rules', () {
      // Read off a refusal on 2026-10-29: `idempotencyKey must match
      // /^[A-Za-z0-9:_-]+$/` and `must be shorter than or equal to 128
      // characters`. Neither is in the guide, and a key that breaks either is
      // a 400 at the moment the giver taps Give.
      final key = CheckoutHandoffService.newGivingKey(
        '6a2423ae0e90471cdcb3af5d',
      );
      expect(RegExp(r'^[A-Za-z0-9:_-]+$').hasMatch(key), isTrue);
      expect(key.length, lessThanOrEqualTo(128));
    });

    test('and so does the subscription key', () {
      final key = CheckoutHandoffService.newAttemptKey(
        '6a2423ae0e90471cdcb3af5d',
      );
      expect(RegExp(r'^[A-Za-z0-9:_-]+$').hasMatch(key), isTrue);
      expect(key.length, lessThanOrEqualTo(128));
    });

    test('a chosen fund travels; an unchosen one is omitted', () async {
      final api = _FakeApi(getBody: _capabilities, postBody: _createGiving);
      await _service(api).startGiving(creatorId: 'c1', fundSlug: 'building');
      expect(api.bodies.single['preferredFundSlug'], 'building');

      final bare = _FakeApi(getBody: _capabilities, postBody: _createGiving);
      await _service(bare).startGiving(creatorId: 'c1');
      expect(bare.bodies.single.containsKey('preferredFundSlug'), isFalse);
    });

    test('the browser is opened with the launch url', () async {
      final api = _FakeApi(getBody: _capabilities, postBody: _createGiving);
      final opened = _Opened();
      final result = await _service(
        api,
        opener: opened,
      ).startGiving(creatorId: 'c1');
      expect(result.outcome, HandoffOutcome.launched);
      expect(opened.uris.single.host, 'auth.staging.gospeltube.tv');
    });

    test('the session is remembered before the browser opens', () async {
      // The return link can arrive while the app is backgrounded; an id
      // written afterwards may not be there in time to recognise it.
      final api = _FakeApi(getBody: _capabilities, postBody: _createGiving);
      final store = InMemoryPendingGivingStore();
      late List<String> atOpenTime;
      await CheckoutHandoffService(
        repo: MobileCheckoutRepo(api: api),
        store: InMemoryPendingCheckoutStore(),
        givingStore: store,
        opener: (_) async {
          atOpenTime = await store.sessions;
          return true;
        },
      ).startGiving(creatorId: 'c1');
      expect(atOpenTime, ['cmvt659c601f9ku13r9zw0uen']);
    });

    test('a closed storefront is reported, and nothing is created', () async {
      final api = _FakeApi(getBody: _givingClosed, postBody: _createGiving);
      final result = await _service(api).startGiving(creatorId: 'c1');
      expect(result.outcome, HandoffOutcome.unavailable);
      expect(api.bodies, isEmpty);
    });

    test(
      'an ineligible ministry is unavailable, not an active attempt',
      () async {
        // Both answers are 409. Reading this one as "you already have an
        // attempt" would send the giver to resume a session that never existed.
        final api = _FakeApi(getBody: _capabilities)..postError = _ineligible;
        final result = await _service(api).startGiving(creatorId: 'c1');
        expect(result.outcome, HandoffOutcome.unavailable);
      },
    );

    test('an empty creator id never reaches the network', () async {
      final api = _FakeApi(getBody: _capabilities);
      final result = await _service(api).startGiving(creatorId: '');
      expect(result.outcome, HandoffOutcome.failed);
      expect(api.paths, isEmpty);
    });
  });

  group('source media', () {
    test('a livestream is named as the source', () async {
      final api = _FakeApi(getBody: _capabilities, postBody: _createGiving);
      await _service(api).startGiving(creatorId: 'c1', sourceMediaId: 'm1');
      expect(api.bodies.single['sourceMediaId'], 'm1');
    });

    test('a refused source is dropped and the gift still goes ahead', () async {
      // The server accepts a narrower set than "media the giver can watch" —
      // a plain video, an audio row and a livestream's own replay are all
      // refused. Attribution is a nicety; the gift is not.
      final api = _FakeApi(getBody: _capabilities, postBody: _createGiving)
        ..postErrorOnce = _badSource;
      final result = await _service(
        api,
      ).startGiving(creatorId: 'c1', sourceMediaId: 'm1');
      expect(result.outcome, HandoffOutcome.launched);
      expect(api.bodies, hasLength(2));
      expect(api.bodies.first['sourceMediaId'], 'm1');
      expect(api.bodies.last.containsKey('sourceMediaId'), isFalse);
    });

    test('the retry reuses the same idempotency key', () async {
      // A second key would be a second intention, and both could be paid.
      final api = _FakeApi(getBody: _capabilities, postBody: _createGiving)
        ..postErrorOnce = _badSource;
      await _service(api).startGiving(creatorId: 'c1', sourceMediaId: 'm1');
      expect(
        api.bodies.first['idempotencyKey'],
        api.bodies.last['idempotencyKey'],
      );
    });

    test('a 403 with no source media is not swallowed as one', () async {
      // Only giving sends a source, so a 403 without one is a real failure.
      final api = _FakeApi(getBody: _capabilities)
        ..postError = _refusal(403, 'Forbidden');
      final result = await _service(api).startGiving(creatorId: 'c1');
      expect(result.outcome, HandoffOutcome.failed);
    });
  });

  group('the session a gift reads back', () {
    test('parses the giving half', () {
      final session = MobileCheckoutSession.fromJson(
        _givingSession(
          'succeeded',
          charge: {
            'currency': 'NGN',
            'amountMinor': 2000000,
            'amount': '₦20,000.00',
          },
        ),
      );
      expect(session.isGiving, isTrue);
      expect(session.giving?.givingPaymentId, 'gp_1');
      expect(session.giving?.chargeLabel, '₦20,000.00');
    });

    test('a created gift carries the keys with no values', () {
      final handoff = MobileCheckoutHandoff.fromJson(_createGiving);
      expect(handoff.session.giving, isNotNull);
      expect(handoff.session.giving?.paymentStatus, isNull);
      expect(handoff.session.giving?.chargeLabel, isNull);
    });

    test('a succeeded gift is settled without entitlements', () {
      // A gift grants nothing, so there is no second view to wait for.
      // Applying the subscription rule here would report every completed gift
      // as still processing, forever.
      final session = MobileCheckoutSession.fromJson(
        _givingSession('succeeded'),
      );
      expect(session.entitlementsReady, isFalse);
      expect(session.isSettled, isTrue);
    });

    test('a subscription still needs entitlements to be settled', () {
      final session = MobileCheckoutSession.fromJson(const {
        'data': {
          'session': {
            'id': 's1',
            'purpose': 'platform_subscription',
            'status': 'succeeded',
            'subscription': {'entitlementsReady': false},
          },
        },
      });
      expect(session.isSettled, isFalse);
    });

    test('a processing gift is neither settled nor terminal', () {
      final session = MobileCheckoutSession.fromJson(
        _givingSession('processing'),
      );
      expect(session.isSettled, isFalse);
      expect(session.isTerminal, isFalse);
    });

    test('creatorNet stays null until settlement finalizes', () {
      final session = MobileCheckoutSession.fromJson(
        _givingSession('succeeded'),
      );
      expect(session.giving?.creatorNet, isNull);
    });
  });

  group('the pending gift list', () {
    test('remembers several gifts at once', () async {
      // Giving sessions coexist; one slot would make the second gift's return
      // link unrecognisable, and an unrecognised link is silently ignored.
      final store = InMemoryPendingGivingStore();
      await store.remember('a');
      await store.remember('b');
      expect(await store.has('a'), isTrue);
      expect(await store.has('b'), isTrue);
    });

    test('the newest gift is first and never duplicated', () async {
      final store = InMemoryPendingGivingStore();
      await store.remember('a');
      await store.remember('b');
      await store.remember('a');
      expect(await store.sessions, ['a', 'b']);
    });

    test('a finished gift is forgotten', () async {
      final store = InMemoryPendingGivingStore();
      await store.remember('a');
      await store.forget('a');
      expect(await store.has('a'), isFalse);
    });

    test('the list is capped rather than growing without bound', () async {
      final store = InMemoryPendingGivingStore();
      for (var i = 0; i < 15; i++) {
        await store.remember('s$i');
      }
      final ids = await store.sessions;
      expect(ids, hasLength(SecurePendingGivingStore.maxRemembered));
      expect(ids.first, 's14');
    });

    test('an empty id is not remembered', () async {
      final store = InMemoryPendingGivingStore();
      await store.remember('');
      expect(await store.sessions, isEmpty);
    });
  });

  group('the return link', () {
    test('a gift return is still a checkout return path', () {
      // One path serves both products; the session id decides which.
      expect(
        CheckoutLinkWatcher.sessionIdFrom(
          Uri.parse(
            'https://app.gospeltube.tv/mobile/payments/return?session=g1',
          ),
        ),
        'g1',
      );
    });

    test('an http link is refused', () {
      expect(
        CheckoutLinkWatcher.sessionIdFrom(
          Uri.parse(
            'http://app.gospeltube.tv/mobile/payments/return?session=g1',
          ),
        ),
        isNull,
      );
    });
  });

  group('cancelling a gift', () {
    test('forgets the session even when the server refuses', () async {
      // Cancellation is best-effort by contract: a session whose payment has
      // started stays processing regardless. Keeping the id after a failed
      // cancel would leave a dead attempt matching return links forever.
      final api = _FakeApi()..postError = _refusal(500, 'boom');
      final store = InMemoryPendingGivingStore();
      await store.remember('g1');
      await _service(api, giving: store).cancelGiving('g1');
      expect(await store.has('g1'), isFalse);
    });
  });
}
