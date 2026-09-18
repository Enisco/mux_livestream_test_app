import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/views/confirm_change_screen.dart';
import 'package:test_app/shared/components/otp_code_field.dart';
import 'package:test_app/shared/components/otp_verification_view.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
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

/// Types a full code into the slots.
Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(OtpCodeField),
      matching: find.byType(EditableText),
    ),
    code,
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('the screen renders at all', () {
    // This is the bug that shipped: the footer was given a negative
    // EdgeInsets, so Padding asserted and the screen showed the error page
    // instead of the code entry. Any exception here fails the test.
    testWidgets('on a normal phone', (tester) async {
      await _pump(tester, _view());
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.checkYourMail), findsOneWidget);
    });

    testWidgets('on a 320pt phone', (tester) async {
      await _pump(tester, _view(), size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no safe-area padding reported', (tester) async {
      // The first frame can arrive before the insets do, which is exactly
      // when the old negative padding blew up.
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.view.viewPadding = FakeViewPadding.zero;
      tester.view.padding = FakeViewPadding.zero;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MaterialApp(home: _view()),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a very long destination does not burst the copy', (
      tester,
    ) async {
      await _pump(
        tester,
        _view(destination: 'averyveryverylongaddress@someverylongdomain.com'),
        size: const Size(320, 568),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('verifying', () {
    testWidgets('Verify stays disabled until the code is complete', (
      tester,
    ) async {
      var attempts = 0;
      await _pump(
        tester,
        _view(
          onVerify: (_) async {
            attempts++;
            return null;
          },
        ),
      );

      await tester.tap(find.text(AppStrings.verify));
      await tester.pump();
      expect(attempts, 0, reason: 'an empty code must not be submitted');

      await _enterCode(tester, '123456');
      await tester.pump();
      expect(attempts, 1, reason: 'a complete code submits on its own');
    });

    testWidgets('a rejected code shows what went wrong', (tester) async {
      await _pump(
        tester,
        _view(onVerify: (_) async => 'That code did not work.'),
      );

      await _enterCode(tester, '123456');
      await tester.pump();

      expect(find.text('That code did not work.'), findsOneWidget);
    });

    testWidgets('an accepted code leaves no error behind', (tester) async {
      await _pump(tester, _view(onVerify: (_) async => null));

      await _enterCode(tester, '123456');
      await tester.pump();

      expect(find.textContaining('did not work'), findsNothing);
    });
  });

  group('resending', () {
    testWidgets('is locked while the countdown runs', (tester) async {
      var sent = 0;
      await _pump(
        tester,
        _view(
          onResend: () async {
            sent++;
            return null;
          },
        ),
      );

      // A 60-second cooldown reads as 1:00 on the first frame.
      expect(find.textContaining('1:00', findRichText: true), findsOneWidget);
      await tester.tapOnText(find.textRange.ofSubstring(AppStrings.sendAgain));
      await tester.pump();
      expect(sent, 0);

      // Let the clock run out.
      await tester.pump(const Duration(seconds: 60));
      await tester.tapOnText(find.textRange.ofSubstring(AppStrings.sendAgain));
      await tester.pump();
      expect(sent, 1);
    });

    testWidgets('the countdown restarts only when a code actually went', (
      tester,
    ) async {
      await _pump(tester, _view(onResend: () async => 'Could not send.'));
      await tester.pump(const Duration(seconds: 60));

      await tester.tapOnText(find.textRange.ofSubstring(AppStrings.sendAgain));
      await tester.pump();

      expect(find.text('Could not send.'), findsOneWidget);
      // No countdown came back, so the reader can try again at once.
      expect(find.textContaining('1:00', findRichText: true), findsNothing);
    });

    testWidgets('the timer stops when the screen goes away', (tester) async {
      await _pump(tester, _view());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });

  group('the settings confirmation', () {
    testWidgets('names the address the code went to', (tester) async {
      await _pump(
        tester,
        const ConfirmChangeScreen.email(destination: 'james@mail.com'),
      );

      expect(
        find.textContaining('james@mail.com', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(AppStrings.settingsConfirmEmailTitle), findsOneWidget);
    });

    testWidgets('a phone change says messages, not mail', (tester) async {
      await _pump(
        tester,
        const ConfirmChangeScreen.phone(destination: '+234 90 555 1111'),
      );
      expect(find.text(AppStrings.settingsConfirmPhoneTitle), findsOneWidget);
    });

    testWidgets('it admits it cannot confirm anything yet', (tester) async {
      await _pump(
        tester,
        const ConfirmChangeScreen.email(destination: 'james@mail.com'),
      );

      await _enterCode(tester, '123456');
      await tester.pump();

      expect(find.text(AppStrings.settingsOtpNotWired), findsOneWidget);
    });
  });
}

OtpVerificationView _view({
  String destination = 'progress@mail.com',
  Future<String?> Function(String)? onVerify,
  Future<String?> Function()? onResend,
}) => OtpVerificationView(
  destination: destination,
  onVerify: onVerify ?? (_) async => null,
  onResend: onResend ?? () async => null,
);
