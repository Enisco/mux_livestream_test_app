import 'package:flutter/material.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/settings/repo/account_repo.dart';
import 'package:test_app/models/auth_models/account_challenge.dart';
import 'package:test_app/shared/components/otp_verification_view.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// The code that completes a credential change.
///
/// One screen behind two flows, because the backend answers the same
/// [AccountChallenge] for both: changing an email address, and turning 2FA on.
/// The view is [OtpVerificationView], the same one sign-up uses.
///
/// Two things it gets from the challenge rather than inventing:
///
/// - **Which address the code went to**, masked. For an email change that is
///   the *new* address, because receiving the code there is the proof; the
///   screen must not say "we emailed you" without naming which mailbox.
/// - **How long until a resend is allowed.** `resendAvailableAt` is the
///   server's own cooldown; a client-side interval would disagree with it and
///   produce a button that looks live and answers 409.
///
/// Popping with `true` means the change went through.
class ConfirmChangeScreen extends StatefulWidget {
  const ConfirmChangeScreen({
    super.key,
    required this.challenge,
    required this.title,
    required this.onVerify,
    required this.onResend,
  });

  /// Confirming a new email address.
  factory ConfirmChangeScreen.email({
    Key? key,
    required AccountChallenge challenge,
    AccountRepo? repo,
  }) {
    final account = repo ?? AccountRepo();
    return ConfirmChangeScreen(
      key: key,
      challenge: challenge,
      title: AppStrings.settingsConfirmEmailTitle,
      onVerify: (id, code) =>
          account.verifyEmailChange(challengeId: id, code: code),
      onResend: account.resendEmailChange,
    );
  }

  /// Confirming that 2FA codes reach the address on the account.
  factory ConfirmChangeScreen.twoFactor({
    Key? key,
    required AccountChallenge challenge,
    AccountRepo? repo,
  }) {
    final account = repo ?? AccountRepo();
    return ConfirmChangeScreen(
      key: key,
      challenge: challenge,
      title: AppStrings.settingsConfirmEmailTitle,
      onVerify: (id, code) =>
          account.verifyTwoFactor(challengeId: id, code: code),
      onResend: account.resendTwoFactor,
    );
  }

  final AccountChallenge challenge;
  final String title;

  final Future<Map<String, dynamic>> Function(String challengeId, String code)
  onVerify;
  final Future<AccountChallenge> Function(String challengeId) onResend;

  @override
  State<ConfirmChangeScreen> createState() => _ConfirmChangeScreenState();
}

class _ConfirmChangeScreenState extends State<ConfirmChangeScreen> {
  late AccountChallenge _challenge = widget.challenge;

  /// Returns null when the code was accepted, or the message to show.
  Future<String?> _verify(String code) async {
    try {
      await widget.onVerify(_challenge.challengeId, code);
      if (mounted) Navigator.pop(context, true);
      return null;
    } on AccountException catch (e) {
      return _say(e);
    } catch (e) {
      logger.w('Verify failed', error: e);
      return AppStrings.settingsSaveFailed;
    }
  }

  /// A resend **rotates** the code: anything already in the reader's hand
  /// stops working, so the challenge is replaced rather than kept.
  Future<String?> _resend() async {
    try {
      final next = await widget.onResend(_challenge.challengeId);
      if (!mounted) return null;
      setState(() => _challenge = next);
      return null;
    } on AccountException catch (e) {
      return _say(e);
    } catch (e) {
      logger.w('Resend failed', error: e);
      return AppStrings.settingsSaveFailed;
    }
  }

  /// The backend asks that its own wording for a wrong code be used as-is.
  String _say(AccountException e) => switch (e.failure) {
    AccountFailure.network => AppStrings.settingsOffline,
    AccountFailure.expired => AppStrings.settingsExpiredRestart,
    AccountFailure.cooldown || AccountFailure.locked =>
      e.retryAt == null
          ? AppStrings.settingsTryLater
          : AppStrings.settingsLockedUntil(_clock(e.retryAt!)),
    _ => e.message ?? AppStrings.settingsSaveFailed,
  };

  static String _clock(DateTime at) {
    final local = at.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute${local.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    return OtpVerificationView(
      // Keyed on the challenge so a resend restarts the countdown: the view
      // holds the cooldown in its own state.
      key: ValueKey(
        'otp-${_challenge.challengeId}-${_challenge.resendAvailableAt}',
      ),
      title: widget.title,
      destination: _challenge.maskedDestination,
      resendCooldown: _challenge.resendCooldownSeconds,
      onBack: () => Navigator.of(context).maybePop(),
      onVerify: _verify,
      onResend: _resend,
    );
  }
}
