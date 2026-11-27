import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/library/views/add_to_playlist_sheet.dart';
import 'package:test_app/features/creator/views/widgets/impact_sheets.dart'
    show showReportSheet;
import 'package:test_app/features/engagement/data/feed_card_actions.dart';
import 'package:test_app/features/engagement/data/share_link_action.dart';
import 'package:test_app/features/giving/data/give_action.dart';
import 'package:test_app/features/giving/data/giving_capability_store.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The `…` on every content card (Figma `10779-89546`).
Future<void> showCardActionsSheet(
  BuildContext context,
  WebFeedItem item, {
  EngagementRepo? repo,
  EngagementStore? store,
  GivingCapabilityStore? givingCapabilities,
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
  // PARKED(1.5): a playlist holds **media**, one row at a time. Widening
  // that is not planned backend-side, and a media *series* is not one of
  // its items either — `POST .../items` refuses a series id. So the row
  // is absent on a blog, a devotional, an event and a series, rather than
  // present and always failing.
  final canAddToPlaylist =
      item.entityType == 'media' && item.entityId.isNotEmpty;
  final isEvent = item.entityType == 'event';

  // The interaction API's own name for this row's type, which is not
  // always the feed's `entityType` — a `devotional_series` interacts as a
  // `devotional`, a `calendar_event` as an `event`. The card reads and
  // writes through this mapping, so the sheet has to as well or the two
  // keep separate state for the same thing. Null for a creator row or a
  // media series, which carry no interactions at all.
  final saveTarget = InteractionTargets.fromEntityType(item.entityType);
  final saved =
      saveTarget != null &&
      engagementStore
          .resolve(saveTarget, item.entityId, FeedCardActions.baselineOf(item))
          .saved;

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

  // Asked before the sheet is built, because a row cannot appear after it
  // is open.
  final canGive =
      creatorId != null &&
      (givingCapabilities ?? getIt<GivingCapabilityStore>()).known(creatorId) ==
          true;

  final actions = <LibraryAction>[
    const LibraryAction(
      label: AppStrings.cardShare,
      icon: HugeIcons.strokeRoundedShare08,
    ),
    if (canGive)
      const LibraryAction(
        label: AppStrings.cardGiveNow,
        icon: HugeIcons.strokeRoundedGift,
      ),
    if (canAddToPlaylist)
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
    // Says which way it goes. The row was a fixed "Bookmark" however long
    // the thing had been saved, so there was no way to tell from the sheet
    // that it already was, and no way to take it out from here.
    if (saveTarget != null)
      LibraryAction(
        label: saved ? AppStrings.cardBookmarked : AppStrings.cardBookmark,
        icon: saved
            ? HugeIcons.strokeRoundedBookmark03
            : HugeIcons.strokeRoundedBookmark02,
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

  // Resolved once, up front, rather than through `context` each time.
  // Most of these handlers report **after** awaiting the server, and by
  // then the reader may well have left — blocking a ministry now closes
  // its page under them. A messenger read from a dead context meant the
  // answer, including "that did not work", was simply never shown.
  // `maybeOf`, not `of`: resolving it up front would otherwise turn a
  // missing messenger from "no snackbar" into a throw on opening the
  // sheet, for a caller that may never show one.
  final messenger = ScaffoldMessenger.maybeOf(context);

  void say(String message) {
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(
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
      final outcome = await shareLink(
        engagement: engagement,
        targetType: item.isCreatorRow ? 'creator' : item.entityType,
        // For a creator, send the **creator id** — the handle is resolved
        // server-side, so a rename needs no client release.
        targetId: creatorId != null && item.isCreatorRow
            ? creatorId
            : item.entityId,
        subject: item.title,
        from: shareOriginOf(context),
      );
      // Only a refusal is worth saying out loud, and it is final: the
      // target is not shareable until its creator changes its visibility.
      // A sheet the reader opened and backed out of needs no snackbar.
      if (outcome == ShareLinkOutcome.unavailable) {
        say(AppStrings.cardShareUnavailable);
      }

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
    case AppStrings.cardBookmarked:
      if (saveTarget == null || !gate('save this')) return;
      // The same toggle the card's own bookmark runs, on the same key, so
      // the two cannot drift apart: the store owns the state and every
      // surface watching it redraws without a reload.
      engagementStore.toggleSave(
        targetType: saveTarget,
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
      // This used to push the playlists *browse* screen, which has no way
      // to know what is being added — so a reader could tap through a
      // playlist, or make one, and nothing was ever put in it.
      final chosen = await showAddToPlaylistSheet(
        context,
        mediaId: item.entityId,
      );
      if (chosen != null) say(chosen.message);

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
        // Out of the lists at once. The report itself suppresses nothing
        // server-side — a moderator decides that — but scrolling back
        // past what you just objected to is its own insult.
        engagementStore.setReported(item.entityId);
        say(AppStrings.commentReported);
      } catch (e) {
        // Reporting your own content is refused, as is a target that is not
        // reachable for this viewer.
        logger.w('Report refused', error: e);
        say(AppStrings.cardActionFailed);
      }

    case AppStrings.cardGiveNow:
      // Only drawn when the ministry is known to be able to receive, so the
      // giver is not sent at a refusal.
      if (creatorId == null || !context.mounted) return;
      await startGive(
        context,
        creatorId: creatorId,
        ministryName: creatorName,
        requireAccount: gate,
      );

    default:
      // Add to calendar needs the device calendar and no route; Prayer
      // request and Submit testimony belong to flows that are not built or
      // are parked.
      logger.w('Card sheet: unhandled action "$picked"');
  }
}
