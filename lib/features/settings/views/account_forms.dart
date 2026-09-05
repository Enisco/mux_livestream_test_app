import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/data/account_form_rules.dart';
import 'package:test_app/features/settings/data/settings_dummy_data.dart';
import 'package:test_app/features/settings/views/widgets/settings_form.dart';
import 'package:test_app/features/settings/views/widgets/settings_row.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The four screens the account menu's rows lead to.
///
/// Each validates what it can on the device and then stops: the routes exist —
/// `PATCH /v1/user/{id}` for name, email and phone, the avatar upload pair for
/// a photo — but their payloads are not published and they are auth-gated, so
/// none of them is wired. Every Update says so rather than pretending.

/// Reports that a form is as far as the app can currently take it.
void _notWired(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$what is not wired to the API yet',
          style: AppStyles.body(13)),
      backgroundColor: AppColors.neutral800,
      behavior: SnackBarBehavior.floating,
    ),
  );
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
  String? _error;

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

  void _submit() {
    final problem = AccountFormRules.name(
      first: _first.text,
      last: _last.text,
    );
    setState(() => _error = problem);
    if (problem == null) _notWired(context, 'Updating your name');
  }

  @override
  Widget build(BuildContext context) {
    final name = '${_first.text} ${_last.text}'.trim();

    return SettingsFormScaffold(
      title: AppStrings.settingsProfileInfo,
      onAction: _submit,
      children: [
        Center(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomRight,
                children: [
                  SettingsAvatar(
                    name: name.isEmpty
                        ? AppStrings.accountFallbackName
                        : name,
                    size: 80,
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
                onTap: () => _notWired(context, 'Changing your photo'),
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

  void _submit() {
    final problem = AccountFormRules.email(
      value: _next.text,
      current: _current.text,
    );
    setState(() => _error = problem);
    if (problem == null) _notWired(context, 'Changing your email address');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.settingsChangeEmailTitle,
      onAction: _submit,
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
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = AccountFormRules.phone(
      value: _next.text,
      current: _current.text,
    );
    setState(() => _error = problem);
    if (problem == null) _notWired(context, 'Changing your phone number');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.settingsChangePhoneTitle,
      onAction: _submit,
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

  void _submit() {
    final problem = AccountFormRules.newPassword(
      current: _current.text,
      next: _next.text,
      confirm: _confirm.text,
    );
    setState(() => _error = problem);
    if (problem == null) _notWired(context, 'Changing your password');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormScaffold(
      title: AppStrings.settingsChangePasswordTitle,
      onAction: _submit,
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
