import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_dashboard_repo.dart';
import 'package:test_app/features/creator/views/giving_screen.dart';
import 'package:test_app/features/creator/views/impact_screen.dart';
import 'package:test_app/features/creator/views/studio_content_screen.dart';
import 'package:test_app/features/creator/views/studio_screen.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The creator studio, and the four things it is made of.
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
    final repo = CreatorDashboardRepo();
    final context = await repo.fetchContext(creatorId);
    if (mounted) setState(() => _context = context);

    unawaited(_loadStudios());

    final attention = await repo.fetchAttention(creatorId);
    if (!mounted) return;
    setState(() => _impactBadge = attention.fold(0, (sum, i) => sum + i.count));
  }

  /// Every studio the reader can work in, shared by all four tabs so the
  /// switcher says the same thing wherever it is opened from.
  List<StudioMembership> _studios = const [];

  Future<void> _loadStudios() async {
    try {
      final studios = await CreatorDashboardRepo().fetchMemberships();
      if (mounted) setState(() => _studios = studios);
    } catch (e) {
      logger.w('Studio memberships unavailable', error: e);
    }
  }

  /// Open the switcher, and re-point the whole shell if one is picked.
  ///
  /// `creatorId` in storage is what every tab reads, so switching is: write
  /// it, drop the cached context, and load again. Per-studio permissions come
  /// from `dashboard/context`, which is re-read for the new one.
  Future<void> switchStudio(String creatorId) async {
    await LocalStorage.setString(LocalStorage.creatorIdKey, creatorId);
    if (!mounted) return;
    setState(() {
      _context = null;
      _impactBadge = 0;
    });
    await _loadContext();
  }

  /// How many things are waiting, for the badge on the Impact tab.
  ///
  /// This was hardcoded to the design's `18`, which meant every studio
  /// claimed eighteen things needed attention whatever was actually there.
  /// It is the sum of the dashboard's attention feed now, and a studio with
  /// nothing waiting carries no badge at all.
  int _impactBadge = 0;

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
                studios: _studios,
                onSwitchStudio: switchStudio,
              ),
              1 => StudioContentScreen(
                context: _context,
                studios: _studios,
                onSwitchStudio: switchStudio,
              ),
              2 => ImpactScreen(
                context: _context,
                studios: _studios,
                onSwitchStudio: switchStudio,
              ),
              _ => GivingScreen(
                context: _context,
                studios: _studios,
                onSwitchStudio: switchStudio,
              ),
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
