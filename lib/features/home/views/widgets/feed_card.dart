import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum FeedCardKind {
  video,
  audio,
  live,
  event,
  channel,
  blog,
  post,
  devotional,
  series,
}

class FeedCardData {
  const FeedCardData({
    required this.id,
    required this.kind,
    required this.creatorName,
    required this.handle,
    required this.age,
    this.title,
    this.body,
    this.thumbnailUrl,
    this.avatarUrl,
    this.duration,
    this.verified = false,
    this.sponsored = false,
    this.likes = 0,
    this.saves = 0,
    this.comments = 0,
    this.views,
    this.viewCount = 0,
    this.liked = false,
    this.saved = false,
    this.following = false,
    this.subscribers = 0,
    this.category,
    this.eventStart,
    this.location,
    this.planLabel,
    this.subtitle,
  });

  final String id;
  final FeedCardKind kind;
  final String creatorName;
  final String handle;

  final String age;
  final String? title;
  final String? body;
  final String? thumbnailUrl;
  final String? avatarUrl;

  final String? duration;
  final bool verified;
  final bool sponsored;
  final int likes;
  final int saves;
  final int comments;
  final String? views;

  final int viewCount;
  final bool liked;
  final bool saved;

  final bool following;
  final int subscribers;

  final String? category;
  final DateTime? eventStart;
  final String? location;

  final String? planLabel;

  final String? subtitle;

  String viewsNoun(int n) => switch ((kind, n)) {
    (FeedCardKind.live, _) => 'Watching',
    (FeedCardKind.blog, 1) => 'Open',
    (FeedCardKind.blog, _) => 'Opens',
    (_, 1) => 'View',
    _ => 'Views',
  };
}

class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.data,
    this.onTap,
    this.onCreatorTap,
    this.onFollow,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onMore,
  });

  final FeedCardData data;
  final VoidCallback? onTap;
  final VoidCallback? onCreatorTap;
  final VoidCallback? onFollow;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.base1,
          border: Border(
            bottom: BorderSide(color: AppColors.neutral700, width: 1.5.s),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 20.s),
          child: data.kind == FeedCardKind.channel
              ? _ChannelBody(
                  data: data,
                  onFollow: onFollow,
                  onOpen: onTap,
                  onMore: onMore,
                )
              : _StandardBody(
                  data: data,
                  onCreatorTap: onCreatorTap,
                  onFollow: onFollow,
                  onLike: onLike,
                  onSave: onSave,
                  onComment: onComment,
                  onMore: onMore,
                  onOpen: onTap,
                ),
        ),
      ),
    );
  }
}

class _StandardBody extends StatelessWidget {
  const _StandardBody({
    required this.data,
    this.onCreatorTap,
    this.onFollow,
    this.onLike,
    this.onSave,
    this.onComment,
    this.onMore,
    this.onOpen,
  });

  final FeedCardData data;
  final VoidCallback? onCreatorTap;
  final VoidCallback? onFollow;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onMore;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreatorRow(
          data: data,
          onCreatorTap: onCreatorTap,
          onFollow: onFollow,
          onMore: onMore,
        ),
        SizedBox(height: 16.s),
        Container(
          padding: EdgeInsets.only(bottom: 10.s),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.neutral800)),
          ),
          child: switch (data.kind) {
            FeedCardKind.audio => _AudioStrip(data: data),
            FeedCardKind.event => _EventBody(data: data, onRsvp: onOpen),
            FeedCardKind.blog => _BlogBody(data: data, onOpen: onOpen),
            FeedCardKind.devotional => _DevotionalBody(
              data: data,
              onStart: onOpen,
            ),
            FeedCardKind.series => _MediaBlock(data: data),
            _ => _MediaAndTitle(data: data),
          },
        ),
        SizedBox(height: 12.s),
        _ActionRow(
          data: data,
          onLike: onLike,
          onSave: onSave,
          onComment: onComment,
        ),
      ],
    );
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({
    required this.data,
    this.onCreatorTap,
    this.onFollow,
    this.onMore,
  });

  final FeedCardData data;
  final VoidCallback? onCreatorTap;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(
          url: data.avatarUrl,
          verified: data.verified,
          ringColor: switch (data) {
            _ when data.kind == FeedCardKind.live => AppColors.red500,
            _ when data.following => AppColors.cyan400,
            _ => AppColors.purple400,
          },
          onTap: data.following ? null : onFollow,
        ),
        SizedBox(width: 10.s),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCreatorTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        data.creatorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.heading(13),
                      ),
                    ),
                    if (data.verified) ...[
                      SizedBox(width: 4.s),
                      DesignIcon(
                        AppAssets.iconFeedVerified,
                        width: 12.83.s,
                        height: 13.311.s,
                        box: 16,
                      ),
                    ],
                    if (data.kind == FeedCardKind.live) ...[
                      SizedBox(width: 4.s),
                      const _LivePill(),
                    ],
                  ],
                ),
                SizedBox(height: 2.s),
                _MetaRow(data: data),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.s),
        _MoreButton(onTap: onMore),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.data});

  final FeedCardData data;

  @override
  Widget build(BuildContext context) {
    final meta = AppStyles.body(
      12,
      color: AppColors.neutral400,
      lineHeight: 16 / 12,
    );
    return Row(
      children: [
        Flexible(
          child: Text(
            '@${data.handle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: meta,
          ),
        ),
        if (data.age.isNotEmpty) ...[
          SizedBox(width: 6.s),
          Text(
            '·',
            style: AppStyles.label(
              12,
              color: AppColors.neutral500,
              weight: AppStyles.bold,
              lineHeight: 16 / 12,
            ),
          ),
          SizedBox(width: 3.s),
          Text(data.age, style: meta),
        ],
        if (data.sponsored) ...[
          SizedBox(width: 6.s),
          DesignIcon(
            AppAssets.iconFeedLoudspeaker,
            width: 9.s,
            height: 9.286.s,
            box: 12,
          ),
          SizedBox(width: 2.s),
          Text(
            'Sponsored',
            style: AppStyles.heading(
              10,
              color: AppColors.brandPrimary,
              lineHeight: 16 / 10,
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    this.url,
    this.verified = false,
    this.onTap,
    this.size = 32,
    this.ringColor,
  });

  final String? url;
  final bool verified;
  final VoidCallback? onTap;
  final double size;

  /// Red while live, cyan once following, purple when still followable.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size + 8,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandPrimary,
                border: ringColor == null
                    ? null
                    : Border.all(color: ringColor!, width: 2.s),
                image: url == null || url!.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(url!),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            if (onTap != null)
              Positioned(
                top: size - 9,
                child: DesignIcon(
                  AppAssets.iconFeedPlusCircle,
                  width: 12.s,
                  height: 12.s,
                  box: 16,
                ),
              ),
          ],
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
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 11.s, vertical: 5.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(color: AppColors.neutral800, width: 1.5.s),
        ),
        child: DesignIcon(
          AppAssets.iconFeedMore,
          width: 15.833.s,
          height: 2.5.s,
          box: 20,
        ),
      ),
    );
  }
}

class _MediaBlock extends StatelessWidget {
  const _MediaBlock({required this.data});

  final FeedCardData data;

  static const _aspect = 338 / 195;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.s),
      child: AspectRatio(
        aspectRatio: _aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.neutral900,
              child: data.thumbnailUrl == null || data.thumbnailUrl!.isEmpty
                  ? null
                  : Image.network(
                      data.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
            if (data.duration case final duration?)
              Positioned(
                left: 9.s,
                bottom: 9.s,
                child: _Pill(label: duration),
              ),
            if (data.planLabel case final plan?)
              Positioned(
                left: 12.s,
                bottom: 12.s,
                child: Text(
                  plan,
                  style: AppStyles.label(
                    11,
                    color: AppColors.brandPrimary,
                    weight: AppStyles.bold,
                  ),
                ),
              ),
            if (data.sponsored && data.kind == FeedCardKind.series)
              Positioned(
                right: 12.s,
                bottom: 12.s,
                child: const _SponsoredTag(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  static const color = AppColors.brandSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 3.s),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.s),
      ),
      child: Text(
        label,
        style: AppStyles.label(
          8,
          color: AppColors.neutral100,
          weight: AppStyles.bold,
          lineHeight: 16 / 8,
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.109.s, vertical: 1.777.s),
      decoration: BoxDecoration(
        color: AppColors.livePillFill,
        borderRadius: BorderRadius.circular(10.663.s),
        border: Border.all(color: AppColors.red500, width: 1.185.s),
      ),
      child: Text(
        AppStrings.liveBadge,
        style: AppStyles.label(
          5.924,
          weight: AppStyles.bold,
          lineHeight: 9.478 / 5.924,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.data,
    this.onLike,
    this.onSave,
    this.onComment,
  });

  final FeedCardData data;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    final live = data.kind == FeedCardKind.live;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ActionButton(
          asset: AppAssets.iconFeedHeart,
          width: 14.667.s,
          height: 13.334.s,
          count: data.likes,
          active: data.liked,
          onTap: onLike,
        ),
        SizedBox(width: 20.s),
        _ActionButton(
          asset: AppAssets.iconFeedBookmark,
          width: 12.667.s,
          height: 14.663.s,
          count: data.saves,
          active: data.saved,
          onTap: onSave,
        ),
        // The design's post card carries no comment action.
        if (data.kind != FeedCardKind.post) ...[
          SizedBox(width: 20.s),
          _ActionButton(
            asset: AppAssets.iconFeedChat,
            width: 13.333.s,
            height: 13.333.s,
            count: data.comments,
            onTap: onComment,
          ),
        ],
        const Spacer(),
        if (data.views case final views?) ...[
          Text(
            '$views ${data.viewsNoun(data.viewCount)}',
            style: live
                ? AppStyles.label(
                    12,
                    color: AppColors.neutral300,
                    weight: AppStyles.bold,
                    lineHeight: 16 / 12,
                  )
                : AppStyles.label(
                    10,
                    weight: AppStyles.bold,
                    lineHeight: 16 / 10,
                  ),
          ),
          SizedBox(width: 4.s),
          if (live)
            DesignIcon(
              AppAssets.iconFeedEye,
              width: 13.885.s,
              height: 9.s,
              box: 16,
            )
          else
            DesignIcon(
              AppAssets.iconFeedUsers,
              width: 12.926.s,
              height: 12.s,
              box: 16,
            ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.asset,
    required this.width,
    required this.height,
    required this.count,
    this.active = false,
    this.onTap,
  });

  final String asset;
  final double width;
  final double height;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignIcon(
            asset,
            width: width,
            height: height,
            box: 16,
            color: active ? AppColors.brandPrimary : null,
          ),
          SizedBox(width: 4.s),
          Text(
            formatCount(count),
            style: AppStyles.label(
              10,
              color: active ? AppColors.brandPrimary : AppColors.neutral400,
              weight: AppStyles.bold,
              lineHeight: 16 / 10,
            ),
          ),
        ],
      ),
    );
  }
}

String relativeAge(DateTime? at) {
  if (at == null) return '';
  final d = DateTime.now().toUtc().difference(at.toUtc());
  if (d.isNegative) return '';
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 365) return '${(d.inDays / 7).floor()}w';
  return '${(d.inDays / 365).floor()}y';
}

String formatCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final k = value / 1000;
    return '${_trim(k)}K';
  }
  return '${_trim(value / 1000000)}M';
}

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

class _MediaAndTitle extends StatelessWidget {
  const _MediaAndTitle({required this.data});

  final FeedCardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.kind != FeedCardKind.post) ...[
          _MediaBlock(data: data),
          SizedBox(height: 16.s),
        ],
        if (data.kind == FeedCardKind.post)
          // A post is body-only, set in the headline face.
          if (data.body ?? data.title case final text?)
            _Headline(text)
          else ...[
            if (data.title case final title?) _Headline(title),
            if (data.body case final body?) ...[
              if (data.title != null) SizedBox(height: 6.s),
              _Excerpt(body),
            ],
          ],
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppStyles.heading(14, lineHeight: 24 / 14, letterSpacing: -0.4),
  );
}

class _Excerpt extends StatelessWidget {
  const _Excerpt(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppStyles.body(13, color: AppColors.neutral200, lineHeight: 20 / 13),
  );
}

class _AudioStrip extends StatelessWidget {
  const _AudioStrip({required this.data});

  final FeedCardData data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.s),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.neutral900,
              child: data.thumbnailUrl == null || data.thumbnailUrl!.isEmpty
                  ? null
                  : Image.network(
                      data.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xE60D0D0D), Color(0x800D0D0D)],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12.s),
            child: Row(
              children: [
                Container(
                  width: 64.s,
                  height: 64.s,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.s),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF64618E), Color(0xFF2A2754)],
                    ),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: AppColors.textPrimary,
                    size: 30.s,
                  ),
                ),
                SizedBox(width: 12.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (data.title case final title?)
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyles.heading(14, lineHeight: 20 / 14),
                        ),
                      SizedBox(height: 8.s),
                      const _Waveform(),
                      if (data.duration case final duration?) ...[
                        SizedBox(height: 6.s),
                        Text(
                          duration,
                          style: AppStyles.label(
                            10,
                            color: AppColors.neutral400,
                            weight: AppStyles.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 10.s),
                Container(
                  width: 40.s,
                  height: 40.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.base1.withValues(alpha: 0.6),
                    border: Border.all(color: AppColors.neutral700),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.textPrimary,
                    size: 22.s,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform();

  static const _bars = <double>[
    6,
    12,
    18,
    10,
    22,
    14,
    8,
    20,
    16,
    24,
    12,
    18,
    9,
    15,
    21,
    11,
    17,
    7,
    13,
    19,
    10,
    16,
    22,
    8,
    14,
    20,
    12,
    18,
    6,
    15,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24.s,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in _bars) ...[
            Container(
              width: 2.5.s,
              height: h,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(2.s),
              ),
            ),
            SizedBox(width: 2.s),
          ],
        ],
      ),
    );
  }
}

class _EventBody extends StatelessWidget {
  const _EventBody({required this.data, this.onRsvp});

  final FeedCardData data;
  final VoidCallback? onRsvp;

  @override
  Widget build(BuildContext context) {
    final start = data.eventStart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaBlock(data: data),
        SizedBox(height: 16.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (start != null) ...[
              _DateBlock(date: start),
              SizedBox(width: 12.s),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.title case final title?) _Headline(title),
                  if (data.location != null || start != null) ...[
                    SizedBox(height: 4.s),
                    _VenueRow(location: data.location, start: start),
                  ],
                ],
              ),
            ),
            SizedBox(width: 10.s),
            _OutlineButton(label: AppStrings.rsvp, onTap: onRsvp),
          ],
        ),
      ],
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});

  final DateTime date;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${date.day}',
          style: AppStyles.heading(20, color: AppColors.brandPrimary),
        ),
        Text(
          _months[date.month - 1],
          style: AppStyles.label(
            10,
            color: AppColors.brandPrimary,
            weight: AppStyles.bold,
          ),
        ),
      ],
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({this.location, this.start});

  final String? location;
  final DateTime? start;

  @override
  Widget build(BuildContext context) {
    final style = AppStyles.body(
      12,
      color: AppColors.neutral400,
      lineHeight: 16 / 12,
    );
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 14.s,
          color: AppColors.neutral400,
        ),
        SizedBox(width: 4.s),
        Flexible(
          child: Text(
            [
              if (location != null && location!.isNotEmpty) location!,
              if (start != null) _time(start!),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  static String _time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute${d.hour < 12 ? 'am' : 'pm'}';
  }
}

class _BlogBody extends StatelessWidget {
  const _BlogBody({required this.data, this.onOpen});

  final FeedCardData data;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaBlock(data: data),
        SizedBox(height: 16.s),
        if (data.title case final title?) _Headline(title),
        if (data.body case final body?) ...[
          SizedBox(height: 6.s),
          _Excerpt(body),
        ],
        SizedBox(height: 14.s),
        Align(
          alignment: Alignment.centerLeft,
          child: _OutlineButton(label: AppStrings.readMore, onTap: onOpen),
        ),
      ],
    );
  }
}

class _ChannelBody extends StatelessWidget {
  const _ChannelBody({
    required this.data,
    this.onFollow,
    this.onOpen,
    this.onMore,
  });

  final FeedCardData data;
  final VoidCallback? onFollow;
  final VoidCallback? onOpen;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (data.sponsored) const _SponsoredTag(),
            const Spacer(),
            _MoreButton(onTap: onMore),
          ],
        ),
        SizedBox(height: 14.s),
        _Avatar(
          url: data.avatarUrl,
          verified: data.verified,
          size: 48.s,
          onTap: data.following ? null : onFollow,
        ),
        SizedBox(height: 12.s),
        Row(
          children: [
            Flexible(
              child: Text(
                data.creatorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.heading(17, letterSpacing: -0.4),
              ),
            ),
            if (data.verified) ...[
              SizedBox(width: 6.s),
              DesignIcon(
                AppAssets.iconFeedVerified,
                width: 12.83.s,
                height: 13.311.s,
                box: 18,
              ),
            ],
          ],
        ),
        SizedBox(height: 4.s),
        Text(
          [
            '@${data.handle}',
            if (data.category != null && data.category!.isNotEmpty)
              data.category!,
            if (data.subscribers > 0)
              '${formatCount(data.subscribers)} Subscribers',
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.body(
            12,
            color: AppColors.neutral400,
            lineHeight: 16 / 12,
          ),
        ),
        if (data.body case final body?) ...[
          SizedBox(height: 10.s),
          _Excerpt(body),
        ],
        SizedBox(height: 16.s),
        Row(
          children: [
            Expanded(
              child: _OutlineButton(
                label: data.following
                    ? AppStrings.following
                    : AppStrings.follow,
                onTap: onFollow,
                expand: true,
              ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: _OutlineButton(
                label: AppStrings.viewChannel,
                onTap: onOpen,
                expand: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SponsoredTag extends StatelessWidget {
  const _SponsoredTag();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignIcon(
          AppAssets.iconFeedLoudspeaker,
          width: 9.s,
          height: 9.286.s,
          box: 12,
        ),
        SizedBox(width: 2.s),
        Text(
          AppStrings.sponsored,
          style: AppStyles.heading(
            10,
            color: AppColors.brandPrimary,
            lineHeight: 16 / 10,
          ),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, this.onTap, this.expand = false});

  final String label;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 40.s,
        padding: EdgeInsets.symmetric(horizontal: 20.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.s),
          border: Border.all(color: AppColors.neutral700, width: 1.5.s),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppStyles.label(13, weight: AppStyles.bold)),
          ],
        ),
      ),
    );
  }
}

class _DevotionalBody extends StatelessWidget {
  const _DevotionalBody({required this.data, this.onStart});

  final FeedCardData data;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaBlock(data: data),
        SizedBox(height: 16.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.title case final title?) _Headline(title),
                  if (data.subtitle case final subtitle?) ...[
                    SizedBox(height: 4.s),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.body(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 10.s),
            _OutlineButton(label: AppStrings.startDevotion, onTap: onStart),
          ],
        ),
      ],
    );
  }
}
