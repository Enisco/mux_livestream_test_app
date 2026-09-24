import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_dashboard_repo.dart';
import 'package:test_app/features/creator/views/studio_content_screen.dart';
import 'package:test_app/features/creator/views/studio_screen.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The creator studio, and the four things it is made of.
///
/// Content, Impact and Giving are their own Figma sections and are not built
/// yet; each says so rather than showing an empty screen that looks broken.
class StudioShell extends StatefulWidget {
  const StudioShell({super.key});

  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  int _tab = 0;

  /// Fetched once for the shell so every tab shares one answer rather than
  /// each asking again on every switch.
  DashboardContext? _context;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) return;
    final context = await CreatorDashboardRepo().fetchContext(creatorId);
    if (mounted) setState(() => _context = context);
  }

  /// Impact carries the count of things waiting; the design shows it on the
  /// tab itself so it is visible from anywhere in the studio.
  static const _impactBadge = 18;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Stack(
        children: [
          Positioned.fill(
            child: switch (_tab) {
              0 => StudioScreen(
                onLeaveStudio: () => context.go(AppRouter.home),
              ),
              1 => StudioContentScreen(context: _context),
              2 => const _NotBuilt(AppStrings.studioTabImpact),
              _ => const _NotBuilt(AppStrings.studioTabGiving),
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 12.s),
                child: _StudioNavBar(
                  index: _tab,
                  impactBadge: _impactBadge,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating four-tab bar.
class _StudioNavBar extends StatelessWidget {
  const _StudioNavBar({
    required this.index,
    required this.impactBadge,
    required this.onChanged,
  });

  final int index;
  final int impactBadge;
  final ValueChanged<int> onChanged;

  static const _tabs = <(String, List<List<dynamic>>)>[
    (AppStrings.studioTab, HugeIcons.strokeRoundedGridView),
    (AppStrings.studioTabContent, HugeIcons.strokeRoundedLayers01),
    (AppStrings.studioTabImpact, HugeIcons.strokeRoundedFavourite),
    (AppStrings.studioTabGiving, HugeIcons.strokeRoundedGift),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 8.s),
      decoration: BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.circular(999.s),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (i, (label, icon)) in _tabs.indexed)
            _NavTab(
              key: ValueKey('studio-tab-$i'),
              label: label,
              icon: icon,
              active: i == index,
              badge: i == 2 && impactBadge > 0 ? impactBadge : null,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final String label;
  final List<List<dynamic>> icon;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final tint = active ? AppColors.brandPrimary : AppColors.neutral400;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 6.s),
        decoration: BoxDecoration(
          color: active ? AppColors.fieldBg : Colors.transparent,
          borderRadius: BorderRadius.circular(999.s),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                HugeIcon(icon: icon, color: tint, size: 19.s),
                if (badge case final count?)
                  Positioned(
                    right: -8.s,
                    top: -6.s,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.s,
                        vertical: 1.s,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        borderRadius: BorderRadius.circular(999.s),
                      ),
                      child: Text(
                        '$count',
                        style: AppStyles.label(
                          9,
                          weight: AppStyles.bold,
                          color: AppColors.base1,
                          lineHeight: 12 / 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4.s),
            Text(
              label,
              style: AppStyles.label(
                10,
                weight: active ? AppStyles.bold : AppStyles.medium,
                color: tint,
                lineHeight: 13 / 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tab whose Figma section has not been built yet.
class _NotBuilt extends StatelessWidget {
  const _NotBuilt(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.s),
      child: Text(
        '$name is not built yet',
        textAlign: TextAlign.center,
        style: AppStyles.body(14, color: AppColors.neutral400),
      ),
    ),
  );
}
