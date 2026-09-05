import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The bar over History: where the reader came from, what the screen is, the
/// way to wipe it, and a field to narrow it.
///
/// It sits over the list rather than scrolling with it, and blurs what passes
/// underneath, so "Clear all" and the field stay reachable the whole way down.
class HistoryHeader extends StatelessWidget {
  const HistoryHeader({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    this.onBack,
    this.onClearAll,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onBack;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3.15, sigmaY: 3.15),
        child: Container(
          color: AppColors.base1.withValues(alpha: 0.73),
          padding: EdgeInsets.fromLTRB(
            20.s,
            MediaQuery.paddingOf(context).top + 10.s,
            20.s,
            20.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GTubeBackButton(onTap: onBack, size: 24, box: 24),
                        SizedBox(width: 12.s),
                        Flexible(
                          child: Text(
                            AppStrings.historyTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.label(
                              18,
                              weight: AppStyles.bold,
                              lineHeight: 28 / 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.s),
                  _ClearAll(onTap: onClearAll),
                ],
              ),
              SizedBox(height: 22.s),
              _SearchField(
                controller: controller,
                onChanged: onQueryChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearAll extends StatelessWidget {
  const _ClearAll({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(8.s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedDelete02,
              color: AppColors.neutral400,
              size: 12.s,
            ),
            SizedBox(width: 4.s),
            Text(
              AppStrings.historyClearAll,
              style: AppStyles.label(
                12,
                weight: AppStyles.black,
                color: AppColors.neutral400,
                lineHeight: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34.s,
      padding: EdgeInsets.symmetric(horizontal: 20.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(18.s),
        border: Border.all(color: AppColors.neutral900, width: 2.s),
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
              onChanged: onChanged,
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
                hintText: AppStrings.historySearchHint,
                hintStyle: AppStyles.label(
                  12,
                  color: AppColors.neutral300,
                  lineHeight: 16 / 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One part-watched item on the rail across the top of History.
class HistoryResumeCard extends StatelessWidget {
  const HistoryResumeCard({super.key, required this.item, this.onTap});

  static const double width = 235;

  final HistoryResumeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width.s,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.s),
              child: SizedBox(
                height: 139.s,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.thumbnailAsset case final asset?)
                      Image.asset(asset, fit: BoxFit.cover)
                    else if (item.thumbnailUrl case final url?)
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.base2),
                      )
                    else
                      const ColoredBox(color: AppColors.base2),
                    if (item.isAudio)
                      Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMusicNote01,
                          color: AppColors.textPrimary,
                          size: 20.s,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: 4.s,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: item.progress.clamp(0, 1),
                                child: const ColoredBox(
                                  color: AppColors.progressFill,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.s),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.label(13, weight: AppStyles.bold),
            ),
            SizedBox(height: 4.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    item.creatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.body(
                      12,
                      weight: AppStyles.regular,
                      color: AppColors.neutral200,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ),
                if (item.creatorVerified) ...[
                  SizedBox(width: 4.s),
                  DesignIcon(
                    AppAssets.iconFeedVerified,
                    width: 14.s,
                    height: 14.s,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing watched yet — or nothing matching what was typed.
class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 40.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70.s,
            height: 70.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandPrimary.withValues(alpha: 0.15),
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                color: AppColors.brandPrimary,
                size: 37.s,
              ),
            ),
          ),
          SizedBox(height: 10.s),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppStyles.heading(20, lineHeight: 28 / 20),
          ),
          SizedBox(height: 10.s),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppStyles.body(
              13,
              color: AppColors.neutral400,
              lineHeight: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }
}
