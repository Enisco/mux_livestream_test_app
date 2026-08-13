import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum OrgType {
  church(AppStrings.orgTypeChurch),
  ministry(AppStrings.orgTypeMinistry),
  bibleSchool(AppStrings.orgTypeBibleSchool),
  others(AppStrings.orgTypeOthers);

  const OrgType(this.label);

  final String label;
}

class OrgTypeSheet extends StatelessWidget {
  const OrgTypeSheet({super.key});

  static Future<OrgType?> show(BuildContext context) =>
      showModalBottomSheet<OrgType>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => const OrgTypeSheet(),
      );

  static const _height = 236.0;
  static const _cornerRadius = 24.0;
  static const _handleWidth = 40.0;
  static const _listWidth = 350.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: const BoxDecoration(
        color: AppColors.base1,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_cornerRadius),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          const SizedBox(
            width: _handleWidth,
            height: 3,
            child: ColoredBox(color: AppColors.neutral400),
          ),
          const SizedBox(height: 23),
          Center(
            child: SizedBox(
              width: _listWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.base1,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppStyles.fieldFocusShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final type in OrgType.values)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(type),
                          child: Container(
                            width: double.infinity,
                            color: AppColors.base2,
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              type.label,
                              style: AppStyles.body(
                                13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
