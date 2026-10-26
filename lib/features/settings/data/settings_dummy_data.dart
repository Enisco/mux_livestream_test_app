import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The values the account menu reads out.
///
/// `GET /v1/user/profile` is now read on open, so most of this is real: the
/// name, the email, the phone and the chosen topics all come off the account
/// the server holds.
///
/// Since 2026-10-26 the profile also carries `passwordChangedAt`,
/// `twoFactorEnabled` and `language`, so the only thing still read out of a
/// constant here is the Account row's reminder summary — and the reminders
/// screen behind it reads the real preference.
///
/// To retire the last of it: have the Account row read
/// `/v1/notification/preferences` too, or accept one extra request on a menu
/// that already makes two.
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

  /// Real: `passwordChangedAt` arrived on 2026-10-26. **Null means never
  /// changed since registration**, not unknown — the row says so.
  static String get passwordChanged {
    final at = LocalStorage.cachedPasswordChangedAt;
    if (at == null) return AppStrings.settingsPasswordNeverChanged;
    return AppStrings.settingsPasswordChangedOn(_date(at.toLocal()));
  }

  static String _date(DateTime at) =>
      '${at.day} ${_months[at.month - 1]} '
      '${at.year}';

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Real: `twoFactorEnabled` is on every `User` now.
  static String get twoFactorStatus => LocalStorage.cachedTwoFactorEnabled
      ? AppStrings.twoFactorStatusOn
      : AppStrings.twoFactorStatusOff;

  /// The last invented value here. The reminder default is real
  /// (`/v1/notification/preferences`) but lives on the reminders screen,
  /// which reads it directly.
  static const eventReminder = '1 hour before';
}
