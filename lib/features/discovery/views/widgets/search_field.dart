import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The search header: a back arrow beside the field.
///
/// The field takes a brand-coloured ring while it holds focus and a neutral one
/// once a query has been committed, which is how the design distinguishes "I am
/// typing" from "these are the results".
class SearchHeaderField extends StatelessWidget {
  const SearchHeaderField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.onBack,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 12.s),
      child: Row(
        children: [
          GTubeBackButton(onTap: onBack, size: 24, box: 24),
          SizedBox(width: 10.s),
          Expanded(
            child: ListenableBuilder(
              // Both the ring and the clear button track state the field owns,
              // so this rebuilds on focus and on every keystroke.
              listenable: Listenable.merge([focusNode, controller]),
              builder: (context, _) => _field(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field() {
    final focused = focusNode.hasFocus;
    return Container(
      height: 34.s,
      padding: EdgeInsets.symmetric(horizontal: 20.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(18.s),
        border: Border.all(
          color: focused ? AppColors.brandPrimary : AppColors.neutral900,
          width: 2.s,
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: AppColors.neutral300,
            size: 18.s,
          ),
          SizedBox(width: 5.s),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.brandPrimary,
              style: AppStyles.label(
                12,
                color: AppColors.neutral200,
                lineHeight: 16 / 12,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: AppStrings.searchFieldHint,
                hintStyle: AppStyles.label(
                  12,
                  color: AppColors.neutral300,
                  lineHeight: 16 / 12,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: EdgeInsets.only(left: 6.s),
                child: Icon(
                  Icons.close_rounded,
                  size: 18.s,
                  color: AppColors.neutral300,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
