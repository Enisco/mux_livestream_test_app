import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/models/auth_models/auth_models.dart';
import 'package:test_app/shared/components/otp_verification_view.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// The emailed second factor.
///
/// The platform's second factor is **an emailed code and nothing else** —
/// no authenticator app, no secret, no recovery codes — so there is one
/// screen for it however the sign-in started: a password, Google or Apple.
///
/// It verifies with `clientType: "native"`, which the repo sends. Omitting
/// it there is the trap the guide calls out: the gateway sets cookies the
/// app cannot use, answers no tokens, and the person ends up back where
/// they started with no error to read.
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.challengeId,
    this.isNewUser = false,
  });

  /// Where the code was sent. May be an Apple private relay address, which
  /// is why it is shown rather than assumed to be something the person
  /// typed.
  final String email;

  final String challengeId;

  /// Whether the sign-in behind this challenge created the account. Decides
  /// where finishing it lands.
  final bool isNewUser;

  @override
  Widget build(BuildContext context) {
    final repo = getIt<AuthRepo>();

    return OtpVerificationView(
      destination: email,
      onBack: () => context.pop(),
      onVerify: (code) async {
        try {
          final outcome = await repo.verifyChallenge(
            challengeId: challengeId,
            code: code,
          );
          if (outcome is! AuthSignedIn) {
            // The verify route answers a `LOGGED_IN` payload or it fails;
            // a second challenge is not a shape it has.
            return AppStrings.authContractBroken;
          }
          if (!context.mounted) return null;

          // The session is stored by the time this returns, so this is a
          // `go`: there is nothing left behind worth going back to.
          if (isNewUser) {
            final name = Uri.encodeComponent(outcome.session.user.firstName);
            context.go('${AppRouter.welcomeNote}?name=$name');
          } else {
            context.go(AppRouter.home);
          }
          return null;
        } on AuthContractException catch (e) {
          logger.e('2FA verify answered a shape with no session', error: e);
          return AppStrings.authContractBroken;
        } on DioException catch (e) {
          return _messageFrom(e);
        } catch (e) {
          logger.e('Unexpected 2FA verify error', error: e);
          return AppStrings.somethingWentWrong;
        }
      },
      onResend: () async {
        try {
          // Resending rotates the code, so whatever is in the field is
          // already dead. `OtpVerificationView` clears it.
          await repo.resendChallengeOtp(challengeId: challengeId);
          return null;
        } on DioException catch (e) {
          return _messageFrom(e);
        } catch (e) {
          // Anything that escapes here leaves the view with no new code and
          // nothing to read: it neither clears the field nor restarts the
          // countdown, so Resend becomes a button that does nothing.
          logger.e('Unexpected 2FA resend error', error: e);
          return AppStrings.somethingWentWrong;
        }
      },
    );
  }

  static String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      // The gateway words these itself, and its sentences are better than
      // anything guessable here: "That code has expired", and so on.
      final error = data['error'] ?? data['message'];
      if (error is String && error.isNotEmpty) return error;
      if (error is List && error.isNotEmpty) return error.first.toString();
    }
    return AppStrings.otpCodeRejected;
  }
}
