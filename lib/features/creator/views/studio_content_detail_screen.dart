import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/new_article_screen.dart';
import 'package:test_app/features/creator/views/new_event_screen.dart';
import 'package:test_app/features/creator/views/new_media_screen.dart';
import 'package:test_app/features/creator/services/content_delete.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/features/discovery/views/media_detail_screen.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Opens the editor for [item], if this kind can be edited from a phone.
Future<bool> openContentEditor(
  BuildContext context,
  StudioContentItem item,
) async {
  if (!item.isEditableHere) return false;
  final route = switch (item.kind) {
    StudioContentKind.post => MaterialPageRoute<bool>(
      builder: (_) => NewArticleScreen(editPostId: item.id),
    ),
    StudioContentKind.event => MaterialPageRoute<bool>(
      builder: (_) => NewEventScreen(editEventId: item.id),
    ),
    StudioContentKind.video => MaterialPageRoute<bool>(
      builder: (_) =>
          NewMediaScreen(kind: MediaUploadKind.video, editMediaId: item.id),
    ),
    StudioContentKind.audio => MaterialPageRoute<bool>(
      builder: (_) =>
          NewMediaScreen(kind: MediaUploadKind.music, editMediaId: item.id),
    ),
    StudioContentKind.livestream => null,
  };
  if (route == null) return false;
  final saved = await Navigator.push<bool>(context, route);
  return saved ?? false;
}

/// How a row is removed. A test supplies its own.
typedef ContentDeleter =
    Future<ContentDeleteOutcome> Function(StudioContentItem item);

/// One piece of content: how it is doing, and the four things a creator can
/// do with it from a phone.
class StudioContentDetailScreen extends StatefulWidget {
  const StudioContentDetailScreen({super.key, required this.item, this.delete});

  final StudioContentItem item;

  /// Defaults to the real routes.
  final ContentDeleter? delete;

  @override
  State<StudioContentDetailScreen> createState() =>
      _StudioContentDetailScreenState();
}

class _StudioContentDetailScreenState extends State<StudioContentDetailScreen> {
  StudioContentItem get item => widget.item;

  /// A delete in flight. Every control is held while it is, because the one
  /// thing worse than a slow delete is two of them.
  bool _deleting = false;

  bool get _isEvent => item.kind == StudioContentKind.event;

  /// Whether this row has an update route the phone can call, and is in a
  /// state anyone is allowed to change.
  bool get _isEditable => item.isEditableHere;

  /// What the footer has to say, or nothing.
  String? get _footnote {
    if (!item.isEditableHere && item.kind != StudioContentKind.livestream) {
      return AppStrings.editMediaNotEditable;
    }
    return switch (item.kind) {
      StudioContentKind.post => AppStrings.contentPostEditNote,
      StudioContentKind.event => null,
      StudioContentKind.video ||
      StudioContentKind.audio => AppStrings.contentMediaEditNote,
      StudioContentKind.livestream => AppStrings.contentMediaEditWeb,
    };
  }

  Future<void> _edit() async {
    final saved = await openContentEditor(context, item);
    // Carry the "something changed" back to the list that pushed this, so
    // it reloads rather than showing the old title.
    if (saved && mounted) Navigator.pop(context, true);
  }

  /// Asks first, then removes. A delete that succeeds leaves the screen,
  /// because what it was showing no longer exists.
  Future<void> _confirmDelete() async {
    if (_deleting) return;
    if (!item.canDeleteHere) {
      _report(AppStrings.contentDeleteLive);
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.base2,
        title: Text(
          AppStrings.contentDeleteTitle,
          style: AppStyles.heading(18, letterSpacing: -0.4),
        ),
        content: Text(
          AppStrings.contentDeleteBody(item.title),
          style: AppStyles.body(13, color: AppColors.neutral300),
        ),
        actions: [
          TextButton(
            key: const ValueKey('delete-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              AppStrings.contentDeleteCancel,
              style: AppStyles.button(14, color: AppColors.neutral300),
            ),
          ),
          TextButton(
            key: const ValueKey('delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AppStrings.contentDeleteConfirm,
              style: AppStyles.button(14, color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _deleting = true);
    final outcome = await (widget.delete ?? ContentDelete.run)(item);
    if (!mounted) return;
    setState(() => _deleting = false);

    switch (outcome) {
      // Already gone counts as done: the row the creator wanted rid of is
      // not there, and the list behind this should stop showing it.
      case ContentDeleteOutcome.done:
      case ContentDeleteOutcome.gone:
        _report(
          outcome == ContentDeleteOutcome.done
              ? AppStrings.contentDeleted
              : AppStrings.contentDeleteGone,
        );
        Navigator.pop(context, true);
      case ContentDeleteOutcome.notAllowed:
        _report(AppStrings.contentDeleteNotAllowed);
      case ContentDeleteOutcome.network:
        _report(AppStrings.contentDeleteNetwork);
      case ContentDeleteOutcome.refused:
        _report(AppStrings.contentDeleteRefused);
    }
  }

  void _report(String message) {
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
  void _copyLink() {
    Clipboard.setData(const ClipboardData(text: ''));
    _report(AppStrings.contentNoPublicLink);
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
                      onTap: () => _report(AppStrings.contentAnalyticsPro),
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
                    onTap: () => _report(AppStrings.contentNoPublicLink),
                  ),
                  SizedBox(height: 12.s),
                  _OutlinedAction(
                    actionKey: const ValueKey('detail-copy-link'),
                    icon: HugeIcons.strokeRoundedLink02,
                    label: AppStrings.contentCopyLink,
                    onTap: () => _copyLink(),
                  ),
                  SizedBox(height: 12.s),
                  if (_isEditable)
                    _OutlinedAction(
                      actionKey: const ValueKey('detail-edit'),
                      icon: HugeIcons.strokeRoundedEdit02,
                      label: AppStrings.contentEdit,
                      onTap: _edit,
                    )
                  else
                    _OutlinedAction(
                      actionKey: const ValueKey('detail-manage-web'),
                      icon: HugeIcons.strokeRoundedLinkSquare01,
                      label: AppStrings.contentManageOnWeb,
                      onTap: () => _report(AppStrings.contentWebOnlyAction),
                    ),
                  // Last, and the only one drawn in the destructive colour:
                  // it is the one action on this screen that cannot be
                  // taken back.
                  SizedBox(height: 12.s),
                  _DestructiveAction(
                    actionKey: const ValueKey('detail-delete'),
                    label: AppStrings.contentDelete,
                    busy: _deleting,
                    enabled: item.canDeleteHere,
                    onTap: _confirmDelete,
                  ),
                  if (_footnote case final note?) ...[
                    SizedBox(height: 16.s),
                    Container(
                      padding: EdgeInsets.all(14.s),
                      decoration: BoxDecoration(
                        color: AppColors.fieldBg,
                        borderRadius: BorderRadius.circular(10.s),
                      ),
                      child: Text(
                        note,
                        style: AppStyles.body(
                          12,
                          color: AppColors.neutral400,
                          lineHeight: 17 / 12,
                        ),
                      ),
                    ),
                  ],
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

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MediaDetailScreen(
          item: WebFeedItem.fromJson({
            'entityType': 'media',
            'entityId': item.id,
            'title': item.title,
            'meta': {'mediaType': item.kind.name},
            'facets': {'mediaType': item.kind.name},
          }),
          source: AnalyticsSource.creatorProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('studio-content-hero'),
    behavior: HitTestBehavior.opaque,
    onTap: item.isPlayable ? () => _open(context) : null,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10.s),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.fieldBg),
            if (item.stillUrl case final url?)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (item.isPlayable)
              Center(
                child: Container(
                  width: 52.s,
                  height: 52.s,
                  decoration: BoxDecoration(
                    color: AppColors.overlayDark,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.textPrimary,
                    size: 30.s,
                  ),
                ),
              )
            else if (item.stillUrl == null)
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

/// The one control on the screen that cannot be undone.
class _DestructiveAction extends StatelessWidget {
  const _DestructiveAction({
    required this.actionKey,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.enabled = true,
  });

  final Key actionKey;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  /// False while a broadcast is on air. The control stays on screen and
  /// says why when tapped, rather than vanishing without explanation.
  final bool enabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: actionKey,
    behavior: HitTestBehavior.opaque,
    onTap: busy ? null : onTap,
    child: Container(
      height: 50.s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.s),
        border: Border.all(
          color: enabled ? AppColors.destructive : AppColors.neutral800,
        ),
      ),
      child: busy
          ? SizedBox(
              width: 18.s,
              height: 18.s,
              child: CircularProgressIndicator(
                strokeWidth: 2.s,
                color: AppColors.destructive,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  color: enabled ? AppColors.destructive : AppColors.neutral500,
                  size: 17.s,
                ),
                SizedBox(width: 10.s),
                Text(
                  label,
                  style: AppStyles.button(
                    14,
                    color: enabled
                        ? AppColors.destructive
                        : AppColors.neutral500,
                  ),
                ),
              ],
            ),
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
