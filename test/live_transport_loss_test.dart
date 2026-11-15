import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/views/live_broadcast_screen.dart';

/// Losing the RTMP push.
void main() {
  group('what a lost push means', () {
    test('before going live it is fatal for this attempt', () {
      expect(
        LiveLossAction.forPhase(LivePhase.connecting),
        LiveLossAction.fail,
      );
    });

    test('once live it is a drop, so the push is made again', () {
      // The backend is already waiting for the encoder to come back; ending
      // the broadcast outright would throw away a recoverable blip.
      expect(LiveLossAction.forPhase(LivePhase.live), LiveLossAction.repush);
    });

    test('before the push has started there is nothing to lose', () {
      expect(
        LiveLossAction.forPhase(LivePhase.preparing),
        LiveLossAction.ignore,
      );
    });

    test('on the way out it does not matter', () {
      expect(LiveLossAction.forPhase(LivePhase.ending), LiveLossAction.ignore);
    });

    test('and a screen already failed is not failed twice', () {
      expect(LiveLossAction.forPhase(LivePhase.failed), LiveLossAction.ignore);
    });

    test('every phase has an answer', () {
      // A phase added later must be decided deliberately rather than falling
      // through to silence, which is the bug this replaced.
      for (final phase in LivePhase.values) {
        expect(() => LiveLossAction.forPhase(phase), returnsNormally);
      }
    });
  });

  group('waiting for the encoder', () {
    test('the screen gives up long before the backend does', () {
      // The contract gives the provider about fifteen minutes.
      expect(
        LiveBroadcastScreen.connectTimeout,
        lessThan(const Duration(minutes: 2)),
      );
      // But long enough for a slow handshake on a poor connection.
      expect(
        LiveBroadcastScreen.connectTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 30)),
      );
    });
  });
}
