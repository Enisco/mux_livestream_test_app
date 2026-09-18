import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/data/account_form_rules.dart';
import 'package:test_app/features/settings/views/account_forms.dart';
import 'package:test_app/features/settings/views/widgets/settings_form.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setString(
      LocalStorage.cachedUserKey,
      '{"firstName":"Ayomide","lastName":"John",'
      '"email":"ayomide.john@mail.com"}',
    );
  });

  group('naming yourself', () {
    test('both halves are required', () {
      expect(AccountFormRules.name(first: '', last: 'John'), isNotNull);
      expect(AccountFormRules.name(first: 'Ayomide', last: ''), isNotNull);
      expect(AccountFormRules.name(first: '  ', last: '  '), isNotNull);
    });

    test('a full name passes', () {
      expect(AccountFormRules.name(first: 'Ayomide', last: 'John'), isNull);
    });
  });

  group('changing your email', () {
    const current = 'ayomide.john@mail.com';

    test('an empty address is refused', () {
      expect(AccountFormRules.email(value: '', current: current), isNotNull);
    });

    test('something without an @ or a dot is refused', () {
      for (final bad in ['notanemail', 'no@dot', 'no.at.sign', 'a b@c.com']) {
        expect(
          AccountFormRules.email(value: bad, current: current),
          AppStrings.settingsEmailInvalid,
          reason: bad,
        );
      }
    });

    test('the address you already have is refused, whatever its case', () {
      // Otherwise the form would post a change that changes nothing.
      expect(
        AccountFormRules.email(value: current, current: current),
        AppStrings.settingsEmailUnchanged,
      );
      expect(
        AccountFormRules.email(
          value: 'AYOMIDE.JOHN@MAIL.COM',
          current: current,
        ),
        AppStrings.settingsEmailUnchanged,
      );
    });

    test('a genuinely new address passes', () {
      expect(
        AccountFormRules.email(value: 'james@mail.com', current: current),
        isNull,
      );
      // Plus-addressing and subdomains are valid and must not be rejected.
      expect(
        AccountFormRules.email(value: 'a+b@mail.co.uk', current: current),
        isNull,
      );
    });
  });

  group('changing your phone number', () {
    const current = '+234 80 123 234 5678';

    test('too few digits is refused', () {
      expect(
        AccountFormRules.phone(value: '12345', current: current),
        AppStrings.settingsPhoneInvalid,
      );
    });

    test('the same number written differently is still the same number', () {
      // Spacing and punctuation must not disguise an unchanged value.
      expect(
        AccountFormRules.phone(value: '+2348012323456 78', current: current),
        AppStrings.settingsPhoneUnchanged,
      );
      expect(
        AccountFormRules.phone(value: '+234-80-123-234-5678', current: current),
        AppStrings.settingsPhoneUnchanged,
      );
    });

    test('a different number passes', () {
      expect(
        AccountFormRules.phone(value: '+234 90 555 111 2222', current: current),
        isNull,
      );
    });
  });

  group('changing your password', () {
    test('the current one is required first', () {
      expect(
        AccountFormRules.newPassword(
          current: '',
          next: 'abcd1234',
          confirm: 'abcd1234',
        ),
        AppStrings.settingsPasswordRequired,
      );
    });

    test('the rule under the field is the rule enforced', () {
      expect(AccountFormRules.isStrong('abcd1234'), isTrue);
      expect(
        AccountFormRules.isStrong('abcdefgh'),
        isFalse,
        reason: 'no digit',
      );
      expect(
        AccountFormRules.isStrong('12345678'),
        isFalse,
        reason: 'no letter',
      );
      expect(
        AccountFormRules.isStrong('abc1234'),
        isFalse,
        reason: 'too short',
      );
    });

    test('a new password identical to the old one is refused', () {
      expect(
        AccountFormRules.newPassword(
          current: 'abcd1234',
          next: 'abcd1234',
          confirm: 'abcd1234',
        ),
        AppStrings.settingsPasswordSame,
      );
    });

    test('the confirmation has to match', () {
      expect(
        AccountFormRules.newPassword(
          current: 'old12345',
          next: 'abcd1234',
          confirm: 'abcd9999',
        ),
        AppStrings.settingsPasswordMismatch,
      );
    });

    test('a sound change passes', () {
      expect(
        AccountFormRules.newPassword(
          current: 'old12345',
          next: 'abcd1234',
          confirm: 'abcd1234',
        ),
        isNull,
      );
    });
  });

  group('the forms on screen', () {
    testWidgets('the name form opens on the cached account', (tester) async {
      await _pump(tester, const ProfileInfoScreen());

      expect(find.text('Profile info'), findsOneWidget);
      expect(find.text('Ayomide'), findsOneWidget);
      expect(find.text('John'), findsOneWidget);
    });

    testWidgets('an incomplete name is reported rather than submitted', (
      tester,
    ) async {
      await _pump(tester, const ProfileInfoScreen());

      await tester.enterText(find.byType(TextField).last, '');
      await tester.tap(find.text('Update'));
      await tester.pump();

      expect(find.text(AppStrings.settingsNameRequired), findsOneWidget);
    });

    testWidgets('the email form shows the current address, locked', (
      tester,
    ) async {
      await _pump(tester, const ChangeEmailScreen());

      expect(find.text('ayomide.john@mail.com'), findsOneWidget);
      final locked = tester
          .widgetList<SettingsFormField>(find.byType(SettingsFormField))
          .where((f) => f.locked);
      expect(locked, hasLength(1));
    });

    testWidgets('a bad new email is reported under its own field', (
      tester,
    ) async {
      await _pump(tester, const ChangeEmailScreen());

      await tester.enterText(find.byType(TextField).at(1), 'nonsense');
      await tester.tap(find.text('Update'));
      await tester.pump();

      expect(find.text(AppStrings.settingsEmailInvalid), findsOneWidget);
    });

    testWidgets('a password field hides its value and can reveal it', (
      tester,
    ) async {
      await _pump(tester, const ChangePasswordScreen());

      expect(find.text('Show'), findsNWidgets(3));
      await tester.tap(find.text('Show').first);
      await tester.pump();

      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Show'), findsNWidgets(2));
    });

    testWidgets('mismatched passwords are reported', (tester) async {
      await _pump(tester, const ChangePasswordScreen());

      await tester.enterText(find.byType(TextField).at(0), 'old12345');
      await tester.enterText(find.byType(TextField).at(1), 'abcd1234');
      await tester.enterText(find.byType(TextField).at(2), 'different1');
      await tester.tap(find.text('Update'));
      await tester.pump();

      expect(find.text(AppStrings.settingsPasswordMismatch), findsOneWidget);
    });

    testWidgets('the phone form refuses the number already on file', (
      tester,
    ) async {
      await _pump(tester, const ChangePhoneScreen());

      await tester.enterText(
        find.byType(TextField).at(1),
        '+234 80 123 234 5678',
      );
      await tester.tap(find.text('Update'));
      await tester.pump();

      expect(find.text(AppStrings.settingsPhoneUnchanged), findsOneWidget);
    });

    testWidgets('a valid form does not report an error', (tester) async {
      await _pump(tester, const ChangeEmailScreen());

      await tester.enterText(find.byType(TextField).at(1), 'james@mail.com');
      await tester.tap(find.text('Update'));
      await tester.pump();

      expect(find.text(AppStrings.settingsEmailInvalid), findsNothing);
      expect(find.text(AppStrings.settingsEmailUnchanged), findsNothing);
    });
  });
}
