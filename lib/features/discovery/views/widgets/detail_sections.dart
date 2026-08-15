import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The anatomy shared by every content-detail screen in the Contents Details
/// section — video, audio, blog, post, devotional and live all stack the same
/// title / creator / actions / description / comments blocks under a different
/// hero. Kept in one place so the six screens cannot drift apart.

const _hairline = AppColors.neutral800;

class DetailDivider extends StatelessWidget {
  const DetailDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1.s, color: _hairline);
}

/// Title plus the "12.9K Views · June 12, 2026" line beneath it.
class DetailTitleBlock extends StatelessWidget {
  const DetailTitleBlock({
    super.key,
    required this.title,
    this.viewsLabel,
    this.dateLabel,
  });

  final String title;
  final String? viewsLabel;
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    final meta = [?viewsLabel, ?dateLabel];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AppStyles.heading(18, lineHeight: 28 / 18)),
        if (meta.isNotEmpty) ...[
          SizedBox(height: 4.s),
          Text(
            meta.join('  ·  '),
            style: AppStyles.label(
              12,
              weight: AppStyles.bold,
              color: AppColors.neutral500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Avatar ring colour follows creator type — purple for organisations (with the
/// add badge), cyan for individuals.
class DetailAvatar extends StatelessWidget {
  const DetailAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.isOrganization = false,
    this.size = 32,
  });

  final String name;
  final String? avatarUrl;
  final bool isOrganization;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ring = isOrganization ? AppColors.purple400 : AppColors.cyan400;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final avatar = Container(
      width: size.s,
      height: size.s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandPrimary,
        border: Border.all(color: ring, width: 2.s),
        image: avatarUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              ),
      ),
      child: avatarUrl != null
          ? null
          : Center(child: Text(initial, style: AppStyles.heading(size * 0.44))),
    );
    if (!isOrganization) return avatar;
    return SizedBox(
      width: size.s,
      height: (size + 6).s,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          avatar,
          Positioned(
            bottom: 0,
            child: DesignIcon(
              AppAssets.iconFeedPlusCircle,
              width: 12.s,
              height: 12.s,
            ),
          ),
        ],
      ),
    );
  }
}

/// Creator identity with the Follow and overflow buttons.
class DetailCreatorRow extends StatelessWidget {
  const DetailCreatorRow({
    super.key,
    required this.name,
    required this.subscribersLabel,
    this.avatarUrl,
    this.verified = false,
    this.isOrganization = false,
    this.following = false,
    this.busy = false,
    this.onTap,
    this.onFollow,
    this.onMore,
  });

  final String name;
  final String subscribersLabel;
  final String? avatarUrl;
  final bool verified;
  final bool isOrganization;
  final bool following;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              children: [
                DetailAvatar(
                  name: name,
                  avatarUrl: avatarUrl,
                  isOrganization: isOrganization,
                ),
                SizedBox(width: 10.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyles.heading(13),
                            ),
                          ),
                          if (verified) ...[
                            SizedBox(width: 4.s),
                            DesignIcon(
                              AppAssets.iconFeedVerified,
                              width: 16.s,
                              height: 16.s,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2.s),
                      Row(
                        children: [
                          DesignIcon(
                            AppAssets.iconFeedUsers,
                            width: 16.s,
                            height: 16.s,
                          ),
                          SizedBox(width: 4.s),
                          Flexible(
                            child: Text(
                              subscribersLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyles.label(
                                12,
                                weight: AppStyles.bold,
                                color: AppColors.neutral500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 10.s),
        _FollowButton(following: following, busy: busy, onTap: onFollow),
        SizedBox(width: 10.s),
        _MoreButton(onTap: onMore),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.busy,
    required this.onTap,
  });

  final bool following;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 11.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(color: AppColors.neutral700, width: 1.5.s),
          color: following
              ? AppColors.neutral700.withValues(alpha: 0.35)
              : null,
        ),
        child: busy
            ? SizedBox(
                width: 13.s,
                height: 13.s,
                child: const CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: AppColors.neutral300,
                ),
              )
            : Text(
                following ? AppStrings.followingLabel : AppStrings.follow,
                style: AppStyles.button(13),
              ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 11.s, vertical: 5.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(color: _hairline, width: 1.5.s),
        ),
        child: SizedBox(
          width: 20.s,
          height: 20.s,
          child: Center(
            child: DesignIcon(AppAssets.iconFeedMore, width: 16.s, height: 4.s),
          ),
        ),
      ),
    );
  }
}

/// Like / save / share, split evenly across the row.
class DetailImpactActions extends StatelessWidget {
  const DetailImpactActions({
    super.key,
    required this.likes,
    required this.saves,
    this.liked = false,
    this.saved = false,
    this.onLike,
    this.onSave,
    this.onShare,
  });

  final String likes;
  final String saves;
  final bool liked;
  final bool saved;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 13.s),
      child: Row(
        children: [
          _Action(
            icon: AppAssets.iconFeedHeart,
            size: 20,
            label: likes,
            active: liked,
            onTap: onLike,
          ),
          _Action(
            icon: AppAssets.iconFeedBookmark,
            size: 20,
            label: saves,
            active: saved,
            onTap: onSave,
          ),
          _Action(
            icon: AppAssets.iconShare,
            size: 16,
            label: AppStrings.share,
            labelColor: AppColors.neutral50,
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.size,
    required this.label,
    this.active = false,
    this.labelColor,
    this.onTap,
  });

  final String icon;
  final double size;
  final String label;
  final bool active;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DesignIcon(
              icon,
              width: size.s,
              height: size.s,
              color: active ? AppColors.brandPrimary : null,
            ),
            SizedBox(width: 4.s),
            Text(
              label,
              style: AppStyles.label(
                12,
                weight: AppStyles.bold,
                color: labelColor ?? AppColors.neutral400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible description panel.
class DetailDescriptionCard extends StatefulWidget {
  const DetailDescriptionCard({
    super.key,
    required this.body,
    this.title = AppStrings.descriptionLabel,
  });

  final String body;
  final String title;

  @override
  State<DetailDescriptionCard> createState() => _DetailDescriptionCardState();
}

class _DetailDescriptionCardState extends State<DetailDescriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(8.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: AppStyles.heading(13)),
          SizedBox(height: 6.s),
          Text(
            widget.body,
            maxLines: _expanded ? null : 4,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: AppStyles.label(
              12,
              weight: AppStyles.bold,
              color: AppColors.neutral400,
              lineHeight: 16 / 12,
            ),
          ),
          SizedBox(height: 6.s),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? AppStrings.showLess : AppStrings.showMore,
              style: AppStyles.heading(11),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Comments · 86" header that opens the full thread, plus a one-line preview
/// of the top comment.
class DetailCommentsPreview extends StatelessWidget {
  const DetailCommentsPreview({
    super.key,
    required this.count,
    this.topComment,
    this.topCommentAuthor,
    this.onOpen,
  });

  final int count;
  final String? topComment;
  final String? topCommentAuthor;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${AppStrings.comments} · $count',
                  style: AppStyles.label(14, weight: AppStyles.bold),
                ),
              ),
              Transform.rotate(
                angle: -1.5708,
                child: DesignIcon(
                  AppAssets.iconChevronDown,
                  width: 12.s,
                  height: 8.s,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (topComment != null) ...[
          SizedBox(height: 18.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailAvatar(name: topCommentAuthor ?? '?', size: 32),
              SizedBox(width: 12.s),
              Expanded(
                child: Text(
                  topComment!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.body(12, lineHeight: 16 / 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Up next" heading above the suggestion list.
class DetailSectionHeading extends StatelessWidget {
  const DetailSectionHeading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AppStyles.label(14, weight: AppStyles.bold, lineHeight: 20 / 14),
  );
}
