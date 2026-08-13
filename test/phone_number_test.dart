import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/auth/views/widgets/auth_widgets.dart';
import 'package:test_app/shared/data/countries.dart';
import 'package:test_app/utils/helpers/phone_number.dart';

void main() {
  final us = Countries.byIsoCode('US')!;
  final ng = Countries.byIsoCode('NG')!;
  final gb = Countries.byIsoCode('GB')!;

  group('PhoneNumber.national', () {
    test('drops the national trunk zero', () {
      expect(PhoneNumber.national('08031234567', ng.dialCode), '8031234567');
      expect(PhoneNumber.national('07911123456', gb.dialCode), '7911123456');
    });

    test('strips formatting characters', () {
      expect(PhoneNumber.national('(415) 555-2671', us.dialCode), '4155552671');
      expect(PhoneNumber.national(' 415 555 2671 ', us.dialCode), '4155552671');
    });

    test('drops a dial code the user typed in international form', () {
      expect(PhoneNumber.national('+2348031234567', ng.dialCode), '8031234567');
      expect(
        PhoneNumber.national('002348031234567', ng.dialCode),
        '8031234567',
      );
      expect(
        PhoneNumber.national('+234 803 123 4567', ng.dialCode),
        '8031234567',
      );
    });

    test('keeps a leading digit that merely looks like the dial code', () {
      // National form, so the leading 1 is part of the subscriber number.
      expect(PhoneNumber.national('1415552671', us.dialCode), '1415552671');
    });

    test('handles trunk zero after an international prefix', () {
      expect(PhoneNumber.national('+2340803123456', ng.dialCode), '803123456');
    });

    test('returns empty for nothing usable', () {
      expect(PhoneNumber.national('', us.dialCode), '');
      expect(PhoneNumber.national('   ', us.dialCode), '');
      expect(PhoneNumber.national('000', us.dialCode), '');
    });
  });

  group('PhoneNumber.e164', () {
    test('joins the dial code to the subscriber number', () {
      expect(PhoneNumber.e164('08031234567', ng.dialCode), '+2348031234567');
      expect(PhoneNumber.e164('(415) 555-2671', us.dialCode), '+14155552671');
    });

    test('is idempotent on an already-complete number', () {
      expect(PhoneNumber.e164('+2348031234567', ng.dialCode), '+2348031234567');
    });

    test('stays empty rather than sending a bare dial code', () {
      expect(PhoneNumber.e164('', ng.dialCode), '');
    });
  });

  group('PhoneNumber.validate', () {
    test('requires a value', () {
      expect(PhoneNumber.validate(null, us), isNotNull);
      expect(PhoneNumber.validate('  ', us), isNotNull);
    });

    test('rejects too short and too long', () {
      expect(PhoneNumber.validate('123', us), isNotNull);
      expect(PhoneNumber.validate('12345678901234567', us), isNotNull);
    });

    test('accepts real numbers in either form', () {
      expect(PhoneNumber.validate('08031234567', ng), isNull);
      expect(PhoneNumber.validate('+2348031234567', ng), isNull);
      expect(PhoneNumber.validate('(415) 555-2671', us), isNull);
    });
  });

  group('WordCapitalizationInputFormatter', () {
    const formatter = WordCapitalizationInputFormatter();

    String format(String input) => formatter
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: input,
            selection: TextSelection.collapsed(offset: input.length),
          ),
        )
        .text;

    test('capitalises each word', () {
      expect(format('sodiq'), 'Sodiq');
      expect(format('mary jane'), 'Mary Jane');
      expect(format('anne-marie'), 'Anne-Marie');
      expect(format("o'brien"), "O'Brien");
    });

    test('leaves the rest of the word as typed', () {
      expect(format('McDonald'), 'McDonald');
      expect(format('van der BERG'), 'Van Der BERG');
    });

    test('keeps the caret in place', () {
      const value = TextEditingValue(
        text: 'john doe',
        selection: TextSelection.collapsed(offset: 4),
      );
      final result = formatter.formatEditUpdate(TextEditingValue.empty, value);
      expect(result.text, 'John Doe');
      expect(result.selection.baseOffset, 4);
    });
  });
}
