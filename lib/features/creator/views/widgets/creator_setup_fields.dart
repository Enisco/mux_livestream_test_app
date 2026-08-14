import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sizing/sizing.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum HandleState { idle, checking, available, taken, invalid }

const _radius = 8.0;

OutlineInputBorder creatorFieldBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(_radius),
  borderSide: BorderSide(color: color),
);

class CreatorFieldLabel extends StatelessWidget {
  const CreatorFieldLabel(
    this.text, {
    super.key,
    this.size = 12,
    this.bold = false,
  });

  final String text;
  final double size;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          AppStyles.caption(
            12,
            color: AppColors.textPrimary,
            weight: AppStyles.medium,
            lineHeight: 16 / 12,
          ).copyWith(
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
    );
  }
}

class CreatorTextField extends StatelessWidget {
  const CreatorTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.contentPadding = const EdgeInsets.all(16),
  });

  final TextEditingController controller;
  final String hint;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppStyles.body(13, color: AppColors.neutral50),
      cursorColor: AppColors.textPrimary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppStyles.body(13, color: AppColors.neutral400),
        filled: true,
        fillColor: AppColors.brandAltDark,
        isDense: true,
        contentPadding: contentPadding,
        enabledBorder: creatorFieldBorder(AppColors.neutral700),
        focusedBorder: creatorFieldBorder(AppColors.brandPrimary),
      ),
    );
  }
}

class CreatorSelectField extends StatelessWidget {
  const CreatorSelectField({
    super.key,
    required this.hint,
    required this.onTap,
    this.value,
    this.contentPadding = const EdgeInsets.all(16),
  });

  final String hint;
  final String? value;
  final VoidCallback onTap;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final filled = value != null && value!.isNotEmpty;
    return Material(
      color: AppColors.brandAltDark,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: AppColors.neutral700),
          ),
          padding: contentPadding,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  filled ? value! : hint,
                  style: filled
                      ? AppStyles.body(13, color: AppColors.neutral50)
                      : AppStyles.body(13, color: AppColors.neutral400),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset(
                AppAssets.iconChevronDown,
                width: 7.072,
                height: 4.713,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreatorHandleField extends StatelessWidget {
  const CreatorHandleField({
    super.key,
    required this.controller,
    required this.state,
    required this.normalizedHandle,
    required this.availableLabel,
    required this.takenLabel,
    required this.invalidLabel,
    required this.prefix,
  });

  final TextEditingController controller;
  final HandleState state;
  final String normalizedHandle;
  final String availableLabel;
  final String takenLabel;
  final String invalidLabel;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final resolved = state == HandleState.available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: resolved ? AppStyles.fieldFocusShadow : null,
          ),
          child: TextField(
            controller: controller,
            style: AppStyles.body(13, color: AppColors.neutral50),
            cursorColor: AppColors.textPrimary,
            autocorrect: false,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.brandAltDark,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Text(
                  prefix,
                  style: AppStyles.body(13, color: AppColors.neutral50),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: resolved
                  ? Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SvgPicture.asset(
                        AppAssets.iconCheckCircle,
                        width: 20,
                        height: 20,
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              enabledBorder: creatorFieldBorder(
                resolved ? AppColors.brandPrimary : AppColors.neutral700,
              ),
              focusedBorder: creatorFieldBorder(AppColors.brandPrimary),
            ),
          ),
        ),
        if (state != HandleState.idle && state != HandleState.checking) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (resolved) ...[
                Icon(
                  CupertinoIcons.check_mark,
                  color: AppColors.green500,
                  size: 16,
                ),
                SizedBox(width: 3.s),
              ],
              Flexible(
                child: Text(
                  switch (state) {
                    HandleState.available => '$availableLabel$normalizedHandle',
                    HandleState.taken => takenLabel,
                    _ => invalidLabel,
                  },
                  style: resolved
                      ? AppStyles.caption(
                          10,
                          color: AppColors.green500,
                          weight: AppStyles.medium,
                        )
                      : AppStyles.caption(
                          10,
                          color: AppColors.error,
                          weight: AppStyles.medium,
                        ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
