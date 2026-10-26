import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Who this viewer has muted or blocked, and the only way to undo either.
///
/// **The blocked list is not optional.** A blocked creator is hidden from
/// every surface a viewer could rediscover them on — feeds, Explore, search,
/// even their own channel page — so without this screen the `DELETE` is
/// unreachable and a block can never be lifted. The backend flagged it as a
/// route the app had not asked for and needed.
///
/// Muted is the softer half and has another way back: a muted creator stays
/// in `following-creators`, which carries `isMuted`. This screen is still the
/// one that lists them together.
class HiddenCreatorsScreen extends StatefulWidget {
  const HiddenCreatorsScreen({super.key, this.repo, this.store});

  final EngagementRepo? repo;
  final EngagementStore? store;

  @override
  State<HiddenCreatorsScreen> createState() => _HiddenCreatorsScreenState();
}

class _HiddenCreatorsScreenState extends State<HiddenCreatorsScreen> {
  late final _repo = widget.repo ?? getIt<EngagementRepo>();
  late final _store = widget.store ?? getIt<EngagementStore>();

  bool _blockedTab = false;
  List<HiddenCreator> _muted = const [];
  List<HiddenCreator> _blocked = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // Both at once: the tabs switch without a second wait, and the counts
      // beside them are right from the first frame.
      //
      // `Future.wait` rather than two bare awaits: awaiting them in sequence
      // leaves the second read's failure unobserved when the first one is
      // the one that threw, which surfaces as an unhandled async error well
      // away from here.
      final rows = await Future.wait([
        _repo.fetchHiddenCreators(blocked: false),
        _repo.fetchHiddenCreators(blocked: true),
      ]);
      if (!mounted) return;
      setState(() {
        _muted = rows.first;
        _blocked = rows.last;
        _loading = false;
      });
      _store
        ..seedMuted(_muted.map((c) => c.creatorId))
        ..seedBlocked(_blocked.map((c) => c.creatorId));
    } catch (e) {
      logger.w('Hidden creators failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Optimistic, and put back if the write is refused.
  ///
  /// **Unblocking does not re-follow.** It makes the creator visible and
  /// stops there; the viewer never asked to follow them twice.
  Future<void> _restore(HiddenCreator creator) async {
    final blocked = _blockedTab;
    // Where it was, so putting it back after a refusal does not silently
    // reorder the list.
    final was = (blocked ? _blocked : _muted).indexWhere(
      (c) => c.creatorId == creator.creatorId,
    );
    setState(() {
      if (blocked) {
        _blocked = [..._blocked]
          ..removeWhere((c) => c.creatorId == creator.creatorId);
      } else {
        _muted = [..._muted]
          ..removeWhere((c) => c.creatorId == creator.creatorId);
      }
    });
    if (blocked) {
      _store.setBlocked(creator.creatorId, false);
    } else {
      _store.setMuted(creator.creatorId, false);
    }

    try {
      await (blocked
          ? _repo.unblockCreator(creator.creatorId)
          : _repo.unmuteCreator(creator.creatorId));
    } catch (e) {
      logger.w('Restore failed', error: e);
      if (!mounted) return;
      setState(() {
        if (blocked) {
          _blocked = [..._blocked]
            ..insert(was.clamp(0, _blocked.length), creator);
          _store.setBlocked(creator.creatorId, true);
        } else {
          _muted = [..._muted]..insert(was.clamp(0, _muted.length), creator);
          _store.setMuted(creator.creatorId, true);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.cardActionFailed, style: AppStyles.body(13)),
          backgroundColor: AppColors.neutral800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _blockedTab ? _blocked : _muted;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryHeader(
            title: AppStrings.hiddenTitle,
            bottom: LibraryFilterChips(
              labels: const [
                AppStrings.hiddenMutedTab,
                AppStrings.hiddenBlockedTab,
              ],
              selected: _blockedTab
                  ? AppStrings.hiddenBlockedTab
                  : AppStrings.hiddenMutedTab,
              onSelected: (label) => setState(
                () => _blockedTab = label == AppStrings.hiddenBlockedTab,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  )
                : _failed
                ? ErrorStateView(onRetry: _load)
                : rows.isEmpty
                ? SingleChildScrollView(
                    child: LibraryEmptyState(
                      icon: _blockedTab
                          ? HugeIcons.strokeRoundedUserBlock01
                          : HugeIcons.strokeRoundedVolumeOff,
                      title: _blockedTab
                          ? AppStrings.hiddenBlockedEmptyTitle
                          : AppStrings.hiddenMutedEmptyTitle,
                      body: _blockedTab
                          ? AppStrings.hiddenBlockedEmptyBody
                          : AppStrings.hiddenMutedEmptyBody,
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.only(top: 12.s, bottom: 40.s),
                    children: [
                      for (final creator in rows)
                        _Row(
                          creator: creator,
                          blocked: _blockedTab,
                          // A muted creator's page is still reachable; a
                          // blocked one's is not, so only one is tappable.
                          onTap: _blockedTab
                              ? null
                              : () => openCreatorProfile(
                                  context,
                                  creatorId: creator.creatorId,
                                ),
                          onRestore: () => unawaited(_restore(creator)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.creator,
    required this.blocked,
    required this.onTap,
    required this.onRestore,
  });

  final HiddenCreator creator;
  final bool blocked;
  final VoidCallback? onTap;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('hidden-${creator.creatorId}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.s),
        padding: EdgeInsets.symmetric(vertical: 14.s),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutral900)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    creator.displayName.isEmpty
                        ? creator.handle
                        : creator.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(14, weight: AppStyles.bold),
                  ),
                  if (creator.handle.isNotEmpty) ...[
                    SizedBox(height: 3.s),
                    Text(
                      '@${creator.handle}',
                      style: AppStyles.label(
                        12,
                        color: AppColors.neutral500,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 12.s),
            GestureDetector(
              key: ValueKey('restore-${creator.creatorId}'),
              behavior: HitTestBehavior.opaque,
              onTap: onRestore,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 8.s),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.s),
                  border: Border.all(color: AppColors.neutral700),
                ),
                child: Text(
                  blocked ? AppStrings.cardUnblock : AppStrings.cardUnmute,
                  style: AppStyles.button(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
