import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/auth/views/widgets/auth_widgets.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/gtube_text_field.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _repo = getIt<AuthRepo>();

  bool _submitting = false;
  String? _error;
  bool _sent = false;

  static const _formInset = 26.0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.requestPasswordReset(
        email: _emailCtrl.text.trim().toLowerCase(),
      );
      if (mounted) setState(() => _sent = true);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Could not send the reset link. Please try again.';
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      gradient: AppStyles.splashBackground,
      backgroundAsset: AppAssets.onboardingBg,
      centerContent: true,
      child: _content(),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            GTubeLogoMark.plain(),
            SizedBox(height: 7),
            Text(
              AppStrings.forgotPasswordTitle,
              style: AppStyles.heading(
                20,
                lineHeight: 32 / 20,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: 3),
            Text(
              AppStrings.forgotPasswordSubtitle,
              textAlign: TextAlign.center,
              style: AppStyles.body(16, lineHeight: 16 / 16),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _formInset),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  AuthErrorBanner(message: _error!),
                  const SizedBox(height: 10),
                ],
                if (_sent) ...[
                  Text(
                    AppStrings.resetLinkSent,
                    textAlign: TextAlign.center,
                    style: AppStyles.caption(
                      10,
                      color: AppColors.green500,
                      weight: AppStyles.medium,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                GTubeTextField(
                  controller: _emailCtrl,
                  hint: AppStrings.emailHint,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  inputFormatters: const [LowerCaseInputFormatter()],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: AppStrings.resetPassword,
                  loading: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
