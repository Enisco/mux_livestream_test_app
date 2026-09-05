import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/features/auth/views/widgets/auth_widgets.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/otp_code_field.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// "Check your mail": a code sent somewhere, the slots to type it into, and a
/// resend that unlocks on a countdown.
///
/// Sign-up and the settings email and phone changes all use this same screen,
/// so it owns the layout, the countdown and the submitting state, and asks the
/// caller only what it cannot know — where the code went and what to do with
/// it once it is typed.
class OtpVerificationView extends StatefulWidget {
  const OtpVerificationView({
    super.key,
    required this.destination,
    required this.onVerify,
    required this.onResend,
    this.title = AppStrings.checkYourMail,
    this.codeLength = 6,
    this.resendCooldown = 60,
    this.onBack,
  });

  /// Printed in bold mid-sentence — the address or number the code went to.
  final String destination;

  /// Returns null when the code was accepted, or the message to show.
  final Future<String?> Function(String code) onVerify;

  /// Returns null when a fresh code went out, or the message to show. The
  /// countdown restarts only on success.
  final Future<String?> Function() onResend;

  final String title;
  final int codeLength;
  final int resendCooldown;
  final VoidCallback? onBack;

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final _code = TextEditingController();

  Timer? _timer;
  late int _secondsLeft = widget.resendCooldown;
  bool _submitting = false;
  String? _error;

  /// The copy and the code slots.
  static const _contentInset = 46.0;

  /// The Verify button, which the design runs wider than the content.
  static const _footerInset = 24.0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != widget.codeLength || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final problem = await widget.onVerify(_code.text);
    if (mounted) {
      setState(() {
        _submitting = false;
        _error = problem;
      });
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() => _error = null);
    final problem = await widget.onResend();
    if (!mounted) return;
    if (problem == null) {
      _startCountdown();
    } else {
      setState(() => _error = problem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete = _code.text.length == widget.codeLength;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: OnboardingScaffold(
        backgroundAsset: AppAssets.onboardingBg,
        horizontalPadding: _footerInset,
        topBar: Align(
          alignment: Alignment.centerLeft,
          child: GTubeBackButton(onTap: widget.onBack),
        ),
        footer: PrimaryButton(
          label: AppStrings.verify,
          enabled: complete && !_submitting,
          loading: _submitting,
          labelStyle: AppStyles.button(16, lineHeight: 28 / 16),
          onPressed: _verify,
        ),
        // The copy and the code slots sit further in than the button does.
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _contentInset - _footerInset,
          ),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _MailBadge(),
        const SizedBox(height: 8),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppStyles.heading(20, lineHeight: 32 / 20, letterSpacing: -0.8),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: AppStyles.body(13),
            children: [
              const TextSpan(text: AppStrings.otpSentPrefix),
              TextSpan(
                text: widget.destination,
                style: AppStyles.label(
                  13,
                  color: AppColors.neutral200,
                  weight: AppStyles.black,
                ),
              ),
              const TextSpan(text: AppStrings.otpSentSuffix),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 35),
        OtpCodeField(
          controller: _code,
          length: widget.codeLength,
          onCompleted: (_) => _verify(),
        ),
        const SizedBox(height: 23),
        if (_error case final message?) ...[
          AuthErrorBanner(message: message),
          const SizedBox(height: 12),
        ],
        _ResendRow(secondsLeft: _secondsLeft, onResend: _resend),
      ],
    );
  }
}

class _MailBadge extends StatelessWidget {
  const _MailBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.base1,
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [AppColors.base1, AppColors.badgeInnerGlow],
          stops: [0.45, 1.0],
        ),
      ),
      child: Center(
        child: SvgPicture.asset(AppAssets.iconMailBadge, width: 29, height: 29),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsLeft, required this.onResend});

  final int secondsLeft;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final minutes = secondsLeft ~/ 60;
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    final ready = secondsLeft == 0;
    return SizedBox(
      width: 286,
      child: Text.rich(
        TextSpan(
          style: AppStyles.body(
            13,
            color: AppColors.textPrimary,
            weight: AppStyles.regular,
          ),
          children: [
            const TextSpan(text: AppStrings.didntGetIt),
            TextSpan(
              text: AppStrings.sendAgain,
              style:
                  AppStyles.label(
                    13,
                    color: AppColors.brandPrimary,
                    weight: AppStyles.bold,
                  ).copyWith(
                    color: ready
                        ? AppColors.brandPrimary
                        : AppColors.brandPrimary.withValues(alpha: 0.4),
                  ),
              recognizer: ready
                  ? (TapGestureRecognizer()..onTap = onResend)
                  : null,
            ),
            if (!ready) TextSpan(text: '· $minutes:$seconds'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
