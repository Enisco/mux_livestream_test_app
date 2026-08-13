import 'package:test_app/shared/data/countries.dart';

abstract final class PhoneNumber {
  static const maxDigits = 15;

  static const minNationalDigits = 4;

  static String national(String input, String dialCode) {
    final trimmed = input.trim();
    var digits = _digitsOnly(trimmed);
    if (digits.isEmpty) return '';

    // Only strip the dial code in international form, or a national number
    // that merely starts with those digits loses one.
    if (trimmed.startsWith('+') || digits.startsWith('00')) {
      if (digits.startsWith('00')) digits = digits.substring(2);
      if (digits.startsWith(dialCode) && digits.length > dialCode.length) {
        digits = digits.substring(dialCode.length);
      }
    }

    return _withoutTrunkZeros(digits);
  }

  static String e164(String input, String dialCode) {
    final subscriber = national(input, dialCode);
    return subscriber.isEmpty ? '' : '+$dialCode$subscriber';
  }

  static String? validate(String? input, Country country) {
    if (input == null || input.trim().isEmpty) {
      return 'Phone number is required';
    }
    final subscriber = national(input, country.dialCode);
    if (subscriber.length < minNationalDigits ||
        subscriber.length + country.dialCode.length > maxDigits) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static String _withoutTrunkZeros(String digits) {
    var i = 0;
    while (i < digits.length && digits[i] == '0') {
      i++;
    }
    return digits.substring(i);
  }
}
