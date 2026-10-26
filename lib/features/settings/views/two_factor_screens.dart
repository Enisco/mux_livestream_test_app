import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/features/settings/views/account_forms.dart'
    show accountFailureMessage, showAccountSnack;
import 'package:test_app/features/settings/views/confirm_change_screen.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Two-factor authentication: one switch, and a code we email.
///
/// **This replaced four screens** (`11599-107177`, `-107746`, `-107859`,
/// `-108005`) that described TOTP — a QR code, a secret to type into an
/// authenticator app, recovery codes. None of that exists. The backend ruled
/// on 2026-10-19 that the second factor is an emailed code, per account, and
/// asked for the screens to be redrawn before anything was built against it
/// (`docs/mobile-api-gap-responses.md` §3.5). The QR tile, the secret chip and
/// the `qr_flutter` dependency went with them.
///
/// The asymmetry is deliberate and worth preserving if this is ever redrawn
/// again:
///
/// - **Turning it on takes no password.** The emailed code is the proof, and
///   it doubles as a check that codes actually arrive — so nobody can switch
///   2FA on against a mailbox they cannot read and strand themselves.
/// - **Turning it off takes the current password.** It is the one direction an
///   attacker on a stolen session wants, and an emailed code would be the same
///   factor being removed.
class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key, this.repo});

  /// Defaults to the real thing; a test supplies its own.
  final AccountRepo? repo;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  late final _repo = widget.repo ?? AccountRepo();

  /// The account's own setting, straight off the cached `User`.
  ///
  /// An account that has never touched the switch still reports `true`: the
  /// second factor used to be platform-wide, so existing accounts default to
  /// on rather than silently getting weaker on deploy.
  late bool _on = LocalStorage.cachedTwoFactorEnabled;
  bool _busy = false;

  Future<void> _toggle(bool wanted) async {
    if (_busy) return;
    if (wanted) {
      await _enable();
    } else {
      await _confirmDisable();
    }
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      final challenge = await _repo.enableTwoFactor();
      if (!mounted) return;
      setState(() => _busy = false);
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ConfirmChangeScreen.twoFactor(challenge: challenge, repo: _repo),
        ),
      );
      if (!mounted) return;
      if (done ?? false) {
        setState(() => _on = true);
        showAccountSnack(context, AppStrings.twoFactorNowOn);
      }
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // Already on: nothing to do but correct the switch.
      if (e.failure == AccountFailure.conflict) {
        setState(() => _on = true);
        return;
      }
      showAccountSnack(context, accountFailureMessage(e));
    } catch (e) {
      logger.w('2FA enable failed', error: e);
      if (!mounted) return;
      setState(() => _busy = false);
      showAccountSnack(context, AppStrings.settingsSaveFailed);
    }
  }

  Future<void> _confirmDisable() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordPrompt(),
    );
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repo.disableTwoFactor(password);
      if (!mounted) return;
      setState(() {
        _on = false;
        _busy = false;
      });
      showAccountSnack(context, AppStrings.twoFactorNowOff);
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // Never retry a 401 here — it shares a lockout with the email and
      // password changes, and five wrong answers lock all three.
      showAccountSnack(context, accountFailureMessage(e));
    } catch (e) {
      logger.w('2FA disable failed', error: e);
      if (!mounted) return;
      setState(() => _busy = false);
      showAccountSnack(context, AppStrings.settingsSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 24.s),
              child: Row(
                children: [
                  const GTubeBackButton(size: 24, box: 24),
                  SizedBox(width: 12.s),
                  Flexible(
                    child: Text(
                      AppStrings.twoFactorTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.label(
                        18,
                        weight: AppStyles.bold,
                        lineHeight: 28 / 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.s),
                children: [
                  SizedBox(height: 8.s),
                  const Center(child: _ShieldBadge()),
                  SizedBox(height: 18.s),
                  Text(
                    AppStrings.twoFactorHeading,
                    textAlign: TextAlign.center,
                    style: AppStyles.heading(18, lineHeight: 26 / 18),
                  ),
                  SizedBox(height: 8.s),
                  Text(
                    AppStrings.twoFactorBody,
                    textAlign: TextAlign.center,
                    style: AppStyles.body(
                      13,
                      color: AppColors.neutral400,
                      lineHeight: 19 / 13,
                    ),
                  ),
                  SizedBox(height: 24.s),
                  _Card(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _on
                                    ? AppStrings.twoFactorOn
                                    : AppStrings.twoFactorOff,
                                style: AppStyles.label(
                                  14,
                                  weight: AppStyles.bold,
                                ),
                              ),
                              SizedBox(height: 4.s),
                              Text(
                                _on
                                    ? AppStrings.twoFactorOnSub
                                    : AppStrings.twoFactorOffSub,
                                style: AppStyles.label(
                                  12,
                                  color: AppColors.neutral500,
                                  lineHeight: 16 / 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_busy)
                          SizedBox(
                            width: 20.s,
                            height: 20.s,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.brandPrimary,
                            ),
                          )
                        else
                          Switch(
                            key: const ValueKey('two-factor-switch'),
                            value: _on,
                            activeThumbColor: AppColors.textPrimary,
                            activeTrackColor: AppColors.brandPrimary,
                            inactiveThumbColor: AppColors.neutral400,
                            inactiveTrackColor: AppColors.neutral800,
                            onChanged: (v) => unawaited(_toggle(v)),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.s),
                  Text(
                    AppStrings.twoFactorLostMailbox,
                    style: AppStyles.label(
                      12,
                      color: AppColors.neutral500,
                      lineHeight: 17 / 12,
                    ),
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

/// Proving the current password before the protection comes off.
class _PasswordPrompt extends StatefulWidget {
  const _PasswordPrompt();

  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.fieldBg,
      title: Text(
        AppStrings.twoFactorTurnOffTitle,
        style: AppStyles.heading(16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.twoFactorTurnOffBody,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
          SizedBox(height: 16.s),
          TextField(
            key: const ValueKey('two-factor-password'),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            style: AppStyles.body(14),
            decoration: InputDecoration(
              hintText: AppStrings.settingsCurrentPassword,
              hintStyle: AppStyles.body(14, color: AppColors.neutral500),
              filled: true,
              fillColor: AppColors.base2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.s),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppStrings.notNow,
            style: AppStyles.button(13, color: AppColors.neutral400),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(
            AppStrings.twoFactorTurnOff,
            style: AppStyles.button(13, color: AppColors.brandPrimary),
          ),
        ),
      ],
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64.s,
      height: 64.s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandPrimary.withValues(alpha: 0.15),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedShieldUser,
          color: AppColors.brandPrimary,
          size: 28.s,
        ),
      ),
    );
  }
}

/// The rounded plate the two-factor screen groups things on.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12.s),
      ),
      child: child,
    );
  }
}
