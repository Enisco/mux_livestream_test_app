import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum HomeTab { discover, following, live }

class HomeFeedHeader extends StatelessWidget {
  const HomeFeedHeader({
    super.key,
    required this.tab,
    required this.onTabChanged,
    required this.topics,
    required this.selectedTopic,
    required this.onTopicChanged,
    this.onEditTopics,
  });

  final HomeTab tab;
  final ValueChanged<HomeTab> onTabChanged;

  final List<String> topics;
  final String? selectedTopic;
  final ValueChanged<String?> onTopicChanged;
  final VoidCallback? onEditTopics;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3.15, sigmaY: 3.15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0x850D0D0D),
            border: Border(
              bottom: BorderSide(color: AppColors.neutral900, width: 2.s),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topInset + 6, bottom: 28.s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Tabs(tab: tab, onChanged: onTabChanged),
                SizedBox(height: 22.s),
                _TopicRail(
                  topics: topics,
                  selected: selectedTopic,
                  onChanged: onTopicChanged,
                  onEdit: onEditTopics,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab, required this.onChanged});

  final HomeTab tab;
  final ValueChanged<HomeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TabLabel(
          label: AppStrings.tabDiscover,
          active: tab == HomeTab.discover,
          onTap: () => onChanged(HomeTab.discover),
        ),
        SizedBox(width: 43.5.s),
        _TabLabel(
          label: AppStrings.tabFollowing,
          active: tab == HomeTab.following,
          onTap: () => onChanged(HomeTab.following),
        ),
        SizedBox(width: 43.5.s),
        _TabLabel(
          label: AppStrings.tabLive,
          active: tab == HomeTab.live,
          leadingDot: true,
          onTap: () => onChanged(HomeTab.live),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.active,
    required this.onTap,
    this.leadingDot = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool leadingDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingDot) ...[
                DesignIcon(
                  AppAssets.iconFeedLiveDot,
                  width: 7.s,
                  height: 7.s,
                  box: 8,
                ),
                SizedBox(width: 4.s),
              ],
              Text(
                label,
                style: AppStyles.label(
                  14,
                  color: active ? AppColors.textPrimary : AppColors.neutral500,
                  weight: AppStyles.bold,
                  lineHeight: 20 / 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.s),
          Container(
            height: 2.s,
            width: 57.s,
            decoration: BoxDecoration(
              color: active ? AppColors.brandPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(36.s),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicRail extends StatelessWidget {
  const _TopicRail({
    required this.topics,
    required this.selected,
    required this.onChanged,
    this.onEdit,
  });

  final List<String> topics;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32.s,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 24.s),
        children: [
          _Chip(
            label: AppStrings.topicAll,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final topic in topics) ...[
            SizedBox(width: 10.s),
            _Chip(
              label: topic,
              selected: selected == topic,
              onTap: () => onChanged(topic),
            ),
          ],
          if (onEdit != null) ...[
            SizedBox(width: 10.s),
            _Chip(label: AppStrings.editTopics, outlined: true, onTap: onEdit!),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// The "Edit topics" affordance: brand border and label, unfilled.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final Color fill = selected
        ? AppColors.textPrimary
        : AppColors.buttonSecondaryActive;
    final Color label0 = outlined
        ? AppColors.brandPrimary
        : selected
        ? AppColors.base1
        : AppColors.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32.s,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 10.s),
        decoration: BoxDecoration(
          color: outlined ? AppColors.buttonSecondaryActive : fill,
          borderRadius: BorderRadius.circular(10.s),
          border: outlined
              ? Border.all(color: AppColors.brandPrimary, width: 1.5.s)
              : null,
        ),
        child: Text(
          label,
          style: AppStyles.label(
            12,
            color: label0,
            weight: AppStyles.bold,
            lineHeight: 16 / 12,
          ),
        ),
      ),
    );
  }
}
