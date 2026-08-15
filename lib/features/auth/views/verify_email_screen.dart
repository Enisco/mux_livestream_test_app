import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/auth/views/widgets/auth_widgets.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/otp_code_field.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.challengeId,
  });

  final String email;

  final String challengeId;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeCtrl = TextEditingController();
  final _repo = getIt<AuthRepo>();

  Timer? _timer;
  int _secondsLeft = _resendCooldown;
  bool _submitting = false;
  String? _error;

  static const _codeLength = 6;
  static const _resendCooldown = 60;

  static const _contentInset = 46.0;
  static const _sideInset = 20.0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.length != _codeLength || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.verifyChallenge(
        challengeId: widget.challengeId,
        code: _codeCtrl.text,
      );
      if (!mounted) return;
      context.go(AppRouter.welcomeNote);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = _messageFrom(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() => _error = null);
    try {
      await _repo.resendChallengeOtp(challengeId: widget.challengeId);
      if (mounted) _startCountdown();
    } on DioException catch (e) {
      if (mounted) setState(() => _error = _messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return 'That code did not work. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final complete = _codeCtrl.text.length == _codeLength;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: OnboardingScaffold(
        backgroundAsset: AppAssets.onboardingBg,
        horizontalPadding: _contentInset,
        topBar: Align(
          alignment: Alignment.centerLeft,
          child: _BackButton(onTap: () => context.pop()),
        ),
        footer: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _sideInset + 4 - _contentInset,
          ),
          child: PrimaryButton(
            label: AppStrings.verify,
            enabled: complete && !_submitting,
            loading: _submitting,
            labelStyle: AppStyles.button(16, lineHeight: 28 / 16),
            onPressed: _verify,
          ),
        ),
        child: _content(complete),
      ),
    );
  }

  Widget _content(bool complete) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _MailBadge(),
        const SizedBox(height: 8),
        Text(
          AppStrings.checkYourMail,
          textAlign: TextAlign.center,
          style: AppStyles.heading(
            20,
            lineHeight: 32 / 20,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: AppStyles.body(13),
            children: [
              const TextSpan(text: AppStrings.otpSentPrefix),
              TextSpan(
                text: widget.email,
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
          controller: _codeCtrl,
          length: _codeLength,
          onCompleted: (_) => _verify(),
        ),
        const SizedBox(height: 23),
        if (_error != null) ...[
          AuthErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        _ResendRow(secondsLeft: _secondsLeft, onResend: _resend),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GTubeBackButton(onTap: onTap);
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
