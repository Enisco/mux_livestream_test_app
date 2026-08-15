import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/auth/views/widgets/auth_widgets.dart';
import 'package:test_app/features/auth/views/widgets/gender_picker_sheet.dart';
import 'package:test_app/shared/components/gtube_phone_field.dart';
import 'package:test_app/shared/components/gtube_text_field.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/data/countries.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/phone_number.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  Gender? _gender;
  Country _country = Countries.fallback;

  static const _sideInset = 20.0;
  static const _contentInset = 4.0;
  static const _fieldGap = 16.0;

  static const _headerGap = 40.0;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthSignUpRequested(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
        phone: PhoneNumber.e164(_phoneCtrl.text, _country.dialCode),
        gender: _gender?.value,
        countryCode: _country.isoCode,
      ),
    );
  }

  Future<void> _pickGender() async {
    FocusScope.of(context).unfocus();
    final picked = await GenderPickerSheet.show(context);
    if (picked != null) setState(() => _gender = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            final name = Uri.encodeComponent(_firstNameCtrl.text.trim());
            context.go('${AppRouter.welcomeNote}?name=$name');
          }
        },
        child: OnboardingScaffold(
          gradient: AppStyles.splashBackground,
          backgroundAsset: AppAssets.onboardingBg,
          horizontalPadding: _sideInset + _contentInset,
          topBar: _Header(),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _headerGap),
        _form(),
        const SizedBox(height: 32),
        _footer(),
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
            controller: _firstNameCtrl,
            hint: AppStrings.fieldFirstName,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            inputFormatters: const [WordCapitalizationInputFormatter()],
            autofillHints: const [AutofillHints.givenName],
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: _fieldGap),
          GTubeTextField(
            controller: _lastNameCtrl,
            hint: AppStrings.fieldLastName,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            inputFormatters: const [WordCapitalizationInputFormatter()],
            autofillHints: const [AutofillHints.familyName],
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: _fieldGap),
          GTubePhoneField(
            controller: _phoneCtrl,
            hint: AppStrings.fieldPhone,
            country: _country,
            onCountryChanged: (country) => setState(() => _country = country),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: _fieldGap),
          GTubeSelectField(
            hint: AppStrings.fieldGenderOptional,
            value: _gender?.label,
            onTap: _pickGender,
            trailing: const Icon(
              AppIcons.chevronDown,
              size: 12,
              color: AppColors.neutral400,
            ),
          ),
          const SizedBox(height: _fieldGap),
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
          const SizedBox(height: _fieldGap),
          GTubeTextField(
            controller: _passwordCtrl,
            hint: AppStrings.fieldPassword,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
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
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'Minimum 8 characters';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => PrimaryButton(
            label: AppStrings.createAccountTitle,
            loading: state is AuthLoading,
            onPressed: _submit,
          ),
        ),
        const SizedBox(height: 13),
        const _LegalFootnote(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GTubeBackButton(onTap: () => context.pop()),
            const SizedBox(width: 10),
            Text(
              AppStrings.createAccountTitle,
              style: AppStyles.heading(
                20,
                lineHeight: 32 / 20,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.createAccountSubtitle,
          style: AppStyles.body(16, color: AppColors.neutral400),
        ),
      ],
    );
  }
}

class _LegalFootnote extends StatelessWidget {
  const _LegalFootnote();

  @override
  Widget build(BuildContext context) {
    const underlined = TextStyle(decoration: TextDecoration.underline);
    return SizedBox(
      width: 286,
      child: Text.rich(
        TextSpan(
          style: AppStyles.body(
            13,
            color: AppColors.neutral400,
            lineHeight: 16 / 13,
          ),
          children: const [
            TextSpan(text: AppStrings.termsPrefix),
            TextSpan(text: AppStrings.terms, style: underlined),
            TextSpan(text: AppStrings.termsAmpersand),
            TextSpan(text: AppStrings.privacyPolicy, style: underlined),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
