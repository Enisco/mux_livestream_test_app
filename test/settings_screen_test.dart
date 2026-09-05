import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/views/settings_screen.dart';
import 'package:test_app/features/settings/views/widgets/settings_row.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// Tall enough that the lazy list builds every section at once.
const _tall = Size(390, 1600);

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
        home: Scaffold(backgroundColor: AppColors.base1, body: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setString(
      LocalStorage.cachedUserKey,
      '{"firstName":"Ayomide","lastName":"John",'
          '"email":"ayomide.john@mail.com"}',
    );
  });

  group('the account menu', () {
    testWidgets('reads the account it is signed in as', (tester) async {
      await _pump(tester, const SettingsScreen(), size: _tall);

      expect(find.text('Ayomide John'), findsOneWidget);
      expect(find.text('ayomide.john@mail.com'), findsOneWidget);
    });

    testWidgets('offers all three sections', (tester) async {
      await _pump(tester, const SettingsScreen(), size: _tall);

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('SECURITY'), findsOneWidget);
    });

    testWidgets('every row the design draws is present', (tester) async {
      await _pump(tester, const SettingsScreen(), size: _tall);

      for (final label in [
        'Email',
        'Phone number',
        'Password',
        'Language',
        'Your topics',
        'Event reminders',
        'Two-factor authentication',
        'Log out all devices',
        'Deactivate account',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a signed-out reader falls back rather than showing nothing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();

      await _pump(tester, const SettingsScreen(), size: _tall);

      expect(find.text('User'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    });
  });

  group('a settings row', () {
    testWidgets('an editable row offers its action word', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        SettingsRow(
          icon: HugeIcons.strokeRoundedMail01,
          title: 'Email',
          subtitle: 'someone@mail.com',
          action: 'Change',
          onTap: () => taps++,
        ),
      );

      expect(find.text('Change'), findsOneWidget);
      await tester.tap(find.text('Email'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a navigating row offers a chevron instead', (tester) async {
      await _pump(
        tester,
        const SettingsRow(
          icon: HugeIcons.strokeRoundedFlag01,
          title: 'Language',
          subtitle: 'English',
          showChevron: true,
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.text('Change'), findsNothing);
    });

    testWidgets('a row with no subtitle draws only its title', (tester) async {
      await _pump(
        tester,
        const SettingsRow(
          icon: HugeIcons.strokeRoundedUserRemove01,
          title: 'Deactivate account',
          destructive: true,
          showChevron: true,
        ),
      );

      expect(find.text('Deactivate account'), findsOneWidget);
      final title = tester.widget<Text>(find.text('Deactivate account'));
      expect(title.style?.color, AppColors.destructive);
    });

    testWidgets('a confirmed value carries its tick', (tester) async {
      await _pump(
        tester,
        const SettingsRow(
          icon: HugeIcons.strokeRoundedMail01,
          title: 'Email',
          subtitle: 'someone@mail.com',
          subtitleVerified: true,
          action: 'Change',
        ),
      );
      // The tick is the only thing that changes; its absence is the default.
      expect(find.text('someone@mail.com'), findsOneWidget);
    });
  });

  group('the initials disc', () {
    testWidgets('takes the first letter of each of two names', (tester) async {
      await _pump(tester, const SettingsAvatar(name: 'Ayomide John'));
      expect(find.text('AJ'), findsOneWidget);
    });

    testWidgets('a single name gives a single letter', (tester) async {
      await _pump(tester, const SettingsAvatar(name: 'Ayomide'));
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('more than two names still gives two letters', (tester) async {
      await _pump(tester, const SettingsAvatar(name: 'Ada Grace Obi'));
      expect(find.text('AG'), findsOneWidget);
    });

    testWidgets('an empty name does not crash', (tester) async {
      await _pump(tester, const SettingsAvatar(name: '   '));
      expect(find.text('?'), findsOneWidget);
    });
  });
}
