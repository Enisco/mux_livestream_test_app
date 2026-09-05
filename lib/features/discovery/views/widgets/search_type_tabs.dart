import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/data/search_query.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The type filter over a set of results.
///
/// Only the seven the design draws are offered. [SearchFilter] also carries
/// `live` and `series`, which the API accepts but this row does not show — they
/// stay reachable from Home, where the live tab already exists.
const _tabs = <SearchFilter>[
  SearchFilter.all,
  SearchFilter.creators,
  SearchFilter.audio,
  SearchFilter.videos,
  SearchFilter.devotionals,
  SearchFilter.blogs,
  SearchFilter.events,
];

/// "All" is a word on its own; every other tab leads with a glyph.
final _icons = <SearchFilter, List<List<dynamic>>>{
  SearchFilter.creators: HugeIcons.strokeRoundedBuilding06,
  SearchFilter.audio: HugeIcons.strokeRoundedMusicNote01,
  SearchFilter.videos: HugeIcons.strokeRoundedPlayCircle,
  SearchFilter.devotionals: HugeIcons.strokeRoundedBookOpen01,
  SearchFilter.blogs: HugeIcons.strokeRoundedNews,
  SearchFilter.events: HugeIcons.strokeRoundedCalendarAdd01,
};

class SearchTypeTabs extends StatelessWidget {
  const SearchTypeTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final SearchFilter selected;
  final ValueChanged<SearchFilter> onSelected;

  static double get height => 38;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height.s,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 24.s, vertical: 3.s),
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => SizedBox(width: 10.s),
        itemBuilder: (context, i) => _Tab(
          filter: _tabs[i],
          active: _tabs[i] == selected,
          onTap: () => onSelected(_tabs[i]),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.filter, required this.active, required this.onTap});

  final SearchFilter filter;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _icons[filter];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 32.s,
        padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 8.s),
        decoration: BoxDecoration(
          color: active
              ? AppColors.textPrimary
              : AppColors.buttonSecondaryActive,
          borderRadius: BorderRadius.circular(10.s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              HugeIcon(
                icon: icon,
                color: active ? AppColors.base1 : AppColors.textPrimary,
                size: 20.s,
              ),
              SizedBox(width: 6.s),
            ],
            Text(
              filter.label,
              style: AppStyles.label(
                12,
                weight: AppStyles.bold,
                color: active ? AppColors.base1 : AppColors.textPrimary,
                lineHeight: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
