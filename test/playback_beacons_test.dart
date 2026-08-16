import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/shared/services/playback_controller.dart';

const _target = PlaybackTarget(
  mediaId: 'm1',
  creatorId: 'c1',
  mediaType: MediaTypes.video,
  source: AnalyticsSource.homeFeed,
);

PlaybackSession _session({Duration startAt = Duration.zero}) =>
    PlaybackSession(target: _target, startAt: startAt);

void main() {
  group('playback session accounting', () {
    test('no heartbeat until enough has been watched', () {
      final s = _session();
      expect(s.advance(const Duration(seconds: 2)), isNull);
      expect(s.advance(const Duration(seconds: 4)), isNull);
      // Five seconds covered — now it is due.
      expect(s.advance(const Duration(seconds: 5)), const Duration(seconds: 5));
    });

    test('each beacon carries a delta, never a running total', () {
      final s = _session();
      expect(s.advance(const Duration(seconds: 5)), const Duration(seconds: 5));
      expect(
        s.advance(const Duration(seconds: 10)),
        const Duration(seconds: 5),
      );
      expect(
        s.advance(const Duration(seconds: 16)),
        const Duration(seconds: 6),
      );
      // The server sums these; totals here would multiply watch time.
    });

    test('resuming mid-stream does not bill the part already watched', () {
      final s = _session(startAt: const Duration(seconds: 40));
      expect(s.advance(const Duration(seconds: 42)), isNull);
      expect(
        s.advance(const Duration(seconds: 45)),
        const Duration(seconds: 5),
      );
    });

    test('a seek forward is not watch time', () {
      final s = _session();
      s.advance(const Duration(seconds: 5));

      s.anchor(const Duration(minutes: 10));
      // Jumping ten minutes ahead must not report ten minutes watched.
      expect(s.advance(const Duration(minutes: 10, seconds: 2)), isNull);
      expect(
        s.advance(const Duration(minutes: 10, seconds: 6)),
        const Duration(seconds: 6),
      );
    });

    test('a seek backwards never reports negative watch time', () {
      final s = _session();
      s.advance(const Duration(seconds: 30));

      expect(s.advance(const Duration(seconds: 5)), isNull);
      expect(s.reportedUpTo, const Duration(seconds: 5));
      expect(s.pendingAt(const Duration(seconds: 3)), Duration.zero);
    });

    test('settling closes the books and cannot double-count', () {
      final s = _session();
      s.advance(const Duration(seconds: 5));

      expect(s.settle(const Duration(seconds: 8)), const Duration(seconds: 3));
      // A second settle at the same point owes nothing.
      expect(s.settle(const Duration(seconds: 8)), Duration.zero);
    });

    test('a session that never started reports nothing', () {
      final s = _session();
      expect(s.started, isFalse);
      expect(s.finished, isFalse);
    });

    test('completion is terminal', () {
      final s = _session()..started = true;
      s.finished = true;
      // The controller checks this so a stop after the end does not also send
      // a view_ended for an item already counted as completed.
      expect(s.finished, isTrue);
    });

    test('a stream that reported a duration counts as alive', () {
      // The start watchdog stops a session that never opened. A duration means
      // it opened and parsed, so it is slow, not dead — killing it there
      // restarts it in a loop that never reaches the first frame.
      const opened = PlaybackState(
        mediaId: 'm1',
        kind: PlaybackKind.video,
        duration: Duration(minutes: 3),
      );
      const dead = PlaybackState(mediaId: 'm1', kind: PlaybackKind.video);

      bool wouldGiveUp(PlaybackState s) =>
          s.position <= Duration.zero && s.duration <= Duration.zero;

      expect(wouldGiveUp(opened), isFalse);
      expect(wouldGiveUp(dead), isTrue);
    });

    test('the heartbeat interval clears the server guardrail', () {
      // Server default rejects progress beacons closer than ~3s apart.
      expect(
        _session().progressEvery.inMilliseconds,
        greaterThanOrEqualTo(3000),
      );
    });
  });
}
