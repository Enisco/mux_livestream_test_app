import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/creator_models/impact_models.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The three things a congregation sends, as tabs with a count each.
class ImpactTabs extends StatelessWidget {
  const ImpactTabs({
    super.key,
    required this.index,
    required this.counts,
    required this.onChanged,
  });

  final int index;

  /// Prayer, testimony and comment totals, in that order. A null count is one
  /// the API has not answered for — the pill shows the label alone rather
  /// than a zero it cannot stand behind.
  final List<int?> counts;

  final ValueChanged<int> onChanged;

  static const labels = [
    AppStrings.impactTabPrayer,
    AppStrings.impactTabTestimony,
    AppStrings.impactTabComments,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, label) in labels.indexed) ...[
            if (i > 0) SizedBox(width: 8.s),
            _TabPill(
              label: label,
              count: i < counts.length ? counts[i] : null,
              active: i == index,
              onTap: () => onChanged(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('impact-tab-$label'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 9.s),
      decoration: BoxDecoration(
        color: active ? AppColors.brandPrimary : AppColors.neutral800,
        borderRadius: BorderRadius.circular(999.s),
      ),
      child: Text(
        count == null ? label : '$label · $count',
        style: AppStyles.label(
          13,
          weight: AppStyles.bold,
          color: active ? AppColors.base1 : AppColors.neutral200,
        ),
      ),
    ),
  );
}

/// "VIEWING ALL PRAYERS" on the left, the state this list is narrowed to on
/// the right.
class ImpactFilterRow extends StatelessWidget {
  const ImpactFilterRow({
    super.key,
    required this.viewing,
    required this.state,
    required this.onTapState,
  });

  final String viewing;
  final String state;
  final VoidCallback onTapState;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            viewing,
            style: AppStyles.label(
              12,
              weight: AppStyles.bold,
              color: AppColors.neutral500,
              letterSpacing: 0.4,
            ),
          ),
        ),
        GestureDetector(
          key: const ValueKey('impact-filter'),
          behavior: HitTestBehavior.opaque,
          onTap: onTapState,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.toUpperCase(),
                style: AppStyles.label(
                  12,
                  weight: AppStyles.bold,
                  color: AppColors.neutral300,
                  letterSpacing: 0.4,
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 20.s,
                color: AppColors.neutral300,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Avatar, name and how long ago — the head of every card on this screen.
///
/// [person] is the gateway's resolved identity and the only thing a client
/// may render as the sender. It already carries the right words for an
/// anonymous submitter and for a profile that could not be looked up, so it
/// is shown as-is.
class ImpactSender extends StatelessWidget {
  const ImpactSender({super.key, this.person, this.at, this.trailing});

  final ImpactPerson? person;
  final DateTime? at;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final resolved = person?.displayName.trim() ?? '';
    final name = resolved.isEmpty ? AppStrings.impactSomeone : resolved;
    final avatarUrl = AssetUrlResolver.resolve(person?.avatarKey);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16.s,
          backgroundColor: AppColors.neutral800,
          backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
          child: avatarUrl != null
              ? null
              : Text(
                  name.characters.first.toUpperCase(),
                  style: AppStyles.label(
                    13,
                    weight: AppStyles.bold,
                    color: AppColors.neutral400,
                  ),
                ),
        ),
        SizedBox(width: 10.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(14, weight: AppStyles.semiBold),
              ),
              SizedBox(height: 2.s),
              Text(
                impactAge(at),
                style: AppStyles.body(12, color: AppColors.neutral500),
              ),
            ],
          ),
        ),
        if (trailing case final pill?) ...[SizedBox(width: 8.s), pill],
      ],
    );
  }
}

/// "2 hours ago", the way every card on this screen writes it.
String impactAge(DateTime? at) {
  if (at == null) return '';
  final gap = DateTime.now().difference(at);
  if (gap.inMinutes < 1) return 'Just now';
  if (gap.inMinutes < 60) {
    return '${gap.inMinutes} ${_plural(gap.inMinutes, 'minute')} ago';
  }
  if (gap.inHours < 24) {
    return '${gap.inHours} ${_plural(gap.inHours, 'hour')} ago';
  }
  if (gap.inDays < 7) return '${gap.inDays} ${_plural(gap.inDays, 'day')} ago';
  final weeks = (gap.inDays / 7).floor();
  return '$weeks ${_plural(weeks, 'week')} ago';
}

String _plural(int n, String word) => n == 1 ? word : '${word}s';

/// A small state pill — "Not assigned", "Flagged comment", an impact tag.
class ImpactPill extends StatelessWidget {
  const ImpactPill({
    super.key,
    required this.label,
    required this.colour,
    this.background,
  });

  const ImpactPill.amber(String label, {Key? key})
    : this(key: key, label: label, colour: AppColors.brandPrimary);

  const ImpactPill.green(String label, {Key? key})
    : this(key: key, label: label, colour: AppColors.green500);

  const ImpactPill.red(String label, {Key? key})
    : this(key: key, label: label, colour: AppColors.destructive);

  final String label;
  final Color colour;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 5.s),
    decoration: BoxDecoration(
      color: background ?? colour.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999.s),
    ),
    child: Text(
      label,
      style: AppStyles.label(11, weight: AppStyles.semiBold, color: colour),
    ),
  );
}

/// The outlined action on a card — "Mark as prayed", "Approve & Share".
class ImpactAction extends StatelessWidget {
  const ImpactAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? tint;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colour = tint ?? AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 10.s),
        decoration: BoxDecoration(
          color: filled ? colour.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.s),
          border: filled
              ? null
              : Border.all(color: AppColors.neutral700, width: 1.2.s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon case final glyph?) ...[
              Icon(glyph, size: 16.s, color: colour),
              SizedBox(width: 7.s),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(
                  13,
                  weight: AppStyles.semiBold,
                  color: colour,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One prayer, as the design lays it out.
///
/// The button on the right is not one button in three states — it is a
/// different step each time. An open prayer is prayed for, a prayed one is
/// closed, and a closed one offers nothing but the overflow menu.
class PrayerRequestCard extends StatelessWidget {
  const PrayerRequestCard({
    super.key,
    required this.prayer,
    this.onAdvance,
    this.onMore,
  });

  final PrayerRequest prayer;

  /// Moves the prayer one step on — prayed for, then closed.
  final VoidCallback? onAdvance;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final assignee = prayer.assignee;
    return Padding(
      key: ValueKey('prayer-${prayer.id}'),
      padding: EdgeInsets.symmetric(vertical: 16.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImpactSender(
            person: prayer.requester,
            at: prayer.createdAt,
            trailing: assignee == null
                ? const ImpactPill.amber(AppStrings.prayerNotAssigned)
                : ImpactPill.green(AppStrings.prayerAssignedTo(_who(assignee))),
          ),
          SizedBox(height: 12.s),
          Text(
            prayer.body,
            style: AppStyles.body(
              14,
              color: AppColors.neutral200,
              lineHeight: 21 / 14,
            ),
          ),
          SizedBox(height: 14.s),
          Row(
            children: [
              Expanded(child: _source()),
              GestureDetector(
                key: ValueKey('prayer-more-${prayer.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.s),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 20.s,
                    color: AppColors.neutral400,
                  ),
                ),
              ),
              if (!prayer.isClosed)
                ImpactAction(
                  key: ValueKey('prayer-advance-${prayer.id}'),
                  label: prayer.isPrayedFor
                      ? AppStrings.prayerResolve
                      : AppStrings.prayerMarkPrayed,
                  icon: prayer.isPrayedFor
                      ? Icons.inventory_2_outlined
                      : Icons.check_circle_outline_rounded,
                  onTap: onAdvance,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Pastor Grace (editor)", or just the name when no role came back.
  static String _who(ImpactPerson person) => person.role == null
      ? person.displayName
      : '${person.displayName} (${person.role})';

  Widget _source() {
    final wall = prayer.fromWall;
    final title = prayer.contentRefTitle;
    // A title the gateway could not resolve is normal, not an error — the
    // content may be deleted, or belong to another creator. The line names
    // the kind of thing instead of going blank.
    final label = wall
        ? AppStrings.prayerFromWall
        : title != null
        ? AppStrings.prayerOnContent(title)
        : AppStrings.prayerFromType(prayer.contentRef?.targetType ?? '');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          wall ? Icons.shield_outlined : Icons.play_circle_outline_rounded,
          size: 15.s,
          color: wall ? AppColors.neutral500 : AppColors.brandPrimary,
        ),
        SizedBox(width: 6.s),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.label(
              12,
              weight: wall ? AppStyles.medium : AppStyles.semiBold,
              color: wall ? AppColors.neutral500 : AppColors.brandPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One testimony: waiting, shared, or turned down.
///
/// Pending offers "Approve & Share" and a red ✕; approved offers "Remove";
/// rejected offers "Restore" and nothing else.
class TestimonyCard extends StatelessWidget {
  const TestimonyCard({
    super.key,
    required this.testimony,
    this.onApprove,
    this.onReject,
  });

  final CreatorTestimony testimony;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final approved = testimony.isApproved;
    final rejected = testimony.isRejected;
    return Padding(
      key: ValueKey('testimony-${testimony.id}'),
      padding: EdgeInsets.symmetric(vertical: 16.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The gateway masks an anonymous submitter before this reaches the
          // card; nothing here is derived from the submitter id.
          ImpactSender(person: testimony.author, at: testimony.createdAt),
          SizedBox(height: 12.s),
          Text(
            testimony.body,
            style: AppStyles.body(
              14,
              color: AppColors.neutral200,
              lineHeight: 21 / 14,
            ),
          ),
          SizedBox(height: 14.s),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6.s,
                  runSpacing: 6.s,
                  children: [
                    for (final tag in testimony.impactTags)
                      ImpactPill.amber(testimonyImpactTagLabel(tag)),
                  ],
                ),
              ),
              SizedBox(width: 8.s),
              ImpactAction(
                key: ValueKey('testimony-approve-${testimony.id}'),
                label: switch ((approved, rejected)) {
                  (true, _) => AppStrings.testimonyRemove,
                  (_, true) => AppStrings.testimonyRestore,
                  _ => AppStrings.testimonyApprove,
                },
                icon: approved || rejected
                    ? null
                    : Icons.check_circle_outline_rounded,
                onTap: approved ? onReject : onApprove,
              ),
              // A story that was turned down is restored or left alone;
              // there is nothing further to turn down.
              if (!approved && !rejected) ...[
                SizedBox(width: 10.s),
                GestureDetector(
                  key: ValueKey('testimony-reject-${testimony.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onReject,
                  child: Container(
                    width: 30.s,
                    height: 30.s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.destructive,
                        width: 1.2.s,
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16.s,
                      color: AppColors.destructive,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One comment waiting on a decision.
///
/// The two buttons are the decisions this queue supports, which are not
/// quite the design's Hide/Flag pair: a flagged comment is kept public or
/// hidden, and a hidden one is restored. Keeping it public takes the row out
/// of the queue — that is the queue working, not the row going missing.
class ImpactCommentCard extends StatelessWidget {
  const ImpactCommentCard({
    super.key,
    required this.comment,
    this.onKeepPublic,
    this.onHide,
    this.onReport,
  });

  final ImpactComment comment;
  final VoidCallback? onKeepPublic;
  final VoidCallback? onHide;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final hidden = comment.isHidden;
    return Padding(
      key: ValueKey('comment-${comment.id}'),
      padding: EdgeInsets.symmetric(vertical: 16.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImpactSender(
            person: comment.author,
            at: comment.createdAt,
            trailing: hidden
                ? const ImpactPill.amber(AppStrings.commentHiddenPill)
                : const ImpactPill.red(AppStrings.commentFlaggedPill),
          ),
          // The design quotes the comment this one answers. The queue sends
          // `parentCommentId` and nothing else — no author, no excerpt — and
          // no route fetches one comment by id, so the row says it is a reply
          // rather than inventing the words it replies to. See OPEN_ISSUES.
          if (comment.isReply) ...[
            SizedBox(height: 10.s),
            Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 14.s,
                  color: AppColors.neutral500,
                ),
                SizedBox(width: 5.s),
                Text(
                  AppStrings.commentIsReply,
                  style: AppStyles.label(
                    12,
                    weight: AppStyles.medium,
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 10.s),
          Text(
            comment.body,
            style: AppStyles.body(
              14,
              color: AppColors.neutral200,
              lineHeight: 21 / 14,
            ),
          ),
          SizedBox(height: 10.s),
          _onContent(),
          SizedBox(height: 14.s),
          Row(
            children: [
              Expanded(
                child: ImpactAction(
                  key: ValueKey('comment-primary-${comment.id}'),
                  label: hidden
                      ? AppStrings.commentUnhide
                      : AppStrings.commentKeepPublic,
                  icon: hidden
                      ? Icons.visibility_outlined
                      : Icons.check_circle_outline_rounded,
                  filled: true,
                  tint: hidden ? AppColors.neutral300 : AppColors.green500,
                  onTap: onKeepPublic,
                ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: hidden
                    ? ImpactAction(
                        key: ValueKey('comment-report-${comment.id}'),
                        label: AppStrings.commentFlag,
                        icon: Icons.flag_outlined,
                        filled: true,
                        tint: AppColors.brandPrimary,
                        onTap: onReport,
                      )
                    : ImpactAction(
                        key: ValueKey('comment-hide-${comment.id}'),
                        label: AppStrings.commentHide,
                        icon: Icons.visibility_off_outlined,
                        filled: true,
                        tint: AppColors.neutral300,
                        onTap: onHide,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "on The Prodigal Returns", falling back to the kind of thing when the
  /// title could not be resolved. This is a label, never a grouping key —
  /// two pieces of content can share a title.
  Widget _onContent() {
    final title = comment.targetTitle;
    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                if (title != null)
                  TextSpan(
                    text: 'on ',
                    style: AppStyles.body(12, color: AppColors.neutral500),
                  ),
                TextSpan(
                  text: title ?? AppStrings.prayerFromType(comment.targetType),
                  style: AppStyles.label(
                    12,
                    weight: AppStyles.semiBold,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (comment.replyCount > 0) ...[
          SizedBox(width: 10.s),
          Text(
            AppStrings.impactReplyCount(comment.replyCount),
            style: AppStyles.body(12, color: AppColors.neutral500),
          ),
        ],
      ],
    );
  }
}

/// A line under the Comments tab saying what this queue is.
///
/// Without it, "Comments" reads as every comment on your content, and a busy
/// ministry seeing an empty queue will think the screen is broken.
class ImpactQueueNote extends StatelessWidget {
  const ImpactQueueNote({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(top: 12.s),
    padding: EdgeInsets.all(12.s),
    decoration: BoxDecoration(
      color: AppColors.neutral900,
      borderRadius: BorderRadius.circular(10.s),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 15.s,
          color: AppColors.neutral500,
        ),
        SizedBox(width: 9.s),
        Expanded(
          child: Text(
            AppStrings.commentQueueNote,
            style: AppStyles.body(
              12,
              color: AppColors.neutral400,
              lineHeight: 17 / 12,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Nothing has arrived yet.
///
/// The design draws praying hands in brand orange, bare — no disc behind
/// them — over one headline and a line saying what will land here. The glyph
/// is an icon rather than the 🙏 the frame uses, because no emoji face
/// renders reliably in this app (see the font notes in `CLAUDE.md`).
class ImpactEmpty extends StatelessWidget {
  const ImpactEmpty({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(32.s, 40.s, 32.s, 40.s),
    child: Column(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedHandPrayer,
          color: AppColors.brandPrimary,
          size: 56.s,
        ),
        SizedBox(height: 18.s),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppStyles.heading(20, lineHeight: 26 / 20),
        ),
        SizedBox(height: 8.s),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppStyles.body(
            13,
            color: AppColors.neutral400,
            lineHeight: 19 / 13,
          ),
        ),
      ],
    ),
  );
}
