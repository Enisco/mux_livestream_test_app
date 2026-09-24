import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// One piece of content: how it is doing, and the three things a creator can
/// do with it from a phone.
///
/// Four kinds share this screen because they differ only in wording — views
/// or plays or reads, a runtime or a read time — and in the Going card an
/// event adds. Editing is not among them: title, description, visibility and
/// series are the web studio's job, which the footer says outright.
///
/// **No deltas.** The design shows "+18%" beside each figure. Those come from
/// `POST /v1/analytics/media/breakdown`, which answers
/// `403 Advanced analytics requires the Pro plan or higher` — so a Free
/// creator has none, and the response shape could not be read to build for
/// the Pro case. The lifetime totals on the row are shown instead.
class StudioContentDetailScreen extends StatelessWidget {
  const StudioContentDetailScreen({super.key, required this.item});

  final StudioContentItem item;

  bool get _isEvent => item.kind == StudioContentKind.event;

  void _report(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Nothing in the API returns a public URL for a piece of content — only
  /// the creator's handle — so there is no link to put on the clipboard yet.
  /// See OPEN_ISSUES.
  void _copyLink(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: ''));
    _report(context, AppStrings.contentNoPublicLink);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 8.s, 20.s, 0),
              child: CreatorFlowHeader(title: _kindTitle),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 40.s),
                children: [
                  if (_isEvent)
                    _EventHead(item: item)
                  else ...[
                    _Hero(item: item),
                    SizedBox(height: 16.s),
                    Text(
                      item.title,
                      style: AppStyles.heading(22, letterSpacing: -0.6),
                    ),
                    SizedBox(height: 6.s),
                    Text(
                      _metaLine,
                      style: AppStyles.body(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ],
                  SizedBox(height: 22.s),
                  Text(
                    AppStrings.contentPerformance,
                    style: AppStyles.label(
                      12,
                      weight: AppStyles.bold,
                      color: AppColors.neutral500,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(height: 10.s),
                  if (_isEvent) ...[
                    _GoingCard(item: item),
                    SizedBox(height: 10.s),
                  ],
                  _stats(),
                  SizedBox(height: 10.s),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      key: const ValueKey('detail-full-analytics'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          _report(context, AppStrings.contentAnalyticsPro),
                      child: Text(
                        AppStrings.studioFullAnalytics,
                        style: AppStyles.label(
                          12,
                          weight: AppStyles.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 22.s),
                  _PrimaryAction(
                    label: AppStrings.contentShare,
                    onTap: () =>
                        _report(context, AppStrings.contentNoPublicLink),
                  ),
                  SizedBox(height: 12.s),
                  _OutlinedAction(
                    actionKey: const ValueKey('detail-copy-link'),
                    icon: HugeIcons.strokeRoundedLink02,
                    label: AppStrings.contentCopyLink,
                    onTap: () => _copyLink(context),
                  ),
                  SizedBox(height: 12.s),
                  _OutlinedAction(
                    actionKey: const ValueKey('detail-manage-web'),
                    icon: HugeIcons.strokeRoundedLinkSquare01,
                    label: item.kind == StudioContentKind.video
                        ? AppStrings.contentEditOnWeb
                        : AppStrings.contentManageOnWeb,
                    onTap: () =>
                        _report(context, AppStrings.contentWebOnlyAction),
                  ),
                  SizedBox(height: 16.s),
                  Container(
                    padding: EdgeInsets.all(14.s),
                    decoration: BoxDecoration(
                      color: AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(10.s),
                    ),
                    child: Text(
                      AppStrings.contentWebStudioNote,
                      style: AppStyles.body(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 17 / 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _kindTitle => switch (item.kind) {
    StudioContentKind.video => AppStrings.contentKindVideo,
    // Broadcast, not uploaded — the studio never calls one the other.
    StudioContentKind.livestream => AppStrings.contentKindLivestream,
    StudioContentKind.audio => AppStrings.contentKindAudio,
    StudioContentKind.post => AppStrings.contentKindPost,
    StudioContentKind.event => AppStrings.contentKindEvent,
  };

  /// "Published Jun 6 · Preaching".
  String get _metaLine => [
    if (item.publishedAt case final at?)
      '${AppStrings.contentPublished} ${_shortDate(at)}'
    else if (_stateWord.isNotEmpty)
      _stateWord
    // An unscheduled livestream session has neither a publish date nor a
    // state word; who can see it is the one thing worth saying.
    else
      ?_visibilityWord,
    for (final slug in item.categorySlugs.take(1)) _prettySlug(slug),
  ].join(' · ');

  String? get _visibilityWord => switch (item.visibility) {
    'public' => AppStrings.contentPublic,
    'unlisted' => AppStrings.contentUnlisted,
    'private' => AppStrings.contentPrivate,
    _ => null,
  };

  String get _stateWord => switch (item.state) {
    StudioContentState.draft => AppStrings.contentDraft,
    StudioContentState.processing => AppStrings.contentProcessing,
    StudioContentState.scheduled => AppStrings.contentScheduled,
    StudioContentState.live => AppStrings.contentLiveNow,
    StudioContentState.replay => AppStrings.contentReplay,
    StudioContentState.ended => AppStrings.contentEnded,
    StudioContentState.failed => AppStrings.contentFailed,
    StudioContentState.inReview => AppStrings.contentInReview,
    StudioContentState.blocked => AppStrings.contentBlocked,
    StudioContentState.archived => AppStrings.contentArchived,
    StudioContentState.cancelled => AppStrings.contentCancelled,
    _ => '',
  };

  Widget _stats() => Row(
    children: [
      if (!_isEvent) ...[
        Expanded(
          child: _StatCard(
            label: switch (item.kind) {
              StudioContentKind.audio => AppStrings.contentPlaysLabel,
              StudioContentKind.post => AppStrings.contentReadsLabel,
              StudioContentKind.livestream =>
                AppStrings.contentWatchedLiveLabel,
              _ => AppStrings.studioViews,
            },
            value: formatCount(item.views),
          ),
        ),
        SizedBox(width: 10.s),
      ],
      Expanded(
        child: _StatCard(
          label: AppStrings.contentLikes,
          value: formatCount(item.likes),
        ),
      ),
      SizedBox(width: 10.s),
      Expanded(
        child: _StatCard(
          label: AppStrings.contentComments,
          value: formatCount(item.comments),
        ),
      ),
    ],
  );

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _shortDate(DateTime at) => '${_months[at.month - 1]} ${at.day}';

  /// Only slugs come back on these rows, so "bible-study" is shown as
  /// "Bible study" rather than looked up.
  static String _prettySlug(String slug) {
    if (slug.isEmpty) return slug;
    final words = slug.replaceAll('-', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }
}

/// The still, with what kind it is and how long it runs.
class _Hero extends StatelessWidget {
  const _Hero({required this.item});

  final StudioContentItem item;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10.s),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.fieldBg),
          Center(
            child: Text(
              AppStrings.contentViewContent,
              style: AppStyles.label(
                12,
                color: AppColors.neutral300,
                lineHeight: 16 / 12,
              ),
            ),
          ),
          Positioned(
            left: 10.s,
            top: 10.s,
            child: HugeIcon(
              icon: switch (item.kind) {
                StudioContentKind.audio => HugeIcons.strokeRoundedHeadphones,
                StudioContentKind.post => HugeIcons.strokeRoundedBookOpen01,
                StudioContentKind.livestream =>
                  HugeIcons.strokeRoundedLiveStreaming01,
                _ => HugeIcons.strokeRoundedVideo01,
              },
              color: AppColors.brandPrimary,
              size: 18.s,
            ),
          ),
          if (_badge case final label?)
            Positioned(
              right: 10.s,
              bottom: 8.s,
              child: Text(
                label,
                style: AppStyles.label(
                  11,
                  weight: AppStyles.bold,
                  color: AppColors.neutral100,
                  lineHeight: 14 / 11,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  String? get _badge {
    final seconds = item.durationSeconds;
    if (seconds == null || seconds <= 0) return null;
    final d = Duration(seconds: seconds);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$mm:$ss' : '$mm:$ss';
  }
}

/// An event leads with when and where rather than with a picture.
class _EventHead extends StatelessWidget {
  const _EventHead({required this.item});

  final StudioContentItem item;

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
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final at = item.startsAt;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (at != null) ...[
          Container(
            width: 52.s,
            padding: EdgeInsets.symmetric(vertical: 8.s),
            decoration: BoxDecoration(
              color: AppColors.fieldBg,
              borderRadius: BorderRadius.circular(8.s),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  at.day.toString().padLeft(2, '0'),
                  style: AppStyles.heading(
                    18,
                    color: AppColors.brandPrimary,
                    lineHeight: 22 / 18,
                  ),
                ),
                Text(
                  _months[at.month - 1],
                  style: AppStyles.label(
                    11,
                    color: AppColors.brandPrimary,
                    lineHeight: 14 / 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.s),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                style: AppStyles.heading(20, letterSpacing: -0.5),
              ),
              SizedBox(height: 6.s),
              Text(
                _when(at),
                style: AppStyles.body(
                  12,
                  color: AppColors.neutral400,
                  lineHeight: 17 / 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _when(DateTime? at) {
    final parts = <String>[
      if (at != null) '${_days[at.weekday - 1]} ${_clock(at)}',
      if (item.venue.isNotEmpty) item.venue,
    ];
    return parts.join(' · ');
  }

  static String _clock(DateTime at) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// How many said they are coming, against what the room holds.
class _GoingCard extends StatelessWidget {
  const _GoingCard({required this.item});

  final StudioContentItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(14.s),
    decoration: BoxDecoration(
      color: AppColors.fieldBg,
      borderRadius: BorderRadius.circular(10.s),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.contentGoingLabel,
          style: AppStyles.label(
            12,
            color: AppColors.neutral400,
            lineHeight: 16 / 12,
          ),
        ),
        SizedBox(height: 6.s),
        Text(
          formatCount(item.goingCount),
          style: AppStyles.heading(24, letterSpacing: -0.6),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(12.s),
    decoration: BoxDecoration(
      color: AppColors.fieldBg,
      borderRadius: BorderRadius.circular(10.s),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.label(
            12,
            color: AppColors.neutral400,
            lineHeight: 16 / 12,
          ),
        ),
        SizedBox(height: 8.s),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.heading(20, letterSpacing: -0.6),
        ),
      ],
    ),
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('detail-share'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 50.s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppStyles.primaryButtonGradient,
        borderRadius: BorderRadius.circular(999.s),
      ),
      child: Text(label, style: AppStyles.button(14)),
    ),
  );
}

class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: actionKey,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 50.s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(10.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: AppColors.textPrimary, size: 17.s),
          SizedBox(width: 10.s),
          Text(label, style: AppStyles.button(14)),
        ],
      ),
    ),
  );
}
