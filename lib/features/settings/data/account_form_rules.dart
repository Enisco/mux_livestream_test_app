import 'package:test_app/utils/app_constants/app_strings.dart';

/// What each account form will accept, kept away from the widgets so the rules
/// can be read and tested on their own.
///
/// These are the client's half of the bargain only. Nothing here proves a
/// password is right or an address is free — that is the server's answer, and
/// none of these forms can ask for it yet.
abstract final class AccountFormRules {
  /// Deliberately loose: something, an @, something with a dot in it. Anything
  /// stricter rejects addresses that are perfectly valid.
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Null when the name is usable, otherwise what is wrong with it.
  static String? name({required String first, required String last}) {
    if (first.trim().isEmpty || last.trim().isEmpty) {
      return AppStrings.settingsNameRequired;
    }
    return null;
  }

  static String? email({required String value, required String current}) {
    final next = value.trim();
    if (next.isEmpty) return AppStrings.settingsEmailRequired;
    if (!_email.hasMatch(next)) return AppStrings.settingsEmailInvalid;
    if (next.toLowerCase() == current.trim().toLowerCase()) {
      return AppStrings.settingsEmailUnchanged;
    }
    return null;
  }

  static String? phone({required String value, required String current}) {
    final next = value.trim();
    if (next.isEmpty) return AppStrings.settingsPhoneRequired;
    // Count digits rather than characters: the reader may have typed spaces,
    // dashes or a leading +.
    if (next.replaceAll(RegExp(r'\D'), '').length < 7) {
      return AppStrings.settingsPhoneInvalid;
    }
    if (_digits(next) == _digits(current)) {
      return AppStrings.settingsPhoneUnchanged;
    }
    return null;
  }

  /// The rule printed under the field: eight characters, a letter, a digit.
  static bool isStrong(String value) =>
      value.length >= 8 &&
      value.contains(RegExp(r'[A-Za-z]')) &&
      value.contains(RegExp(r'\d'));

  static String? newPassword({
    required String current,
    required String next,
    required String confirm,
  }) {
    if (current.isEmpty) return AppStrings.settingsPasswordRequired;
    if (!isStrong(next)) return AppStrings.settingsPasswordWeak;
    if (next == current) return AppStrings.settingsPasswordSame;
    if (next != confirm) return AppStrings.settingsPasswordMismatch;
    return null;
  }

  static String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');
}
