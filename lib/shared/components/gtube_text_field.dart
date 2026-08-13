import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';
import 'package:flutter/services.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class GTubeTextField extends StatefulWidget {
  const GTubeTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.trailing,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final Widget? trailing;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  static const radius = 8.0;
  static const horizontalPadding = 16.0;
  static const verticalPadding = 14.0;

  @override
  State<GTubeTextField> createState() => _GTubeTextFieldState();
}

class _GTubeTextFieldState extends State<GTubeTextField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus != _focused) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GTubeTextField.radius),
        boxShadow: _focused ? AppStyles.fieldFocusShadow : null,
      ),
      child: _field(),
    );
  }

  Widget _field() {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.obscureText,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      cursorColor: AppColors.textPrimary,
      cursorWidth: 2,
      cursorHeight: 26,
      style: AppStyles.body(16, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppStyles.body(16, color: AppColors.neutral400),
        filled: true,
        fillColor: AppColors.brandAltDark,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GTubeTextField.horizontalPadding,
          vertical: GTubeTextField.verticalPadding,
        ),
        suffixIcon: widget.trailing,
        suffixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0.s),
        enabledBorder: _border(AppColors.neutral700),
        focusedBorder: _border(AppColors.brandPrimary),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error),
        errorStyle: AppStyles.caption(
          12,
          color: AppColors.error,
          weight: AppStyles.medium,
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(GTubeTextField.radius),
    borderSide: BorderSide(color: color),
  );
}

class GTubeSelectField extends StatelessWidget {
  const GTubeSelectField({
    super.key,
    required this.hint,
    required this.onTap,
    this.value,
    required this.trailing,
  });

  final String hint;
  final String? value;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return Material(
      color: AppColors.brandAltDark,
      borderRadius: BorderRadius.circular(GTubeTextField.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GTubeTextField.radius),
            border: Border.all(color: AppColors.neutral700),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: GTubeTextField.horizontalPadding,
            vertical: GTubeTextField.verticalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  filled ? value! : hint,
                  style: filled
                      ? AppStyles.body(16, color: AppColors.textPrimary)
                      : AppStyles.body(16, color: AppColors.neutral400),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
