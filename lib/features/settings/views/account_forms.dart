import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/creator_asset_repo.dart'
    show AssetUploadFailure;
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/features/settings/data/account_form_rules.dart';
import 'package:test_app/features/settings/data/settings_dummy_data.dart';
import 'package:test_app/features/settings/views/confirm_change_screen.dart';
import 'package:test_app/features/settings/views/widgets/settings_form.dart';
import 'package:test_app/features/settings/views/widgets/settings_row.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The four screens the account menu's rows lead to. **All four are wired.**
///
/// The email and password routes arrived on 2026-10-26
/// (`docs/mobile-api-gap-responses.md` §3.1, §3.2); before that these two
/// forms validated and then said they could not save.
///
/// Three things the routes insist on, which shape these screens:
///
/// - **The email code goes to the new address**, so the OTP screen names it
///   and the password is proved here, before any mail is sent.
/// - **A wrong password or a wrong code is a `401` that must not be retried**
///   — it is slow by design, and five wrong answers lock the password proof
///   across all three credential routes for fifteen minutes.
/// - **The password change spares this session** by sending the refresh
///   token, and says so in `currentSessionRetained`. That is read, not
///   assumed: without it the next call 401s and the reader is stranded.

void showAccountSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppStyles.body(13)),
      backgroundColor: AppColors.neutral800,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// What to put under the field when a credential route refuses.
///
/// The backend asks that its own wording for a wrong password or a wrong code
/// be shown as-is: both are deliberately identical and deliberately vague,
/// because an authenticated route that takes a password is a password oracle
/// for anyone holding a stolen access token.
String accountFailureMessage(AccountException e) => switch (e.failure) {
  AccountFailure.network => AppStrings.settingsOffline,
  AccountFailure.expired => AppStrings.settingsExpiredRestart,
  AccountFailure.locked || AccountFailure.cooldown =>
    e.retryAt == null
        ? AppStrings.settingsTryLater
        : AppStrings.settingsLockedUntil(formatClock(e.retryAt!)),
  _ => e.message ?? AppStrings.settingsSaveFailed,
};

String formatClock(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute${local.hour < 12 ? 'am' : 'pm'}';
}

/// Display name and photo.
class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  late final _first = TextEditingController(
    text: LocalStorage.cachedFirstName ?? '',
  );
  late final _last = TextEditingController(text: _lastNameFromCache());
  final _repo = AccountRepo();
  String? _error;
  bool _busy = false;
  String? _avatarUrl = AssetUrlResolver.resolve(LocalStorage.cachedAvatarKey);

  static String _lastNameFromCache() {
    final full = LocalStorage.cachedFullName ?? '';
    final first = LocalStorage.cachedFirstName ?? '';
    return full.startsWith(first) ? full.substring(first.length).trim() : '';
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  /// `PATCH /v1/user/{id}` with the two fields it accepts.
  ///
  /// The screen pops on success so the account menu behind it rebuilds from
  /// the cache the write just replaced.
  Future<void> _submit() async {
    final problem = AccountFormRules.name(first: _first.text, last: _last.text);
    setState(() => _error = problem);
    if (problem != null || _busy) return;

    setState(() => _busy = true);
    try {
      await _repo.updateAccount(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
      );
      if (!mounted) return;
      _say(AppStrings.settingsNameSaved);
      Navigator.pop(context, true);
    } catch (e) {
      logger.w('Name update failed', error: e);
      if (!mounted) return;
      setState(() => _busy = false);
      _say(AppStrings.settingsSaveFailed);
    }
  }

  /// Pick, upload, confirm. The photo only exists once it is confirmed, so
  /// nothing is shown as changed until the route has answered.
  Future<void> _changePhoto() async {
    if (_busy) return;
    final picked = await CreatorImagePicker.pick(
      maxBytes: AccountRepo.avatarMaxBytes,
    );
    if (picked.isCancelled || !mounted) return;
    if (picked.failure case final why?) {
      _say(switch (why) {
        PickFailure.tooLarge => AppStrings.settingsPhotoTooLarge,
        _ => AppStrings.settingsPhotoUnreadable,
      });
      return;
    }

    setState(() => _busy = true);
    final result = await _repo.uploadAvatar(picked.image!);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.fileId != null) {
        _avatarUrl = AssetUrlResolver.resolve(LocalStorage.cachedAvatarKey);
      }
    });
    _say(switch (result.failure) {
      null => AppStrings.settingsPhotoSaved,
      AssetUploadFailure.tooLarge => AppStrings.settingsPhotoTooLarge,
      AssetUploadFailure.network => AppStrings.settingsPhotoOffline,
      AssetUploadFailure.rejected => AppStrings.settingsSaveFailed,
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = '${_first.text} ${_last.text}'.trim();

    return SettingsFormScaffold(
      title: AppStrings.settingsProfileInfo,
      onAction: () => unawaited(_submit()),
      busy: _busy,
      children: [
        Center(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomRight,
                children: [
                  SettingsAvatar(
                    name: name.isEmpty ? AppStrings.accountFallbackName : name,
                    size: 80,
                    imageUrl: _avatarUrl,
                  ),
                  Positioned(
                    right: 2.s,
                    bottom: 2.s,
                    child: Container(
                      width: 22.s,
                      height: 22.s,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandPrimary,
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCamera01,
                          color: AppColors.base1,
                          size: 12.s,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.s),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_changePhoto()),
                child: Text(
                  AppStrings.settingsChangePhoto,
                  style: AppStyles.label(13, color: AppColors.neutral400),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 32.s),
        SettingsFormField(
          label: AppStrings.settingsDisplayName,
          controller: _first,
          hint: AppStrings.settingsFirstNameHint,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          error: _error,
        ),
        SettingsFormField(
          label: '',
          controller: _last,
          hint: AppStrings.settingsLastNameHint,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

/// Change email address.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _current = TextEditingController(text: SettingsDummyData.email);
  final _next = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _password.dispose();
    super.dispose();
  }

  final _repo = AccountRepo();
  bool _busy = false;

  /// Ask for a code, then hand over to the OTP screen.
  ///
  /// The password is proved here rather than on the code screen, so a wrong
  /// one is caught before an email goes anywhere.
  Future<void> _submit() async {
    final problem = AccountFormRules.email(
      value: _next.text,
      current: _current.text,
    );
    setState(() => _error = problem);
    if (problem != null || _busy) return;
    if (_password.text.isEmpty) {
      setState(() => _error = AppStrings.settingsPasswordRequired);
      return;
    }

    setState(() => _busy = true);
    try {
      final challenge = await _repo.requestEmailChange(
        newEmail: _next.text,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmChangeScreen.email(challenge: challenge),
        ),
      );
      if ((done ?? false) && mounted) {
        _say(AppStrings.settingsEmailChanged);
        Navigator.pop(context, true);
      }
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = accountFailureMessage(e);
      });
    } catch (e) {
      logger.w('Email change failed', error: e);
      if (!mounted) return;
      setState(() => _busy = false);
      _say(AppStrings.settingsSaveFailed);
    }
  }

  void _say(String message) => showAccountSnack(context, message);

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.settingsChangeEmailTitle,
      onAction: () => unawaited(_submit()),
      busy: _busy,
      children: [
        const SettingsFormNotice(text: AppStrings.settingsEmailNotice),
        SettingsFormField(
          label: AppStrings.settingsCurrentEmail,
          controller: _current,
          hint: '',
          locked: true,
        ),
        SettingsFormField(
          label: AppStrings.settingsNewEmail,
          controller: _next,
          hint: 'you@mail.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          error: _error,
        ),
        SettingsFormField(
          label: AppStrings.settingsPassword,
          controller: _password,
          hint: '',
          obscure: true,
          helper: AppStrings.settingsPasswordRule,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

/// Change phone number.
class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _current = TextEditingController(text: SettingsDummyData.phone);
  final _next = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  final _repo = AccountRepo();
  bool _busy = false;

  /// **A phone number is not verified.** `PATCH /v1/user/{id}` takes `phone`
  /// and writes it; there is no phone OTP route anywhere, and the gap
  /// responses did not add one — only email got a challenge flow. So this
  /// saves directly, and the screen does not pretend a code is coming.
  ///
  /// The password field the design draws has nothing to prove against here
  /// either; it is left out rather than collected and discarded.
  Future<void> _submit() async {
    final problem = AccountFormRules.phone(
      value: _next.text,
      current: _current.text,
    );
    setState(() => _error = problem);
    if (problem != null || _busy) return;

    setState(() => _busy = true);
    try {
      await _repo.updateAccount(phone: _next.text.trim());
      if (!mounted) return;
      showAccountSnack(context, AppStrings.settingsPhoneChanged);
      Navigator.pop(context, true);
    } catch (e) {
      logger.w('Phone change failed', error: e);
      if (!mounted) return;
      setState(() => _busy = false);
      showAccountSnack(context, AppStrings.settingsSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.settingsChangePhoneTitle,
      onAction: () => unawaited(_submit()),
      busy: _busy,
      children: [
        const SettingsFormNotice(text: AppStrings.settingsPhoneNotice),
        SettingsFormField(
          label: AppStrings.settingsCurrentPhone,
          controller: _current,
          hint: '',
          locked: true,
        ),
        SettingsFormField(
          label: AppStrings.settingsNewPhone,
          controller: _next,
          hint: '+234 000 000 0000',
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          error: _error,
        ),
      ],
    );
  }
}

/// Change password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  final _repo = AccountRepo();
  bool _busy = false;

  /// The calling session is spared, which the repo arranges by sending the
  /// refresh token. If the server says otherwise, the next call will 401 —
  /// so that is read rather than assumed.
  Future<void> _submit() async {
    final problem = AccountFormRules.newPassword(
      current: _current.text,
      next: _next.text,
      confirm: _confirm.text,
    );
    setState(() => _error = problem);
    if (problem != null || _busy) return;

    setState(() => _busy = true);
    try {
      final result = await _repo.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      showAccountSnack(
        context,
        !result.currentSessionRetained
            ? AppStrings.settingsSignInAgain
            : result.sessionsRevoked > 0
            ? AppStrings.settingsSessionsEnded(result.sessionsRevoked)
            : AppStrings.settingsPasswordChanged,
      );
      Navigator.pop(context, true);
    } on AccountException catch (e) {
      if (!mounted) return;
      // Never retry a 401 here: the route is deliberately slow and
      // uninformative, and five wrong answers lock the password proof for
      // the email change and the 2FA switch too.
      setState(() {
        _busy = false;
        _error = accountFailureMessage(e);
      });
    } catch (e) {
      logger.w('Password change failed', error: e);
      if (!mounted) return;
      setState(() => _busy = false);
      showAccountSnack(context, AppStrings.settingsSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.settingsChangePasswordTitle,
      onAction: () => unawaited(_submit()),
      busy: _busy,
      children: [
        SettingsFormField(
          label: AppStrings.settingsCurrentPassword,
          controller: _current,
          hint: '',
          obscure: true,
          textInputAction: TextInputAction.next,
        ),
        SettingsFormField(
          label: AppStrings.settingsNewPassword,
          controller: _next,
          hint: '',
          obscure: true,
          helper: AppStrings.settingsPasswordRule,
          textInputAction: TextInputAction.next,
          error: _error,
        ),
        SettingsFormField(
          label: AppStrings.settingsConfirmPassword,
          controller: _confirm,
          hint: '',
          obscure: true,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}
