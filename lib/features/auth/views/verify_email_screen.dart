import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/shared/components/otp_verification_view.dart';

/// Confirms the address someone signed up with.
///
/// The screen itself is [OtpVerificationView], shared with the settings email
/// and phone changes; this supplies only the two calls that are particular to
/// signing up.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.challengeId,
  });

  final String email;

  final String challengeId;

  @override
  Widget build(BuildContext context) {
    final repo = getIt<AuthRepo>();

    return OtpVerificationView(
      destination: email,
      onBack: () => context.pop(),
      onVerify: (code) async {
        try {
          await repo.verifyChallenge(challengeId: challengeId, code: code);
          if (context.mounted) context.go(AppRouter.welcomeNote);
          return null;
        } on DioException catch (e) {
          return _messageFrom(e);
        } catch (_) {
          return 'Something went wrong. Please try again.';
        }
      },
      onResend: () async {
        try {
          await repo.resendChallengeOtp(challengeId: challengeId);
          return null;
        } on DioException catch (e) {
          return _messageFrom(e);
        }
      },
    );
  }

  static String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
    return 'That code did not work. Please try again.';
  }
}
