import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class GTubeNavBar extends StatelessWidget {
  const GTubeNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    this.avatarUrl,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final String? avatarUrl;

  static double get _itemWidth => 58.s;
  static double get _gap => 20.s;
  static double get _hPadding => 20.s;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999.s),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _hPadding, vertical: 14.s),
          decoration: BoxDecoration(
            color: const Color(0x8C313131),
            borderRadius: BorderRadius.circular(999.s),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0, 10),
                blurRadius: 12.s,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: index * (_itemWidth + _gap) - 1,
                width: 60.s,
                height: 31.s,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(999.s),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        offset: Offset(0, 10),
                        blurRadius: 24.s,
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0) SizedBox(width: _gap),
                    _NavItem(
                      spec: _items[i],
                      active: i == index,
                      avatarUrl: avatarUrl,
                      onTap: () => onChanged(i),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.label, this.asset, this.width, this.height);

  final String label;

  final String? asset;
  final double width;
  final double height;
}

const _items = <_NavSpec>[
  _NavSpec(AppStrings.navHome, AppAssets.iconNavHome, 16.463, 15.881),
  _NavSpec(AppStrings.navExplore, AppAssets.iconNavExplore, 18.333, 18.333),
  _NavSpec(AppStrings.navFollowing, AppAssets.iconNavFollowing, 17.917, 17.5),
  _NavSpec(AppStrings.navYou, null, 20, 20),
];

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.active,
    required this.onTap,
    this.avatarUrl,
  });

  final _NavSpec spec;
  final bool active;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final tint = active ? AppColors.brandPrimary : AppColors.neutral400;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: GTubeNavBar._itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spec.asset case final asset?)
              DesignIcon(
                asset,
                width: spec.width.s,
                height: spec.height.s,
                box: 20.s,
                color: tint,
              )
            else
              _Avatar(url: avatarUrl, active: active),
            SizedBox(height: 4.s),
            Text(
              spec.label,
              style: AppStyles.label(
                10,
                color: tint,
                weight: AppStyles.bold,
                lineHeight: 16 / 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, this.active = false});

  final String? url;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20.s,
      height: 20.s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.buttonSecondaryActive,
        border: Border.all(
          color: active ? AppColors.brandPrimary : AppColors.textPrimary,
          width: 1.5.s,
        ),
        image: url == null || url!.isEmpty
            ? null
            : DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover),
      ),
      child: url == null || url!.isEmpty
          ? Icon(
              Icons.person,
              size: 12.s,
              color: active ? AppColors.brandPrimary : AppColors.neutral400,
            )
          : null,
    );
  }
}
