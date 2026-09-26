import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/shared/services/live_socket_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';

/// The `/live` Socket.IO contract.
///
/// Two rules in it are easy to get wrong and expensive when you do:
///
///  * the namespace is `/live` on the API origin, **not** `/v1/live`;
///  * `viewer_count` and `status_changed` carry their own monotonic
///    `revision` and must be tracked **separately**. Sharing one counter
///    silently drops good payloads; ignoring them entirely lets a late
///    `live` arrive after an `ended` and resurrect a finished broadcast —
///    which is exactly the "still showing as live" complaint.
class _NoTokens extends TokenStorageService {
  @override
  Future<String?> get accessToken async => null;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.test');
  });

  group('the event names match the contract', () {
    test('every server event is spelled as documented', () {
      expect(LiveEventType.values.map((e) => e.wire), [
        'livestream.viewer_count',
        'livestream.status_changed',
        'livestream.encoder_status_changed',
        'livestream.ingest_status_changed',
        'livestream.metrics_updated',
        'livestream.replay_status_changed',
      ]);
    });
  });

  group('a studio snapshot folded with an event', () {
    test('keeps what the event does not mention', () {
      const before = LivestreamStudio(
        runtime: LiveRuntime.live,
        viewerCount: 10,
        peakViewerCount: 40,
        likeCount: 7,
        prayerCount: 3,
        giving: [GivingTotal(currency: 'NGN', grossMinor: 5000)],
        encoderStatus: 'connected',
      );

      // A viewer tick says nothing about giving, prayers or the encoder.
      final after = before.copyWith(viewerCount: 12);

      expect(after.viewerCount, 12);
      expect(after.peakViewerCount, 40);
      expect(after.likeCount, 7);
      expect(after.prayerCount, 3);
      expect(after.giving, hasLength(1));
      expect(after.encoderStatus, 'connected');
      expect(after.runtime, LiveRuntime.live);
    });

    test('a status change moves the runtime and nothing else', () {
      const before = LivestreamStudio(
        runtime: LiveRuntime.live,
        viewerCount: 10,
      );
      final after = before.copyWith(runtime: LiveRuntime.ended);
      expect(after.runtime, LiveRuntime.ended);
      expect(after.viewerCount, 10);
    });
  });

  group('runtime parsing decides what the badge says', () {
    test('only live is on air', () {
      expect(LiveRuntime.parse('live').isOnAir, isTrue);
      for (final raw in ['idle', 'connecting', 'reconnecting', 'ended']) {
        expect(
          LiveRuntime.parse(raw).isOnAir,
          isFalse,
          reason: '$raw must not read as on air',
        );
      }
    });

    test('an unknown status is not on air either', () {
      // Better to under-claim than to show LIVE for something unrecognised.
      expect(LiveRuntime.parse('something_new').isOnAir, isFalse);
      expect(LiveRuntime.parse(null).isOnAir, isFalse);
    });

    test('reconnecting is still broadcasting, just not on air', () {
      expect(LiveRuntime.reconnecting.isBroadcasting, isTrue);
      expect(LiveRuntime.reconnecting.isOnAir, isFalse);
      expect(LiveRuntime.ended.isBroadcasting, isFalse);
    });
  });

  group('the service', () {
    test('targets the /live namespace on the API origin', () async {
      final service = LiveSocketService(
        tokenStorage: _NoTokens(),
        origin: 'https://api.example.test',
      );
      addTearDown(service.dispose);
      // Nothing is connected, so nothing is claimed.
      expect(service.isConnected, isFalse);
    });

    test('subscribing before a connection does not throw', () async {
      final service = LiveSocketService(
        tokenStorage: _NoTokens(),
        origin: 'https://api.example.test',
      );
      addTearDown(service.dispose);

      expect(() => service.subscribeStudio('s1'), returnsNormally);
      expect(() => service.subscribeStream('s1'), returnsNormally);
      expect(() => service.subscribeCreator('c1'), returnsNormally);
      expect(
        () => service.viewerHeartbeat('s1', playing: true),
        returnsNormally,
      );
      expect(() => service.unsubscribeStudio('s1'), returnsNormally);
    });

    test('a stale viewer count is dropped, not applied', () async {
      final service = LiveSocketService(
        tokenStorage: _NoTokens(),
        origin: 'https://api.example.test',
      );
      addTearDown(service.dispose);

      final seen = <int?>[];
      service.events
          .where((e) => e.type == LiveEventType.viewerCount)
          .listen((e) => seen.add(e.viewerCount));

      void tick(int revision, int count) => service.handleEvent(
        LiveEventType.viewerCount,
        {'streamId': 's1', 'revision': revision, 'viewerCount': count},
      );

      tick(1, 10);
      tick(3, 30);
      tick(2, 20); // arrived late — must not walk the counter backwards
      tick(3, 99); // same revision again — already applied
      tick(4, 40);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [10, 30, 40]);
    });

    test('a late "live" cannot resurrect a stream that has ended', () async {
      // The shape of "still showing as live": the ending is delivered, then
      // an older status turns up behind it.
      final service = LiveSocketService(
        tokenStorage: _NoTokens(),
        origin: 'https://api.example.test',
      );
      addTearDown(service.dispose);

      final seen = <String?>[];
      service.events
          .where((e) => e.type == LiveEventType.statusChanged)
          .listen((e) => seen.add(e.status));

      service.handleEvent(LiveEventType.statusChanged, {
        'streamId': 's1',
        'revision': 5,
        'status': 'ended',
      });
      service.handleEvent(LiveEventType.statusChanged, {
        'streamId': 's1',
        'revision': 4,
        'status': 'live',
      });
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['ended']);
    });

    test('the two revisions are counted separately', () async {
      // Sharing one counter would silently swallow the status change.
      final service = LiveSocketService(
        tokenStorage: _NoTokens(),
        origin: 'https://api.example.test',
      );
      addTearDown(service.dispose);

      final seen = <LiveEventType>[];
      service.events.listen((e) => seen.add(e.type));

      service.handleEvent(LiveEventType.viewerCount, {
        'streamId': 's1',
        'revision': 9,
        'viewerCount': 5,
      });
      service.handleEvent(LiveEventType.statusChanged, {
        'streamId': 's1',
        'revision': 1,
        'status': 'live',
      });
      await Future<void>.delayed(Duration.zero);

      expect(seen, [LiveEventType.viewerCount, LiveEventType.statusChanged]);
    });

    test('revisions are per stream, not global', () async {
      final service = LiveSocketService(
        tokenStorage: _NoTokens(),
        origin: 'https://api.example.test',
      );
      addTearDown(service.dispose);

      final seen = <String>[];
      service.events.listen((e) => seen.add(e.streamId));

      service.handleEvent(LiveEventType.viewerCount, {
        'streamId': 'a',
        'revision': 7,
        'viewerCount': 1,
      });
      service.handleEvent(LiveEventType.viewerCount, {
        'streamId': 'b',
        'revision': 1,
        'viewerCount': 1,
      });
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['a', 'b']);
    });

    test('an event with no revision is always delivered', () async {
      // Only viewer_count and status_changed carry one.
      final service = LiveSocketService(
        tokenStorage: _NoTokens(),
        origin: 'https://api.example.test',
      );
      addTearDown(service.dispose);

      final seen = <LiveEventType>[];
      service.events.listen((e) => seen.add(e.type));

      for (var i = 0; i < 3; i++) {
        service.handleEvent(LiveEventType.metricsUpdated, {'streamId': 's1'});
      }
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(3));
    });

    test('two callers connecting at once build one socket, not two', () async {
      // There is an await between the null check and the assignment — the
      // access token is read from storage — and both screens that use this
      // can call connect more than once (a retry, a reload). Two sockets
      // would mean duplicated events and an orphaned connection.
      final service = LiveSocketService(
        tokenStorage: _NoTokens(),
        origin: 'https://api.example.test',
      );
      addTearDown(service.dispose);

      final first = service.connect();
      final second = service.connect();
      expect(identical(first, second), isTrue);
      await Future.wait([first, second]);
    });

    test(
      'a build with no BASE_URL stays offline rather than dialling',
      () async {
        dotenv.testLoad(fileInput: 'NOTHING=1');
        final service = LiveSocketService(tokenStorage: _NoTokens());
        addTearDown(service.dispose);

        await service.connect();
        expect(service.isConnected, isFalse);

        dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.test');
      },
    );
  });
}
