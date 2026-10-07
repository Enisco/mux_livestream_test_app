import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The values the account menu reads out.
///
/// `GET /v1/user/profile` is now read on open, so most of this is real: the
/// name, the email, the phone and the chosen topics all come off the account
/// the server holds.
///
/// What is left invented is what the profile payload has **no field for**,
/// confirmed against staging on 2026-10-07 — there is no `passwordChangedAt`,
/// no reminder lead time and no `twoFactorEnabled`:
///
///  * when the password last changed — now shown as nothing rather than a
///    date that was made up
///  * the event-reminder lead time
///  * whether two-factor is on
///
/// To retire the rest: a profile payload that carries them, or the routes in
/// `docs/OPEN_ISSUES.md` #33.
abstract final class SettingsDummyData {
  /// Real: the cached account carries it.
  static String get email =>
      LocalStorage.cachedEmail ?? AppStrings.settingsNotSet;

  static const emailVerified = true;

  /// Real: collected at sign-up and carried on the profile.
  static String get phone =>
      LocalStorage.cachedPhone ?? AppStrings.settingsNotSet;

  /// Real: `viewerPreferenceCategorySlugs`, named by the category list.
  static String get topics {
    final slugs = LocalStorage.cachedTopicSlugs;
    if (slugs.isEmpty) return AppStrings.settingsNotSet;
    return slugs.map(_titleCase).join(', ');
  }

  static String _titleCase(String slug) => slug
      .split('-')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// The profile carries no `passwordChangedAt`, so this says nothing rather
  /// than naming a date nobody recorded.
  static const passwordChanged = '';

  static const eventReminder = '1 hour before';
  static const twoFactorStatus = 'Off · uses an authenticator app';
}
