import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/shared/services/api_service.dart';

void main() {
  group('what a 401 means', () {
    test('a guest is never signed out', () {
      // Browsing signed-out with a stale access token used to land the reader
      // on the sign-in screen.
      expect(
        sessionActionFor(hasRefreshToken: false),
        SessionAction.passThrough,
      );
      expect(
        sessionActionFor(
          hasRefreshToken: false,
          outcome: RefreshOutcome.rejected,
        ),
        SessionAction.passThrough,
      );
    });

    test('a successful refresh replays the request', () {
      expect(
        sessionActionFor(
          hasRefreshToken: true,
          outcome: RefreshOutcome.refreshed,
        ),
        SessionAction.retry,
      );
    });

    test('only a refusal ends the session', () {
      expect(
        sessionActionFor(
          hasRefreshToken: true,
          outcome: RefreshOutcome.rejected,
        ),
        SessionAction.endSession,
      );
    });

    test('an unreachable server keeps the session', () {
      // Losing a session because the connection dropped mid-refresh means the
      // reader has to sign in again for no reason.
      expect(
        sessionActionFor(
          hasRefreshToken: true,
          outcome: RefreshOutcome.unavailable,
        ),
        SessionAction.passThrough,
      );
    });

    test('no outcome at all is not a reason to sign out', () {
      expect(
        sessionActionFor(hasRefreshToken: true),
        SessionAction.passThrough,
      );
    });
  });
}
