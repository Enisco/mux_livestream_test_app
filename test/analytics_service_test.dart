import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/app_session_service.dart';
import 'package:test_app/shared/services/connectivity_service.dart';
import 'package:test_app/shared/services/device_info_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

class _FakeApi extends ApiService {
  _FakeApi({required super.tokenStorage, required super.deviceInfo});

  final List<String> paths = [];
  final List<List<Map<String, dynamic>>> batches = [];

  final Map<String, int> failures = {};

  List<Map<String, dynamic>> get allEvents =>
      batches.expand((b) => b).toList(growable: false);

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    final events = ((data as Map<String, dynamic>)['events'] as List)
        .cast<Map<String, dynamic>>();
    batches.add(events);

    for (final entry in failures.entries) {
      if (path.contains(entry.key)) {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: path),
            statusCode: entry.value,
          ),
        );
      }
    }
    return Response<T>(requestOptions: RequestOptions(path: path));
  }
}

class _FakeTokenStorage extends TokenStorageService {
  _FakeTokenStorage(this.signedIn);
  bool signedIn;

  @override
  Future<bool> get hasSession async => signedIn;
}

class _FakeDeviceInfo extends DeviceInfoService {
  @override
  String get platform => 'ios';
  @override
  String get appVersion => '1.0.0';
  @override
  String get deviceType => 'phone';
}

class _FakeConnectivity extends ConnectivityService {
  _FakeConnectivity(this._type);
  final String _type;
  @override
  String get networkType => _type;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeApi api;
  late _FakeTokenStorage tokens;
  late AppSessionService session;
  late AnalyticsService analytics;

  const promotion = PromotionAttribution(
    campaignId: 'camp_1',
    placement: 'vertical_feed',
    deliveryId: 'signed_token',
  );

  Future<AnalyticsService> build({required bool signedIn}) async {
    dotenv.testLoad(fileInput: 'BASE_URL=https://example.test');
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();

    final deviceInfo = _FakeDeviceInfo();
    tokens = _FakeTokenStorage(signedIn);
    api = _FakeApi(tokenStorage: tokens, deviceInfo: deviceInfo);
    session = AppSessionService();
    await session.init();

    return AnalyticsService(
      api: api,
      deviceInfo: deviceInfo,
      session: session,
      tokenStorage: tokens,
      connectivity: _FakeConnectivity('cellular'),
    );
  }

  group('guest (anonymous) viewer', () {
    setUp(() async => analytics = await build(signedIn: false));

    test('posts to the anonymous batch route only', () async {
      analytics.trackViewStarted(
        mediaId: 'm1',
        creatorId: 'c1',
        mediaType: MediaTypes.video,
        source: AnalyticsSource.homeFeed,
      );
      await analytics.flushNow();

      expect(api.paths, ['/v1/analytics/beacons']);
      expect(api.paths.any((p) => p.contains('/auth')), isFalse);
    });

    test('carries an anonymousViewerId in place of the web cookie', () async {
      analytics.trackViewStarted(mediaId: 'm1', creatorId: 'c1');
      await analytics.flushNow();

      final identity = api.allEvents.single['identity'] as Map<String, dynamic>;
      expect(identity['sessionId'], session.analyticsSessionId);
      expect(identity['anonymousViewerId'], session.anonymousViewerId);
      expect(identity['anonymousViewerId'], isNotEmpty);
    });
  });

  group('authenticated viewer', () {
    setUp(() async => analytics = await build(signedIn: true));

    test('prefers the authenticated batch route', () async {
      analytics.trackViewStarted(mediaId: 'm1', creatorId: 'c1');
      await analytics.flushNow();

      expect(api.paths, ['/v1/analytics/beacons/auth']);
    });

    test(
      'falls back to the optional-auth route without losing events',
      () async {
        api.failures['/beacons/auth'] = 403;

        analytics.trackViewStarted(mediaId: 'm1', creatorId: 'c1');
        await analytics.flushNow();

        expect(api.paths, [
          '/v1/analytics/beacons/auth',
          '/v1/analytics/beacons',
        ]);
        expect(api.batches.last.single['mediaId'], 'm1');

        analytics.trackPlay(mediaId: 'm2', creatorId: 'c1');
        await analytics.flushNow();
        expect(api.paths.where((p) => p.endsWith('/auth')).length, 1);
      },
    );
  });

  group('beacon payload', () {
    setUp(() async => analytics = await build(signedIn: false));

    test('includes mediaType, networkType, and watch duration', () async {
      analytics.trackViewEnded(
        mediaId: 'm1',
        creatorId: 'c1',
        mediaType: MediaTypes.livestream,
        positionSeconds: 42.5,
        watchDurationSeconds: 30.25,
        source: AnalyticsSource.homeFeed,
      );
      await analytics.flushNow();

      final event = api.allEvents.single;
      expect(event['eventType'], 'view_ended');
      expect(event['mediaType'], 'livestream');
      expect(event['positionSeconds'], 42.5);
      expect(event['watchDurationSeconds'], 30.25);
      expect(event['source'], 'home_feed');
      expect((event['client'] as Map)['networkType'], 'cellular');
      expect(event['eventId'], isNotEmpty);
    });

    test('omits mediaType rather than guessing when unknown', () async {
      analytics.trackViewStarted(mediaId: 'm1', creatorId: 'c1');
      await analytics.flushNow();
      expect(api.allEvents.single.containsKey('mediaType'), isFalse);
    });
  });

  group('promoted placements', () {
    setUp(() async => analytics = await build(signedIn: false));

    test('click emits click + promotion_click in one batch', () async {
      analytics.trackContentClick(
        mediaId: 'm1',
        creatorId: 'c1',
        mediaType: MediaTypes.video,
        source: AnalyticsSource.homeFeed,
        promotion: promotion,
      );
      await analytics.flushNow();

      final types = api.batches.single.map((e) => e['eventType']).toList();
      expect(types, ['click', 'promotion_click']);

      final paid = api.batches.single[1];
      expect(paid['promotionCampaignId'], 'camp_1');
      expect(paid['promotionPlacement'], 'vertical_feed');
      expect(paid['promotionDeliveryId'], 'signed_token');
      expect(api.batches.single[0].containsKey('promotionDeliveryId'), isFalse);
    });

    test('an organic click emits click only', () async {
      analytics.trackContentClick(
        mediaId: 'm1',
        creatorId: 'c1',
        source: AnalyticsSource.homeFeed,
      );
      await analytics.flushNow();
      expect(api.allEvents.map((e) => e['eventType']), ['click']);
    });

    test('a double tap does not bill the same delivery twice', () async {
      for (var i = 0; i < 3; i++) {
        analytics.trackContentClick(
          mediaId: 'm1',
          creatorId: 'c1',
          source: AnalyticsSource.homeFeed,
          promotion: promotion,
        );
      }
      await analytics.flushNow();

      final paid = api.allEvents.where(
        (e) => e['eventType'] == 'promotion_click',
      );
      expect(paid.length, 1);
      expect(api.allEvents.where((e) => e['eventType'] == 'click').length, 3);
    });

    test(
      'qualified impression is sent once per delivery per session',
      () async {
        for (var i = 0; i < 3; i++) {
          analytics.trackPromotedQualifiedImpression(
            mediaId: 'm1',
            creatorId: 'c1',
            mediaType: MediaTypes.video,
            source: AnalyticsSource.homeFeed,
            promotion: promotion,
            visibleDurationMs: 1500,
          );
        }
        await analytics.flushNow();

        final impressions = api.allEvents.where(
          (e) => e['eventType'] == 'promoted_qualified_impression',
        );
        expect(impressions.length, 1);
        expect(impressions.single['visibleDurationMs'], 1500);
      },
    );

    test(
      'qualified impression eventId is stable so retries are idempotent',
      () async {
        analytics.trackPromotedQualifiedImpression(
          mediaId: 'm1',
          creatorId: 'c1',
          source: AnalyticsSource.homeFeed,
          promotion: promotion,
          visibleDurationMs: 1500,
        );
        await analytics.flushNow();
        final firstId = api.allEvents.single['eventId'] as String;

        final twin = AnalyticsService(
          api: api,
          deviceInfo: _FakeDeviceInfo(),
          session: session,
          tokenStorage: tokens,
          connectivity: _FakeConnectivity('wifi'),
        );
        twin.trackPromotedQualifiedImpression(
          mediaId: 'm1',
          creatorId: 'c1',
          source: AnalyticsSource.homeFeed,
          promotion: promotion,
          visibleDurationMs: 1500,
        );
        await twin.flushNow();

        expect(api.allEvents.last['eventId'], firstId);
      },
    );
  });

  group('delivery reliability', () {
    setUp(() async => analytics = await build(signedIn: false));

    test('a 5xx requeues the batch instead of dropping it', () async {
      api.failures['/beacons'] = 503;
      analytics.trackViewStarted(mediaId: 'm1', creatorId: 'c1');
      await analytics.flushNow();
      expect(api.batches.length, 1);

      api.failures.clear();
      await analytics.flushNow();

      expect(api.batches.length, 2);
      expect(api.batches.last.single['mediaId'], 'm1');
    });

    test('a rejected payload (4xx) is dropped, not retried forever', () async {
      api.failures['/beacons'] = 400;
      analytics.trackViewStarted(mediaId: 'm1', creatorId: 'c1');
      await analytics.flushNow();

      api.failures.clear();
      await analytics.flushNow();

      expect(api.batches.length, 1);
    });
  });
}
