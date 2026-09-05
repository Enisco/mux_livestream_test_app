import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/data/settings_dummy_data.dart';
import 'package:test_app/features/settings/views/widgets/settings_row.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The account menu: everything about the reader's own account, and the way
/// into each thing that can be changed.
///
/// This is the entry point of a larger section — name, email, phone, password,
/// topics, reminders, two-factor and deactivation each have screens of their
/// own in the design that are not built yet. Every row here says so rather than
/// going nowhere.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _todo(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what is not built yet', style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        LocalStorage.cachedFullName ??
        LocalStorage.cachedFirstName ??
        AppStrings.accountFallbackName;
    final email = SettingsDummyData.email;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 24.s),
              child: Row(
                children: [
                  const GTubeBackButton(size: 24, box: 24),
                  SizedBox(width: 12.s),
                  Text(
                    AppStrings.settingsTitle,
                    style: AppStyles.label(
                      18,
                      weight: AppStyles.bold,
                      lineHeight: 28 / 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(25.s, 0, 10.s, 40.s),
                children: [
                  SettingsSection(
                    caption: AppStrings.settingsProfile,
                    children: [
                      SettingsRow(
                        leading: SettingsAvatar(name: name),
                        title: name,
                        subtitle: AppStrings.settingsDisplayNamePhoto,
                        action: AppStrings.settingsEdit,
                        onTap: () => _todo(context, 'Editing your profile'),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedMail01,
                        title: AppStrings.settingsEmail,
                        subtitle: email,
                        subtitleVerified: SettingsDummyData.emailVerified,
                        action: AppStrings.settingsChange,
                        onTap: () =>
                            _todo(context, 'Changing your email address'),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedCall,
                        title: AppStrings.settingsPhone,
                        subtitle: SettingsDummyData.phone,
                        action: AppStrings.settingsChange,
                        onTap: () =>
                            _todo(context, 'Changing your phone number'),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedSquareLock01,
                        title: AppStrings.settingsPassword,
                        subtitle: SettingsDummyData.passwordChanged,
                        action: AppStrings.settingsChange,
                        onTap: () => _todo(context, 'Changing your password'),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedFlag01,
                        title: AppStrings.settingsLanguage,
                        subtitle: AppStrings.settingsLanguageValue,
                        showChevron: true,
                        onTap: () => _todo(context, 'Choosing a language'),
                      ),
                    ],
                  ),
                  SizedBox(height: 42.s),
                  SettingsSection(
                    caption: AppStrings.settingsPreferences,
                    children: [
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedDashboardSquare01,
                        title: AppStrings.settingsTopics,
                        subtitle: SettingsDummyData.topics,
                        showChevron: true,
                        onTap: () => _todo(context, AppStrings.settingsTopics),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedNotification03,
                        title: AppStrings.settingsEventReminders,
                        subtitle: SettingsDummyData.eventReminder,
                        showChevron: true,
                        onTap: () =>
                            _todo(context, AppStrings.settingsEventReminders),
                      ),
                    ],
                  ),
                  SizedBox(height: 42.s),
                  SettingsSection(
                    caption: AppStrings.settingsSecurity,
                    children: [
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedShieldUser,
                        title: AppStrings.settingsTwoFactor,
                        subtitle: SettingsDummyData.twoFactorStatus,
                        showChevron: true,
                        onTap: () =>
                            _todo(context, AppStrings.settingsTwoFactor),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedComputerPhoneSync,
                        title: AppStrings.settingsLogOutAll,
                        subtitle: AppStrings.settingsLogOutAllSub,
                        showChevron: true,
                        onTap: () =>
                            _todo(context, AppStrings.settingsLogOutAll),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedUserRemove01,
                        title: AppStrings.settingsDeactivate,
                        destructive: true,
                        showChevron: true,
                        onTap: () =>
                            _todo(context, AppStrings.settingsDeactivate),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
