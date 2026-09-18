import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/data/two_factor_dummy_data.dart';
import 'package:test_app/features/settings/views/two_factor_screens.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
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
      builder: (context) => MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: AppColors.base1),
        home: child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('the walkthrough', () {
    testWidgets('step one explains what a second factor is', (tester) async {
      await _pump(tester, const TwoFactorIntroScreen());

      expect(find.text(AppStrings.twoFactorHeading), findsOneWidget);
      expect(find.textContaining('TOTP app'), findsOneWidget);
      expect(find.text(AppStrings.twoFactorSetup), findsOneWidget);
    });

    testWidgets('step two shows the secret both ways', (tester) async {
      await _pump(tester, const TwoFactorScanScreen());

      // Scannable, and typeable for anyone whose camera will not cooperate.
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(TwoFactorDummyData.secret), findsOneWidget);
    });

    test('the code encodes a real otpauth URI', () {
      // An authenticator app can only read the standard shape, so the
      // placeholder has to be the right shape even while the secret is fake.
      final uri = TwoFactorDummyData.provisioningUri;
      expect(uri, startsWith('otpauth://totp/'));
      expect(uri, contains('secret=BSWY3DPEHPK3PXP'));
      expect(uri, contains('issuer=GospelTube'));
      expect(uri, contains('digits=6'));
      // The spaces the design prints are for reading, not for the key.
      expect(uri, isNot(contains(' ')));
    });

    testWidgets('tapping the key copies it', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _pump(tester, const TwoFactorScanScreen());
      await tester.tap(find.text(TwoFactorDummyData.secret));
      await tester.pump();

      expect(copied, [TwoFactorDummyData.secret]);
    });

    testWidgets('step three asks for the code the app is showing', (
      tester,
    ) async {
      await _pump(tester, const TwoFactorCodeScreen());

      expect(
        find.textContaining('6-digit code your app shows'),
        findsOneWidget,
      );
      expect(find.text(AppStrings.twoFactorTurnOn), findsOneWidget);
    });

    testWidgets('an incomplete code does not turn anything on', (tester) async {
      await _pump(tester, const TwoFactorCodeScreen());

      await tester.tap(find.text(AppStrings.twoFactorTurnOn));
      await tester.pump();

      expect(find.text(AppStrings.twoFactorNotWired), findsNothing);
    });
  });

  group('the manage screen', () {
    testWidgets('reports the current state and how to re-enrol', (
      tester,
    ) async {
      await _pump(tester, const TwoFactorManageScreen());

      expect(find.text(AppStrings.twoFactorRescan), findsOneWidget);
      expect(find.text(AppStrings.twoFactorBeginSetup), findsOneWidget);
      expect(
        find.textContaining('Lose your phone?', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('the switch reflects the stored state', (tester) async {
      await _pump(tester, const TwoFactorManageScreen());

      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, TwoFactorDummyData.enabled);
      // An "Enabled Jun 9" subtitle under an off switch would contradict it.
      expect(
        find.text(AppStrings.twoFactorOffSub),
        TwoFactorDummyData.enabled ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(
          TwoFactorDummyData.enabled
              ? AppStrings.twoFactorOn
              : AppStrings.twoFactorOff,
        ),
        findsOneWidget,
      );
    });

    testWidgets('flipping it says it cannot be saved yet', (tester) async {
      await _pump(tester, const TwoFactorManageScreen());

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(find.text(AppStrings.twoFactorNotWired), findsOneWidget);
    });
  });

  group('every step survives a small screen', () {
    for (final (name, screen) in <(String, Widget)>[
      ('intro', TwoFactorIntroScreen()),
      ('scan', TwoFactorScanScreen()),
      ('code', TwoFactorCodeScreen()),
      ('manage', TwoFactorManageScreen()),
    ]) {
      testWidgets('$name on a 320pt phone', (tester) async {
        await _pump(tester, screen, size: const Size(320, 568));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
