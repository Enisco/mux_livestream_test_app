import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/views/go_live_setup_screen.dart';
import 'package:test_app/features/creator/views/widgets/live_broadcast_parts.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

/// `GET /v1/media/live/streams/{id}/studio` exactly as staging answers it.
Map<String, dynamic> _studioBody({
  String runtime = 'live',
  bool isLiveNow = true,
  int viewers = 124,
  int likes = 5,
  int prayers = 4,
  Object? giving = const {
    'giftCount': 3,
    'donorCount': 2,
    'settlementTotals': [
      {
        'currency': 'NGN',
        'provisionalGrossMinor': 1800000,
        'estimatedCreatorNetMinor': 1700000,
      },
    ],
  },
}) => {
  'data': {
    'session': {
      'id': 'ls1',
      'status': 'published',
      'isLiveNow': isLiveNow,
      'livestreamRuntimeStatus': runtime,
      'startedAt': '2026-09-23T14:00:00.000Z',
      'engagementLikeCount': likes,
    },
    'connection': {
      'ingestStatus': 'armed',
      'encoderStatus': 'connected',
      'armedUntil': '2026-09-23T14:15:00.000Z',
      'rtmpIngestUrl': 'rtmps://global-live.mux.com:443/app',
      'streamKeyRef': 'key-1',
    },
    'replay': null,
    'presence': {
      'viewerCount': viewers,
      'peakViewerCount': viewers,
      'revision': 7,
    },
    'metrics': {
      'giving': giving,
      'prayers': {'count': prayers},
    },
  },
};

class _FakeApi implements ApiService {
  _FakeApi({this.body, this.error});

  Map<String, dynamic>? body;
  DioException? error;

  final List<String> paths = [];
  final Map<String, Map<String, dynamic>> sent = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (body ?? const <String, dynamic>{}) as T,
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
    if (data is Map<String, dynamic>) sent[path] = data;
    if (error != null) throw error!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (body ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

DioException _refusal(String sentence, {int status = 400}) => DioException(
  requestOptions: RequestOptions(path: '/live'),
  response: Response(
    requestOptions: RequestOptions(path: '/live'),
    statusCode: status,
    data: {
      'success': false,
      'data': null,
      'error': [sentence],
    },
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(home: child),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('a livestream is its own thing', () {
    test('the session body carries no upload field', () {
      final body = const LiveSessionDraft(
        title: 'Friday Night Prayer',
        description: 'Join us for prayer.',
        categorySlugs: ['prayer'],
        thumbnailFileId: 'f1',
      ).toJson();

      expect(body['title'], 'Friday Night Prayer');
      expect(body['replayPolicy'], 'auto_publish');
      // "Go Live and notify subscribers" is the whole button.
      expect(body['notifyFollowers'], isTrue);
      // Nothing is uploaded, so there is no source to name.
      expect(body.containsKey('sourceUploadId'), isFalse);
      expect(body.containsKey('type'), isFalse);
    });

    test('a title is all it needs to be startable', () {
      expect(const LiveSessionDraft(title: '  ').isReady, isFalse);
      expect(const LiveSessionDraft(title: 'Friday').isReady, isTrue);
    });

    test('runtime states read the way the API writes them', () {
      expect(LiveRuntime.parse('connecting'), LiveRuntime.connecting);
      expect(LiveRuntime.parse('live').isOnAir, isTrue);
      expect(LiveRuntime.parse('idle').isOnAir, isFalse);
      // Connecting and reconnecting are both worth an End button.
      expect(LiveRuntime.connecting.isBroadcasting, isTrue);
      expect(LiveRuntime.reconnecting.isBroadcasting, isTrue);
      expect(LiveRuntime.ended.isBroadcasting, isFalse);
      expect(LiveRuntime.parse('something-new'), LiveRuntime.other);
    });
  });

  group('the studio snapshot', () {
    test('reads presence, likes, prayers and giving', () {
      final studio = LivestreamStudio.fromJson(
        _studioBody()['data']! as Map<String, dynamic>,
      );

      expect(studio.runtime, LiveRuntime.live);
      expect(studio.viewerCount, 124);
      expect(studio.likeCount, 5);
      expect(studio.prayerCount, 4);
      expect(studio.headlineGiving?.currency, 'NGN');
      expect(studio.headlineGiving?.grossMinor, 1800000);
      expect(studio.armedUntil, isNotNull);
    });

    test('unreachable giving stays null rather than becoming zero', () {
      final studio = LivestreamStudio.fromJson(
        _studioBody(giving: null)['data']! as Map<String, dynamic>,
      );

      // The contract: do not render a zero in a fallback currency.
      expect(studio.giving, isNull);
      expect(givingLabel(studio), AppStrings.goLiveNoGiving);
    });

    test('the pill names its currency and reads the money in full', () {
      final studio = LivestreamStudio.fromJson(
        _studioBody()['data']! as Map<String, dynamic>,
      );
      // 1,800,000 minor units → 18,000, and it says which money that is,
      // because settlement currencies are never mixed.
      expect(givingLabel(studio), 'NGN 18,000');
    });

    test('a second currency is never folded into the first', () {
      final studio = LivestreamStudio.fromJson(
        _studioBody(
              giving: const {
                'giftCount': 4,
                'donorCount': 3,
                'settlementTotals': [
                  {'currency': 'NGN', 'provisionalGrossMinor': 1800000},
                  {'currency': 'USD', 'provisionalGrossMinor': 5000},
                ],
              },
            )['data']!
            as Map<String, dynamic>,
      );

      expect(studio.giving, hasLength(2));
      expect(givingLabel(studio), 'NGN 18,000');
    });
  });

  group('the repo', () {
    test('every mutating call carries an idempotency key', () async {
      final api = _FakeApi(
        body: const {
          'data': {'id': 'ls1', 'livestreamRuntimeStatus': 'connecting'},
        },
      );
      final repo = LivestreamRepo(api);

      await repo.armIngest('ls1');
      await repo.start('ls1');
      await repo.end('ls1');

      for (final path in api.sent.keys) {
        expect(
          api.sent[path]!['idempotencyKey'],
          isA<String>().having((k) => k.isNotEmpty, 'not empty', isTrue),
          reason: path,
        );
      }
      expect(api.sent['/v1/media/live/streams/ls1/end']!['reason'], 'creator');
    });

    test(
      'start reports connecting rather than claiming to be on air',
      () async {
        final api = _FakeApi(
          body: const {
            'data': {'livestreamRuntimeStatus': 'connecting'},
          },
        );

        expect(await LivestreamRepo(api).start('ls1'), LiveRuntime.connecting);
      },
    );

    test('a session already running is named a conflict', () async {
      final api = _FakeApi(
        error: _refusal('Another session is already active', status: 409),
      );

      await expectLater(
        LivestreamRepo(api).armIngest('ls1'),
        throwsA(
          isA<LiveException>().having(
            (e) => e.failure,
            'failure',
            LiveFailure.conflict,
          ),
        ),
      );
    });

    test('backing out is best effort and never throws', () async {
      final api = _FakeApi(error: _refusal('nope'));
      // Cancelling a session that has already gone is not worth an error.
      await LivestreamRepo(api).cancel('ls1');
      await LivestreamRepo(api).disableIngest('ls1');
    });
  });

  group('the broadcast pieces', () {
    testWidgets('the end sheet says who it will disconnect', (tester) async {
      final studio = LivestreamStudio.fromJson(
        _studioBody()['data']! as Map<String, dynamic>,
      );

      await _pump(
        tester,
        Scaffold(
          body: EndLivestreamSheet(
            studio: studio,
            replayPolicy: ReplayPolicy.autoPublish,
            onKeep: () {},
            onEnd: () {},
          ),
        ),
      );

      expect(find.text(AppStrings.goLiveEndTitle), findsOneWidget);
      expect(find.textContaining('124 people are watching'), findsOneWidget);
      expect(find.text(AppStrings.goLiveEndReplay), findsOneWidget);
      expect(find.textContaining('4 prayer requests'), findsOneWidget);
      expect(find.text(AppStrings.goLiveKeepStreaming), findsOneWidget);
      expect(find.text(AppStrings.goLiveEndStream), findsOneWidget);
    });

    testWidgets('a discarded recording does not promise a replay', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: EndLivestreamSheet(
            studio: LivestreamStudio.fromJson(
              _studioBody(prayers: 0)['data']! as Map<String, dynamic>,
            ),
            replayPolicy: ReplayPolicy.discard,
            onKeep: () {},
            onEnd: () {},
          ),
        ),
      );

      expect(find.text(AppStrings.goLiveEndReplayNone), findsOneWidget);
      expect(find.text(AppStrings.goLiveEndReplay), findsNothing);
      // No prayers, nothing to say about them.
      expect(find.textContaining('prayer request'), findsNothing);
    });

    test('elapsed time reads as a clock', () {
      expect(formatElapsed(Duration.zero), '0:00');
      expect(formatElapsed(const Duration(seconds: 4)), '0:04');
      expect(formatElapsed(const Duration(minutes: 12, seconds: 5)), '12:05');
      expect(
        formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      // The clock runs from the server's `startedAt`, which can sit a
      // moment ahead of the device's. That used to read "0:-5".
      expect(formatElapsed(const Duration(seconds: -5)), '0:00');
      expect(formatElapsed(const Duration(minutes: -3)), '0:00');
    });

    test('the giving label survives the odd shapes money comes in', () {
      LivestreamStudio withTotal(int minor, String currency) =>
          LivestreamStudio.fromJson({
            'session': const <String, dynamic>{},
            'presence': const <String, dynamic>{},
            'connection': const <String, dynamic>{},
            'metrics': {
              'giving': {
                'settlementTotals': [
                  {'currency': currency, 'provisionalGrossMinor': minor},
                ],
              },
              'prayers': const {'count': 0},
            },
          });

      expect(givingLabel(withTotal(0, 'NGN')), 'NGN 0');
      expect(givingLabel(withTotal(99, 'NGN')), 'NGN 0');
      expect(givingLabel(withTotal(100, 'USD')), 'USD 1');
      expect(givingLabel(withTotal(123456789, 'NGN')), 'NGN 1,234,567');
      // No settlement rows at all is not the same as no giving service.
      final none = LivestreamStudio.fromJson(const {
        'session': <String, dynamic>{},
        'presence': <String, dynamic>{},
        'connection': <String, dynamic>{},
        'metrics': {
          'giving': {'settlementTotals': []},
          'prayers': {'count': 0},
        },
      });
      expect(givingLabel(none), '0');
    });

    testWidgets('the countdown draws 3, 2, 1 and nothing else', (tester) async {
      for (final value in [3, 2, 1]) {
        await _pump(tester, Scaffold(body: LiveCountdown(value: value)));
        expect(find.text('$value'), findsOneWidget);
      }
      await _pump(tester, const Scaffold(body: LiveCountdown(value: 0)));
      expect(find.text('0'), findsNothing);
    });
  });

  group('the setup screen', () {
    Future<void> pumpSetup(WidgetTester tester, {Size? size}) async {
      final api = _FakeApi(
        body: const {
          'data': {'id': 'ls1'},
        },
      );
      await _pump(
        tester,
        GoLiveSetupScreen(
          creatorId: 'c1',
          live: LivestreamRepo(api),
          uploads: MediaUploadRepo(api),
          creators: CreatorRepo(api: api),
        ),
        size: size ?? const Size(390, 1100),
      );
    }

    testWidgets('it asks what the stream is, not for a file', (tester) async {
      await pumpSetup(tester);

      expect(find.text(AppStrings.goLiveTitle), findsOneWidget);
      expect(find.text(AppStrings.goLiveSubtitle), findsOneWidget);
      expect(find.text(AppStrings.goLiveStart), findsOneWidget);
      // Nothing is uploaded to go live.
      expect(find.byKey(const ValueKey('media-select')), findsNothing);
    });

    testWidgets('going live waits for a title', (tester) async {
      await pumpSetup(tester);

      PrimaryButton button() => tester.widget<PrimaryButton>(
        find.byKey(const ValueKey('live-start')),
      );
      expect(button().enabled, isFalse);

      await tester.enterText(
        find.byKey(const ValueKey('live-title')),
        'Friday Night Prayer',
      );
      await tester.pump();
      expect(button().enabled, isTrue);
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      await pumpSetup(tester, size: const Size(320, 1100));
      expect(tester.takeException(), isNull);
    });
  });
}
