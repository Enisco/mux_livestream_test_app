import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/shared/services/screen_wakelock.dart';

/// The screen locking mid-broadcast.
///
/// Reported from the app: a livestream was running and the phone locked
/// itself. A creator talking to a camera is not touching the phone, so the
/// idle timer has nothing to go on and will always win.
void main() {
  group('holding the screen awake', () {
    test(
      'a hold turns auto-lock off, and letting go turns it back on',
      () async {
        final asked = <bool>[];
        final wakelock = ScreenWakelock(set: (on) async => asked.add(on));

        await wakelock.hold();
        expect(asked, [true]);

        await wakelock.release();
        expect(asked, [true, false]);
      },
    );

    test(
      'two holders, and the first to let go does not undo the second',
      () async {
        // The reason this counts instead of switching: whichever holder
        // finishes first would otherwise leave the screen locking under the
        // one still broadcasting.
        final asked = <bool>[];
        final wakelock = ScreenWakelock(set: (on) async => asked.add(on));

        await wakelock.hold();
        await wakelock.hold();
        await wakelock.release();

        expect(asked, [true], reason: 'still held, so nothing changed');
        expect(wakelock.holds, 1);

        await wakelock.release();
        expect(asked, [true, false]);
      },
    );

    test('and re-holding does not ask twice for what it already has', () async {
      final asked = <bool>[];
      final wakelock = ScreenWakelock(set: (on) async => asked.add(on));

      await wakelock.hold();
      await wakelock.hold();
      await wakelock.hold();

      expect(asked, [true]);
    });

    test('a release nobody asked for leaves no debt behind', () async {
      // Going below zero would mean the next real hold started from a
      // deficit and never reached the plugin at all, which is the screen
      // locking mid-broadcast again by a different route.
      final asked = <bool>[];
      final wakelock = ScreenWakelock(set: (on) async => asked.add(on));

      await wakelock.release();
      expect(asked, isEmpty);
      expect(wakelock.holds, 0);

      await wakelock.hold();
      expect(asked, [true]);
    });

    test(
      'and a platform that refuses does not take the broadcast with it',
      () async {
        final wakelock = ScreenWakelock(
          set: (_) async => throw Exception('no such plugin'),
        );

        await expectLater(wakelock.hold(), completes);
        await expectLater(wakelock.release(), completes);
      },
    );
  });
}
