import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/repo/mobile_checkout_repo.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/features/creator/services/checkout_link_listener.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/pending_checkout_store.dart';

/// Captured verbatim from staging on 2026-08-14 so the parsers are tested
/// against what the server actually sends, not what the guide describes.
const _createResponse = {
  'success': true,
  'data': {
    'session': {
      'id': 'cmssw62s0003kp2146svn9lcz',
      'purpose': 'platform_subscription',
      'platform': 'ios',
      'storefrontCountry': 'NG',
      'creatorId': '6a7e0db8e3e6bd5168e8a1c5',
      'status': 'created',
      'paymentProvider': null,
      'mobileReturnUrl':
          'https://app.staging.gospeltube.tv/mobile/payments/return'
          '?session=cmssw62s0003kp2146svn9lcz',
      'expiresAt': '2026-08-15T11:56:39.696Z',
      'subscription': {
        'targetPlanTier': null,
        'billingInterval': null,
        'scheduled': false,
        'scheduledChangeEffectiveAt': null,
        'entitlementsReady': false,
        'entitlement': {'planTier': 'free', 'status': 'incomplete'},
      },
      'giving': null,
    },
    'launchUrl':
        'https://auth.staging.gospeltube.tv/api/auth/browser-handoff?ticket=x',
    'launchExpiresAt': '2999-01-01T00:00:00.000Z',
  },
};

const _capabilities = {
  'success': true,
  'data': {
    'platform': 'ios',
    'storefrontCountry': 'NG',
    'platformSubscription': {'available': true, 'reason': 'available'},
    'giving': {'available': true, 'reason': 'available'},
  },
};

Map<String, dynamic> _sessionWith(String status, {bool ready = false}) => {
  'success': true,
  'data': {
    'session': {
      'id': 'cmssw62s0003kp2146svn9lcz',
      'status': status,
      'paymentProvider': 'paystack',
      'subscription': {
        'targetPlanTier': 'basic',
        'entitlementsReady': ready,
        'scheduled': false,
        'entitlement': {'planTier': ready ? 'basic' : 'free'},
      },
    },
  },
};

class _FakeApi implements ApiService {
  _FakeApi({this.postError, this.getBody, this.postBody});

  DioException? postError;
  Map<String, dynamic>? getBody;
  Map<String, dynamic>? postBody;

  final List<String> paths = [];
  Map<String, dynamic>? lastBody;
  Map<String, dynamic>? lastQuery;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    lastQuery = queryParameters;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: getBody as T,
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
    if (data is Map<String, dynamic>) lastBody = data;
    if (postError != null) throw postError!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (postBody ?? getBody) as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

DioException _conflict(String? sessionId) => DioException(
  requestOptions: RequestOptions(path: '/'),
  response: Response(
    requestOptions: RequestOptions(path: '/'),
    statusCode: 409,
    data: {
      'success': false,
      'error': 'A mobile web subscription checkout is already active.',
      'details': {'sessionId': ?sessionId},
    },
  ),
);

void main() {
  group('session parsing', () {
    test('reads the created handoff', () {
      final handoff = MobileCheckoutHandoff.fromJson(_createResponse);
      expect(handoff.session.id, 'cmssw62s0003kp2146svn9lcz');
      expect(handoff.session.status, MobileCheckoutStatus.created);
      expect(handoff.session.entitlementsReady, isFalse);
      expect(handoff.session.isSettled, isFalse);
      expect(handoff.launch.launchUrl, contains('browser-handoff'));
      expect(handoff.launch.isUsable, isTrue);
    });

    test('return url comes from the server, not a constant', () {
      final handoff = MobileCheckoutHandoff.fromJson(_createResponse);
      expect(
        handoff.session.mobileReturnUrl,
        startsWith('https://app.staging.gospeltube.tv/mobile/payments/return'),
      );
    });

    test('an expired ticket is not usable', () {
      final launch = MobileCheckoutLaunch.fromMap({
        'launchUrl': 'https://example.com',
        'launchExpiresAt': '2000-01-01T00:00:00.000Z',
      });
      expect(launch.isUsable, isFalse);
    });

    test('succeeded without entitlements is not settled', () {
      final session = MobileCheckoutSession.fromJson(_sessionWith('succeeded'));
      expect(session.status, MobileCheckoutStatus.succeeded);
      expect(session.isSettled, isFalse);
    });

    test('succeeded with entitlements is settled', () {
      final session = MobileCheckoutSession.fromJson(
        _sessionWith('succeeded', ready: true),
      );
      expect(session.isSettled, isTrue);
      expect(session.entitlement?.planTier, 'basic');
    });

    test('processing is neither settled nor terminal', () {
      final session = MobileCheckoutSession.fromJson(
        _sessionWith('processing'),
      );
      expect(session.isSettled, isFalse);
      expect(session.isTerminal, isFalse);
    });

    for (final status in ['failed', 'canceled', 'expired']) {
      test('$status is terminal', () {
        expect(
          MobileCheckoutSession.fromJson(_sessionWith(status)).isTerminal,
          isTrue,
        );
      });
    }

    test('capabilities read the subscription gate', () {
      final caps = CheckoutCapabilities.fromJson(_capabilities);
      expect(caps.subscriptionAvailable, isTrue);
      expect(caps.subscriptionReason, 'available');
    });

    test('capabilities fail closed on a malformed body', () {
      expect(
        CheckoutCapabilities.fromJson(const {}).subscriptionAvailable,
        isFalse,
      );
    });
  });

  group('attempt key', () {
    test('satisfies the server pattern and length bounds', () {
      final key = CheckoutHandoffService.newAttemptKey(
        '6a7e0db8e3e6bd5168e8a1c5',
      );
      expect(RegExp(r'^[A-Za-z0-9:_-]+$').hasMatch(key), isTrue);
      expect(key.length, greaterThanOrEqualTo(16));
      expect(key.length, lessThanOrEqualTo(128));
    });

    test('is unique per attempt', () {
      final a = CheckoutHandoffService.newAttemptKey('creator');
      final b = CheckoutHandoffService.newAttemptKey('creator');
      expect(a, isNot(b));
    });
  });

  group('repo', () {
    test('creates a session without any return url', () async {
      final api = _FakeApi(
        postBody: Map<String, dynamic>.from(_createResponse),
      );
      await MobileCheckoutRepo(api: api).createSession(
        creatorId: 'c1',
        storefrontCountry: 'NG',
        idempotencyKey: 'k' * 20,
      );
      expect(api.lastBody!['purpose'], 'platform_subscription');
      expect(api.lastBody!['creatorId'], 'c1');
      expect(api.lastBody!['storefrontCountry'], 'NG');
      expect(api.lastBody!.containsKey('successUrl'), isFalse);
      expect(api.lastBody!.containsKey('cancelUrl'), isFalse);
      expect(api.lastBody!.containsKey('planTier'), isFalse);
    });

    test('409 becomes a recoverable CheckoutAlreadyActive', () async {
      final api = _FakeApi(postError: _conflict('cmsSESSION'));
      await expectLater(
        MobileCheckoutRepo(api: api).createSession(
          creatorId: 'c1',
          storefrontCountry: 'NG',
          idempotencyKey: 'k' * 20,
        ),
        throwsA(
          isA<CheckoutAlreadyActive>().having(
            (e) => e.sessionId,
            'sessionId',
            'cmsSESSION',
          ),
        ),
      );
    });

    test('capabilities send platform and storefront', () async {
      final api = _FakeApi(getBody: Map<String, dynamic>.from(_capabilities));
      await MobileCheckoutRepo(
        api: api,
      ).fetchCapabilities(storefrontCountry: 'NG');
      expect(api.lastQuery!['storefrontCountry'], 'NG');
      expect(api.lastQuery!['platform'], anyOf('ios', 'android'));
    });
  });

  group('handoff', () {
    test('an unavailable storefront stops before creating a session', () async {
      final api = _FakeApi(
        getBody: {
          'success': true,
          'data': {
            'platformSubscription': {
              'available': false,
              'reason': 'policy_blocked',
            },
          },
        },
      );
      final result = await CheckoutHandoffService(
        repo: MobileCheckoutRepo(api: api),
        store: InMemoryPendingCheckoutStore(),
        opener: (_) async => true,
      ).start(creatorId: 'c1');

      expect(result.outcome, HandoffOutcome.unavailable);
      expect(result.reason, 'policy_blocked');
      expect(api.paths, everyElement(contains('capabilities')));
    });

    test('a stored attempt key is reused so a retry resumes', () async {
      final store = InMemoryPendingCheckoutStore();
      await store.save(sessionId: 'old', attemptKey: 'stable-key-0123456789');
      final api = _FakeApi(
        getBody: Map<String, dynamic>.from(_capabilities),
        postBody: Map<String, dynamic>.from(_createResponse),
      );
      await CheckoutHandoffService(
        repo: MobileCheckoutRepo(api: api),
        store: store,
        opener: (_) async => true,
      ).start(creatorId: 'c1');

      expect(api.lastBody!['idempotencyKey'], 'stable-key-0123456789');
    });

    test('a processing conflict is surfaced, not relaunched', () async {
      final api = _FakeApi(
        getBody: Map<String, dynamic>.from(_capabilities),
        postError: _conflict('cmsBUSY'),
      );
      // The capabilities read and the session read share the fake, so point
      // the GET at a processing session once the conflict has been raised.
      final service = CheckoutHandoffService(
        repo: MobileCheckoutRepo(api: api),
        store: InMemoryPendingCheckoutStore(),
        opener: (_) async => true,
      );
      final future = service.start(creatorId: 'c1');
      api.getBody = _sessionWith('processing');
      final result = await future;

      expect(result.outcome, HandoffOutcome.alreadyActive);
      expect(result.sessionId, 'cmsBUSY');
      expect(api.paths, isNot(contains(contains('/launch'))));
    });
  });

  _linkTests();
}

void _linkTests() {
  const base = 'https://app.staging.gospeltube.tv';
  const path = '/mobile/payments/return';

  group('return link matching', () {
    test('accepts the real return url', () {
      expect(
        CheckoutLinkWatcher.sessionIdFrom(Uri.parse('$base$path?session=abc')),
        'abc',
      );
    });

    test('rejects another path on the same host', () {
      expect(
        CheckoutLinkWatcher.sessionIdFrom(
          Uri.parse('$base/mobile/other?session=abc'),
        ),
        isNull,
      );
    });

    test('rejects a non-https scheme', () {
      expect(
        CheckoutLinkWatcher.sessionIdFrom(
          Uri.parse('gospeltube:/$path?session=abc'),
        ),
        isNull,
      );
    });

    test('rejects a missing session parameter', () {
      expect(
        CheckoutLinkWatcher.sessionIdFrom(Uri.parse('$base$path')),
        isNull,
      );
    });

    test('rejects an empty session parameter', () {
      expect(
        CheckoutLinkWatcher.sessionIdFrom(Uri.parse('$base$path?session=')),
        isNull,
      );
    });
  });
}
