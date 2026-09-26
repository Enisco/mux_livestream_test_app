import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/views/live_broadcast_screen.dart';

/// Losing the RTMP push.
///
/// Reported from the app: going live sat on "Connecting…" for ever. The logs
/// showed exactly why — the push reached Mux, the socket broke
/// (`SocketException: Connection error`), the error was delivered to the
/// screen, and the screen only wrote it to the log:
///
/// ```
/// void _onRtmpError(Exception error) =>
///     logger.e('Live stream error', error: error);
/// ```
///
/// Nothing moved the phase, so the spinner ran while the backend waited out
/// its fifteen-minute patience for an encoder that was never coming back.
/// `onDisconnection` had the same shape.
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
      // The contract gives the provider about fifteen minutes. That is the
      // backend's patience, not a reader's — nothing should watch a spinner
      // for a quarter of an hour.
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
