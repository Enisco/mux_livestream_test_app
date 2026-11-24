import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/auth/views/widgets/auth_flow.dart';
import 'package:test_app/features/auth/views/widgets/auth_widgets.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/gtube_text_field.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/social_sign_in.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/keyboard.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // After validating, as `forgot_password_screen` and
    // `reset_password_screen` both do: a failed validation puts its message
    // under the field being corrected, and dropping the keyboard first
    // would make the reader tap back into it to fix anything.
    dismissKeyboard();
    context.read<AuthBloc>().add(
      AuthSignInRequested(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      // A failure is already drawn as a banner above the form, so this only
      // navigates: to the feed, to onboarding for an account a provider
      // just created, or to the code screen when the account carries a
      // second factor.
      child: AuthFlowListener(
        child: OnboardingScaffold(
          gradient: AppStyles.splashBackground,
          backgroundAsset: AppAssets.onboardingBg,
          horizontalPadding: 24,
          centerContent: true,
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const SizedBox(height: 26),
        const _SocialRow(),
        const SizedBox(height: 26),
        _form(),
      ],
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (_, s) =>
                s is AuthFailure || s is AuthLoading || s is AuthInitial,
            builder: (_, state) => state is AuthFailure
                ? AuthErrorBanner(message: state.message)
                : const SizedBox.shrink(),
          ),
          GTubeTextField(
            controller: _emailCtrl,
            hint: AppStrings.fieldEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            inputFormatters: const [LowerCaseInputFormatter()],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 10),
          GTubeTextField(
            controller: _passwordCtrl,
            hint: AppStrings.fieldPassword,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            trailing: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Padding(
                padding: const EdgeInsets.only(
                  right: GTubeTextField.horizontalPadding,
                ),
                child: Text(
                  _obscurePassword ? AppStrings.show : AppStrings.hide,
                  style: AppStyles.label(
                    13,
                    color: AppColors.brandPrimary,
                    weight: AppStyles.bold,
                  ),
                ),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
          ),
          const SizedBox(height: 20),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => PrimaryButton(
              label: AppStrings.logIn,
              loading: state is AuthLoading,
              // A provider sheet is open behind this screen while
              // AuthSocialLoading is the state, and a password login
              // started on top of it would race it to the same bloc.
              enabled: state is! AuthSocialLoading,
              onPressed: _submit,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(AppRouter.forgotPassword),
              child: Text(
                AppStrings.forgotPasswordLink,
                style: AppStyles.body(
                  14,
                  color: AppColors.neutral300,
                  lineHeight: 16 / 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          // The link in the header is easy to miss above the fold on a
          // short phone, and someone who has no account has nothing to type
          // into this form — so the way out of it is a control of its own.
          AuthSecondaryButton(
            key: const ValueKey('sign-in-sign-up'),
            label: AppStrings.newHereSignUp,
            onPressed: () => context.go(AppRouter.signUp),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GTubeLogoMark.plain(),
        const SizedBox(height: 7),
        Text(
          AppStrings.loginTitle,
          style: AppStyles.heading(
            20,
            lineHeight: 32 / 20,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.noAccount,
              style: AppStyles.body(16, lineHeight: 16 / 16),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              key: const ValueKey('sign-in-sign-up-link'),
              onTap: () => context.go(AppRouter.signUp),
              child: Text(
                AppStrings.signUpLink,
                style: AppStyles.label(
                  16,
                  color: AppColors.brandPrimary,
                  weight: AppStyles.bold,
                  lineHeight: 16 / 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AuthBloc>();
    // Apple first, then Google: the design draws the two icons in that
    // order here, and the opposite one on the welcome page's full-width
    // buttons. Iterating `SocialProvider.values` would quietly reorder this
    // row.
    const order = [SocialProvider.apple, SocialProvider.google];
    final offered = order.where(bloc.offers).toList();

    // No providers on this build means no divider either: an "Or" over an
    // empty row says there was another way in and it is missing.
    if (offered.isEmpty) return const SizedBox.shrink();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final busy = state is AuthSocialLoading ? state.provider : null;
        final working = state is AuthSocialLoading || state is AuthLoading;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final provider in offered) ...[
                  if (provider != offered.first) const SizedBox(width: 11),
                  _SocialIconButton(
                    key: ValueKey('sign-in-with-${provider.slug}'),
                    icon: switch (provider) {
                      SocialProvider.google => AppAssets.iconGoogle,
                      SocialProvider.apple => AppAssets.iconApple,
                    },
                    busy: busy == provider,
                    onPressed: working
                        ? null
                        : () => bloc.add(AuthSocialSignInRequested(provider)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 237,
              child: Row(
                children: [
                  const Expanded(child: _DividerLine()),
                  const SizedBox(width: 10),
                  Text(
                    AppStrings.orDivider,
                    style: AppStyles.caption(
                      12,
                      weight: AppStyles.medium,
                      lineHeight: 16 / 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: _DividerLine()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: AppColors.neutral700));
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String icon;
  final VoidCallback? onPressed;
  final bool busy;

  static const _size = 16.667;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.buttonSecondaryActive,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: _size,
            height: _size,
            child: busy
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.neutral300,
                  )
                : SvgPicture.asset(icon, width: _size, height: _size),
          ),
        ),
      ),
    );
  }
}
