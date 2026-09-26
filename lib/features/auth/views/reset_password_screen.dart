import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
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

/// The second half of a password reset.
///
/// "Check your inbox" was where the flow used to end: the email carries a
/// token and `POST /v1/auth/password/reset` takes `{token, newPassword}`, but
/// nothing in the app could spend it.
///
/// The Figma section has no frame for this screen — it only draws "send me a
/// link" (`10618-83676`) — so the layout deliberately mirrors
/// [ForgotPasswordScreen] rather than inventing a look of its own.
///
/// The token arrives one of two ways: a deep link fills [token] in, and
/// anyone whose link opened in a browser instead can paste the code. Universal
/// links are not verified on either host yet, so the paste path is the one
/// that actually works today, not a fallback.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.token});

  /// Prefilled when a deep link brought the reader here.
  final String? token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tokenCtrl;
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _repo = getIt<AuthRepo>();

  bool _submitting = false;
  bool _obscure = true;
  bool _done = false;
  String? _error;

  static const _formInset = 26.0;

  /// The server's own bounds, so the form refuses what the API would.
  static const minPasswordLength = 8;
  static const maxPasswordLength = 128;

  /// A token that came by deep link is shown read-only: it is not something
  /// anyone should be editing, but hiding it entirely makes a failure
  /// impossible to explain.
  bool get _tokenFromLink => (widget.token ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: widget.token?.trim() ?? '');
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return AppStrings.passwordRequired;
    if (v.length < minPasswordLength) return AppStrings.passwordTooShort;
    if (v.length > maxPasswordLength) return AppStrings.passwordTooLong;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.completePasswordReset(
        token: _tokenCtrl.text.trim(),
        newPassword: _passwordCtrl.text,
      );
      if (mounted) setState(() => _done = true);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The API answers validation failures as a list of strings and a bad token
  /// as `["Invalid or expired reset token."]`. Either way the reader needs one
  /// sentence, and a token problem needs the one that says what to do next.
  String _messageFor(DioException e) {
    final data = e.response?.data;
    final raw = data is Map ? (data['error'] ?? data['message']) : null;
    final message = switch (raw) {
      final String s when s.trim().isNotEmpty => s,
      final List<dynamic> l when l.isNotEmpty => l.first.toString(),
      _ => null,
    };
    if (message == null) return AppStrings.resetTokenRejected;
    return message.toLowerCase().contains('token')
        ? AppStrings.resetTokenRejected
        : message;
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
            const SizedBox(height: 7),
            Text(
              AppStrings.setNewPasswordTitle,
              style: AppStyles.heading(
                20,
                lineHeight: 32 / 20,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _done
                  ? AppStrings.passwordResetDone
                  : AppStrings.setNewPasswordSubtitle,
              textAlign: TextAlign.center,
              style: AppStyles.body(14, lineHeight: 20 / 14),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _formInset),
          child: _done ? _doneActions() : _form(),
        ),
      ],
    );
  }

  Widget _doneActions() => PrimaryButton(
    label: AppStrings.backToSignIn,
    onPressed: () => context.go(AppRouter.signIn),
  );

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: 10),
          ],
          GTubeTextField(
            key: const ValueKey('reset-token'),
            controller: _tokenCtrl,
            hint: AppStrings.resetCodeHint,
            readOnly: _tokenFromLink,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.resetCodeRequired
                : null,
          ),
          const SizedBox(height: 14),
          GTubeTextField(
            key: const ValueKey('reset-password'),
            controller: _passwordCtrl,
            hint: AppStrings.newPasswordHint,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            trailing: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _obscure = !_obscure),
              child: Padding(
                padding: const EdgeInsets.only(
                  right: GTubeTextField.horizontalPadding,
                ),
                child: Text(
                  _obscure ? AppStrings.show : AppStrings.hide,
                  style: AppStyles.label(
                    13,
                    color: AppColors.brandPrimary,
                    weight: AppStyles.bold,
                  ),
                ),
              ),
            ),
            validator: _validatePassword,
          ),
          const SizedBox(height: 14),
          GTubeTextField(
            key: const ValueKey('reset-confirm'),
            controller: _confirmCtrl,
            hint: AppStrings.confirmPasswordHint,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            validator: (v) =>
                v == _passwordCtrl.text ? null : AppStrings.passwordsDoNotMatch,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: AppStrings.saveNewPassword,
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
