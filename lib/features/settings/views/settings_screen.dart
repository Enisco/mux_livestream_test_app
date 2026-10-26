import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/settings/data/settings_dummy_data.dart';
import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/features/settings/views/account_forms.dart';
import 'package:test_app/features/settings/views/account_sheets.dart';
import 'package:test_app/features/settings/views/event_reminders_screen.dart';
import 'package:test_app/features/settings/views/hidden_creators_screen.dart';
import 'package:test_app/features/settings/views/language_screen.dart';
import 'package:test_app/features/settings/views/two_factor_screens.dart';
import 'package:test_app/features/settings/views/widgets/settings_row.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The account menu: everything about the reader's own account, and the way
/// into each thing that can be changed.
///
/// What it reads is the cached account, refreshed from `GET /v1/user/profile`
/// on open so a change made on another device shows here. Profile info is the
/// one row behind it that writes; see `ProfileInfoScreen` for which fields the
/// account route will take.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  /// Not worth an error state: a read that fails leaves the cached account on
  /// screen, which is what was true at the last login.
  Future<void> _refresh() async {
    try {
      await AccountRepo().fetchProfile();
      if (mounted) setState(() {});
    } catch (e) {
      logger.w('Account profile unavailable', error: e);
    }
  }

  /// Push a settings screen and rebuild from the cache it may have replaced.
  ///
  /// Every credential route answers with the updated `User`, which the repo
  /// caches — so the menu behind only needs to re-read it.
  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(builder: (_) => screen),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final name =
        LocalStorage.cachedFullName ??
        LocalStorage.cachedFirstName ??
        AppStrings.accountFallbackName;
    final email = SettingsDummyData.email;
    final avatar = AssetUrlResolver.resolve(LocalStorage.cachedAvatarKey);

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
                        leading: SettingsAvatar(name: name, imageUrl: avatar),
                        title: name,
                        subtitle: AppStrings.settingsDisplayNamePhoto,
                        action: AppStrings.settingsEdit,
                        // The form writes the account and replaces the
                        // cache, so this rebuilds from it on the way back.
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => const ProfileInfoScreen(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedMail01,
                        title: AppStrings.settingsEmail,
                        subtitle: email,
                        subtitleVerified: SettingsDummyData.emailVerified,
                        action: AppStrings.settingsChange,
                        onTap: () => _open(const ChangeEmailScreen()),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedCall,
                        title: AppStrings.settingsPhone,
                        subtitle: SettingsDummyData.phone,
                        action: AppStrings.settingsChange,
                        onTap: () => _open(const ChangePhoneScreen()),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedSquareLock01,
                        title: AppStrings.settingsPassword,
                        subtitle: SettingsDummyData.passwordChanged,
                        action: AppStrings.settingsChange,
                        onTap: () => _open(const ChangePasswordScreen()),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedFlag01,
                        title: AppStrings.settingsLanguage,
                        subtitle: languageLabel(LocalStorage.cachedLanguage),
                        showChevron: true,
                        onTap: () => _open(const LanguageScreen()),
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
                        onTap: () => TopicsSheet.show(context),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedNotification03,
                        title: AppStrings.settingsEventReminders,
                        subtitle: SettingsDummyData.eventReminder,
                        showChevron: true,
                        onTap: () => _open(const EventRemindersScreen()),
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
                        onTap: () => _open(const TwoFactorScreen()),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedVolumeOff,
                        title: AppStrings.hiddenTitle,
                        subtitle: AppStrings.hiddenRowSub,
                        showChevron: true,
                        onTap: () => _open(const HiddenCreatorsScreen()),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedComputerPhoneSync,
                        title: AppStrings.settingsLogOutAll,
                        subtitle: AppStrings.settingsLogOutAllSub,
                        showChevron: true,
                        onTap: () => LogOutAllDialog.show(context),
                      ),
                      SettingsRow(
                        icon: HugeIcons.strokeRoundedUserRemove01,
                        title: AppStrings.settingsDeactivate,
                        destructive: true,
                        showChevron: true,
                        onTap: () => DeactivateAccountDialog.show(context),
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
