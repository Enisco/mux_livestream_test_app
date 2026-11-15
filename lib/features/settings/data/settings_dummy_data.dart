import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The values the account menu reads out.
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
