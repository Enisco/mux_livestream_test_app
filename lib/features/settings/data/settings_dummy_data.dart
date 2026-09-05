import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The values the account menu reads out.
///
/// TEMPORARY, and only partly invented. The reader's name comes from the
/// cached account, and so does the email — the sign-up payload carries it.
/// What has nothing behind it is everything the account menu would need a
/// settings route to know:
///
///  * the phone number, which is collected at sign-up but not cached
///  * when the password last changed
///  * the reader's chosen topics, picked during onboarding but not stored
///  * the event-reminder lead time
///  * whether two-factor is on
///
/// `GET /v1/user/profile` exists in the spec and is the route to wire first —
/// it should carry most of these. To retire this file: delete it and fix the
/// import errors in `settings_screen.dart`.
abstract final class SettingsDummyData {
  /// Real: the cached account carries it. Falls back only if it is missing.
  static String get email =>
      LocalStorage.cachedEmail ?? AppStrings.settingsNotSet;

  static const emailVerified = true;

  static const phone = '+234 80 123 234 5678';
  static const passwordChanged = 'Last changed 3 months ago';
  static const topics = 'Preaching, Worship, Gospel music';
  static const eventReminder = '1 hour before';
  static const twoFactorStatus = 'Off · uses an authenticator app';
}
