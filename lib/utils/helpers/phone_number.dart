import 'package:test_app/shared/data/countries.dart';

/// Turns whatever a user types into an E.164 number.
///
/// The two cases that matter globally: people write their number the way their
/// own country prints it — with a national trunk `0` (`0803…`, `07911…`) that
/// must be dropped before the dial code — and people paste a number that
/// already carries its country code (`+2348031234567`, `002348031234567`).
abstract final class PhoneNumber {
  /// Longest E.164 number, dial code included.
  static const maxDigits = 15;

  /// Shortest plausible subscriber number; below this the field is a typo.
  static const minNationalDigits = 4;

  /// The subscriber part alone: digits only, no dial code, no trunk zero.
  static String national(String input, String dialCode) {
    final trimmed = input.trim();
    var digits = _digitsOnly(trimmed);
    if (digits.isEmpty) return '';

    // Only strip the dial code when the user actually wrote the number in
    // international form. Doing it unconditionally would eat a real leading
    // digit — a US number starting with 1, say.
    if (trimmed.startsWith('+') || digits.startsWith('00')) {
      if (digits.startsWith('00')) digits = digits.substring(2);
      if (digits.startsWith(dialCode) && digits.length > dialCode.length) {
        digits = digits.substring(dialCode.length);
      }
    }

    return _withoutTrunkZeros(digits);
  }

  /// `+<dial><national>`, or an empty string when there is nothing to send.
  static String e164(String input, String dialCode) {
    final subscriber = national(input, dialCode);
    return subscriber.isEmpty ? '' : '+$dialCode$subscriber';
  }

  /// Null when valid, otherwise the message to show under the field.
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
