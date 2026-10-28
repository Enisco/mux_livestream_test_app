import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/library/views/playlists_screen.dart';
import 'package:test_app/features/creator/views/widgets/impact_sheets.dart'
    show showReportSheet;
import 'package:test_app/features/engagement/data/feed_card_actions.dart';
import 'package:test_app/features/engagement/data/share_link_action.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The `…` on every content card (Figma `10779-89546`).
///
/// Six variants of one sheet, which the backend answered on 2026-10-26: share
/// links, `not_interested`, mute and block all exist now, so the button that
/// used to do nothing has something to call.
///
/// Four rules the sheet has to honour, each of which is invisible if broken:
///
/// - **No count beside "Not interested".** It increments nothing, anywhere —
///   deliberately unlike `share`, which does move a public counter. The
///   creator who published the item would be the one reading such a number.
/// - **"Add to playlist" is media only** — `PARKED(1.5)`, playlists hold
///   `mediaId` and nothing else, and widening them is not planned.
/// - **Mute keeps the follow; block drops it.** The block response says
///   whether one was actually dropped, so the confirmation reads off that
///   rather than assuming.
/// - **Minting a share link is not a share.** The count moves on the
///   interaction, when the viewer actually sends it — not when the sheet
///   opens.
///
/// A refused share is final: a link is never minted for something the viewer
/// cannot already open, so "can't be shared" is the answer rather than a
/// retry.
///
/// [isOwn] drops the rows that only make sense about somebody else. Muting
/// yourself is nonsense and **reporting your own content is refused by the
/// route**, which would surface here as "Something went wrong". Only the
/// channel page knows this for certain (`isOwnedByViewer`); a feed row
/// carries no ownership flag, so it is passed where it is known rather than
/// guessed everywhere.
Future<void> showCardActionsSheet(
  BuildContext context,
  WebFeedItem item, {
  EngagementRepo? repo,
  EngagementStore? store,
  bool Function(String feature)? requireAccount,
  bool isOwn = false,
}) async {
  final engagement = repo ?? getIt<EngagementRepo>();
  final engagementStore = store ?? getIt<EngagementStore>();

  // Nothing about muting, blocking, following or reporting yourself.
  final creatorId = isOwn ? null : item.profileCreatorId;
  final creatorName = item.creatorDisplayName;
  final isCreatorRow = item.isCreatorRow;

  // Only the five types ranking can surface may be hidden; a testimony or the
  // verse of the day is a 400.
  final canHide = InteractionTypes.notInterestedTargets.contains(
    item.entityType,
  );
  final isMedia =
      item.entityType == 'media' || item.entityType == 'media_series';
  final isEvent = item.entityType == 'event';

  final hidden = engagementStore.isNotInterested(item.entityId);
  final muted = creatorId == null ? false : engagementStore.isMuted(creatorId);
  final blocked = creatorId == null
      ? false
      : engagementStore.isBlocked(creatorId);
  final following = creatorId == null
      ? false
      : engagementStore.isFollowing(
          creatorId,
          fallback: item.isFollowingCreator,
        );

  final actions = <LibraryAction>[
    const LibraryAction(
      label: AppStrings.cardShare,
      icon: HugeIcons.strokeRoundedShare08,
    ),
    // PARKED(1.5): playlists hold media only, and widening them is not
    // planned — so the row is absent on blog, devotional and event cards
    // rather than present and refused.
    if (isMedia)
      const LibraryAction(
        label: AppStrings.cardAddToPlaylist,
        icon: HugeIcons.strokeRoundedPlayList,
      ),
    if (isEvent)
      const LibraryAction(
        label: AppStrings.cardAddToCalendar,
        icon: HugeIcons.strokeRoundedCalendar03,
      ),
    if (isCreatorRow && !isOwn)
      LibraryAction(
        label: following ? AppStrings.cardUnfollow : AppStrings.cardFollow,
        icon: HugeIcons.strokeRoundedUserAdd01,
      ),
    if (!isCreatorRow)
      const LibraryAction(
        label: AppStrings.cardBookmark,
        icon: HugeIcons.strokeRoundedBookmark02,
      ),
    if (creatorId != null)
      LibraryAction(
        label: muted ? AppStrings.cardUnmute : AppStrings.cardMute,
        icon: HugeIcons.strokeRoundedVolumeOff,
      ),
    if (canHide && !isOwn)
      LibraryAction(
        label: hidden
            ? AppStrings.cardUndoNotInterested
            : AppStrings.cardNotInterested,
        icon: HugeIcons.strokeRoundedCancelCircle,
      ),
    if (creatorId != null)
      LibraryAction(
        label: blocked ? AppStrings.cardUnblock : AppStrings.cardBlock,
        icon: HugeIcons.strokeRoundedUserBlock01,
        destructive: true,
      ),
    if (!isOwn)
      const LibraryAction(
        label: AppStrings.cardReport,
        icon: HugeIcons.strokeRoundedFlag02,
        destructive: true,
      ),
  ];

  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => LibraryActionSheet(
      actions: actions,
      onSelected: (label) => Navigator.pop(sheetContext, label),
    ),
  );
  if (picked == null || !context.mounted) return;

  void say(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Everything but Share needs an account.
  bool gate(String feature) =>
      requireAccount == null ? true : requireAccount(feature);

  switch (picked) {
    case AppStrings.cardShare:
      final url = await copyShareLink(
        engagement: engagement,
        targetType: item.isCreatorRow ? 'creator' : item.entityType,
        // For a creator, send the **creator id** — the handle is resolved
        // server-side, so a rename needs no client release.
        targetId: creatorId != null && item.isCreatorRow
            ? creatorId
            : item.entityId,
      );
      // A refusal is final: the target is not shareable until its creator
      // changes its visibility, so this reports rather than retrying.
      say(url ?? AppStrings.cardShareUnavailable);

    case AppStrings.cardNotInterested:
    case AppStrings.cardUndoNotInterested:
      if (!gate('hide this')) return;
      final nowHidden = !hidden;
      engagementStore.setNotInterested(item.entityId, nowHidden);
      say(nowHidden ? AppStrings.cardHidden : AppStrings.cardHiddenUndone);
      try {
        await engagement.toggleInteraction(
          targetType: item.entityType,
          targetId: item.entityId,
          interactionType: InteractionTypes.notInterested,
        );
      } catch (e) {
        logger.w('not_interested failed', error: e);
        engagementStore.setNotInterested(item.entityId, hidden);
        say(AppStrings.cardActionFailed);
      }

    case AppStrings.cardMute:
    case AppStrings.cardUnmute:
      if (creatorId == null || !gate('mute creators')) return;
      final nowMuted = !muted;
      engagementStore.setMuted(creatorId, nowMuted);
      say(
        nowMuted
            ? AppStrings.cardMuted(creatorName)
            : AppStrings.cardUnmuted(creatorName),
      );
      try {
        await (nowMuted
            ? engagement.muteCreator(creatorId)
            : engagement.unmuteCreator(creatorId));
      } catch (e) {
        logger.w('Mute failed', error: e);
        engagementStore.setMuted(creatorId, muted);
        say(AppStrings.cardActionFailed);
      }

    case AppStrings.cardBlock:
    case AppStrings.cardUnblock:
      if (creatorId == null || !gate('block creators')) return;
      final nowBlocked = !blocked;
      engagementStore.setBlocked(creatorId, nowBlocked);
      try {
        if (nowBlocked) {
          final unfollowed = await engagement.blockCreator(creatorId);
          // Blocking drops the follow; the response says whether one was
          // actually there, so the wording is not a guess.
          if (unfollowed) engagementStore.adoptFollowing(creatorId, false);
          say(
            unfollowed
                ? AppStrings.cardBlockedUnfollowed(creatorName)
                : AppStrings.cardBlocked(creatorName),
          );
        } else {
          await engagement.unblockCreator(creatorId);
          // Unblocking does **not** re-follow.
          say(AppStrings.cardUnblocked(creatorName));
        }
      } catch (e) {
        logger.w('Block failed', error: e);
        engagementStore.setBlocked(creatorId, blocked);
        say(AppStrings.cardActionFailed);
      }

    case AppStrings.cardBookmark:
      if (!gate('save this')) return;
      // The same toggle that put it in Saved; the store owns the state so
      // every other surface agrees without a reload.
      engagementStore.toggleSave(
        targetType: item.entityType,
        targetId: item.entityId,
        fallback: FeedCardActions.baselineOf(item),
      );

    case AppStrings.cardFollow:
    case AppStrings.cardUnfollow:
      if (creatorId == null || !gate('follow creators')) return;
      engagementStore.toggleFollow(
        creatorId,
        fallback: item.isFollowingCreator,
      );

    case AppStrings.cardAddToPlaylist:
      if (!gate('use playlists')) return;
      // The playlists list is where a destination is chosen; adding from a
      // card without first naming a playlist has no screen in the design.
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const PlaylistsScreen()),
      );

    case AppStrings.cardViewEvents:
      openCreatorProfile(context, creatorId: creatorId);

    case AppStrings.cardReport:
      if (!gate('report this')) return;
      final outcome = await showReportSheet(context);
      if (outcome == null || !context.mounted) return;
      try {
        await engagement.report(
          targetType: item.entityType,
          targetId: item.entityId,
          reason: outcome.reason.slug,
          detail: outcome.detail,
        );
        say(AppStrings.commentReported);
      } catch (e) {
        // Reporting your own content is refused, as is a target that is not
        // reachable for this viewer.
        logger.w('Report refused', error: e);
        say(AppStrings.cardActionFailed);
      }

    default:
      // Add to calendar needs the device calendar and no route; Prayer
      // request, Give now and Submit testimony belong to flows that are not
      // built or are parked. The sheet does not draw a row it cannot honour,
      // so reaching here means a label was added without a case.
      logger.w('Card sheet: unhandled action "$picked"');
  }
}
