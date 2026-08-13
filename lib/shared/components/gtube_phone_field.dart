import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/shared/components/country_flag_icon.dart';
import 'package:test_app/shared/components/country_picker_sheet.dart';
import 'package:test_app/shared/components/gtube_text_field.dart';
import 'package:test_app/shared/data/countries.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/phone_number.dart';

/// Dial-code selector joined to a number field inside one bordered shell, so it
/// reads as a single control alongside the other [GTubeTextField]s.
///
/// [controller] holds only what the user typed. Use [PhoneNumber.e164] with the
/// selected country to build the value for the API.
class GTubePhoneField extends StatefulWidget {
  const GTubePhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    required this.hint,
    this.textInputAction,
  });

  final TextEditingController controller;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final String hint;
  final TextInputAction? textInputAction;

  @override
  State<GTubePhoneField> createState() => _GTubePhoneFieldState();
}

class _GTubePhoneFieldState extends State<GTubePhoneField> {
  final _focusNode = FocusNode();
  FormFieldState<String>? _formState;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFormValue);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus != _focused) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void didUpdateWidget(GTubePhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different dial code can make a shown error stale in either direction.
    // Revalidating has to wait for the frame to finish — the enclosing Form
    // rebuilds on it, and it is mid-build right now.
    // Only when something has been typed: pushing a value into an untouched
    // field would trip onUserInteraction and scold someone who has just picked
    // a country before entering their number.
    if (oldWidget.country != widget.country &&
        widget.controller.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFormValue();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFormValue);
    _focusNode.dispose();
    super.dispose();
  }

  /// The number lives in [widget.controller], so the enclosing [Form] only sees
  /// edits once they are pushed into the wrapping [FormField].
  void _syncFormValue() => _formState?.didChange(widget.controller.text);

  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await CountryPickerSheet.show(
      context,
      selected: widget.country,
    );
    if (picked != null) widget.onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => PhoneNumber.validate(value, widget.country),
      builder: (state) {
        _formState = state;
        final error = state.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GTubeTextField.radius),
                boxShadow: _focused ? AppStyles.fieldFocusShadow : null,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.brandAltDark,
                  borderRadius: BorderRadius.circular(GTubeTextField.radius),
                  border: Border.all(color: _borderColor(error)),
                ),
                child: Row(
                  children: [
                    _dialCodeButton(),
                    Container(
                      width: 1,
                      height: 24,
                      color: AppColors.neutral700,
                    ),
                    Expanded(child: _numberField()),
                  ],
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  error,
                  style: AppStyles.caption(
                    12,
                    color: AppColors.error,
                    weight: AppStyles.medium,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _borderColor(String? error) {
    if (error != null) return AppColors.error;
    return _focused ? AppColors.brandPrimary : AppColors.neutral700;
  }

  Widget _dialCodeButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickCountry,
      child: Padding(
        padding: const EdgeInsets.only(
          left: GTubeTextField.horizontalPadding,
          right: 12,
          top: GTubeTextField.verticalPadding,
          bottom: GTubeTextField.verticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CountryFlagIcon(isoCode: widget.country.isoCode, height: 14),
            const SizedBox(width: 8),
            Text(
              widget.country.display,
              style: AppStyles.body(16, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 6),
            SvgPicture.asset(
              AppAssets.iconChevronDown,
              width: 7.072,
              height: 4.713,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
        LengthLimitingTextInputFormatter(20),
      ],
      cursorColor: AppColors.textPrimary,
      cursorWidth: 2,
      cursorHeight: 26,
      style: AppStyles.body(16, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppStyles.body(16, color: AppColors.neutral400),
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: GTubeTextField.verticalPadding,
        ),
      ),
    );
  }
}
