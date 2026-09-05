import 'package:flutter/material.dart';

import 'package:test_app/shared/components/otp_verification_view.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// Confirms a change of email address or phone number with a posted code.
///
/// The screen is [OtpVerificationView], the same one sign-up uses. What is
/// missing is the pair of calls behind it: no route publishes a schema for
/// requesting or confirming an account-contact change, so neither the code
/// that supposedly went out nor the one typed here reaches a server. Both
/// callbacks say so rather than reporting a success that did not happen.
class ConfirmChangeScreen extends StatelessWidget {
  const ConfirmChangeScreen.email({super.key, required this.destination})
    : title = AppStrings.settingsConfirmEmailTitle;

  const ConfirmChangeScreen.phone({super.key, required this.destination})
    : title = AppStrings.settingsConfirmPhoneTitle;

  /// The address or number the code was sent to.
  final String destination;

  final String title;

  @override
  Widget build(BuildContext context) {
    return OtpVerificationView(
      title: title,
      destination: destination,
      onBack: () => Navigator.of(context).maybePop(),
      onVerify: (_) async => AppStrings.settingsOtpNotWired,
      onResend: () async => AppStrings.settingsOtpResendNotWired,
    );
  }
}
