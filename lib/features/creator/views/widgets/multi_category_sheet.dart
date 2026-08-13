import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class MultiCategorySheet extends StatefulWidget {
  const MultiCategorySheet({
    super.key,
    required this.categories,
    required this.initialSelection,
  });

  final List<ContentCategory> categories;
  final Set<String> initialSelection;

  static Future<Set<String>?> show(
    BuildContext context,
    List<ContentCategory> categories,
    Set<String> initialSelection,
  ) => showModalBottomSheet<Set<String>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => MultiCategorySheet(
      categories: categories,
      initialSelection: initialSelection,
    ),
  );

  static const _cornerRadius = 24.0;
  static const _handleWidth = 40.0;

  @override
  State<MultiCategorySheet> createState() => _MultiCategorySheetState();
}

class _MultiCategorySheetState extends State<MultiCategorySheet> {
  late final Set<String> _selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.base1,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MultiCategorySheet._cornerRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          const SizedBox(
            width: MultiCategorySheet._handleWidth,
            height: 3,
            child: ColoredBox(color: AppColors.neutral400),
          ),
          const SizedBox(height: 23),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final category in widget.categories)
                    _Row(
                      label: category.name,
                      checked: _selected.contains(category.slug),
                      onTap: () => setState(() {
                        if (!_selected.remove(category.slug)) {
                          _selected.add(category.slug);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 0, 7, 24),
            child: PrimaryButton(
              label: AppStrings.addSelection,
              height: 54,
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.checked, required this.onTap});

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: AppColors.base2,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppStyles.body(13, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 20,
              height: 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    AppAssets.iconCheckbox,
                    width: 20,
                    height: 20,
                  ),
                  if (checked)
                    SvgPicture.asset(
                      AppAssets.iconCheck,
                      width: 14,
                      height: 14,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
