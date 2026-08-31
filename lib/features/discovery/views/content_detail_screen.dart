import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'dart:async';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/discovery/views/media_detail_screen.dart';
import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/discovery/views/widgets/markdown_body.dart';
import 'package:test_app/features/engagement/data/engagement_store.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/engagement/views/comments_sheet.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount, relativeAge;
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/models/discovery_models/content_detail.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/shared/components/auth_sheet.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Opens the right detail screen for a feed or library row.
///
/// The media aggregate only knows media: asking it for a post, devotional or
/// event returns 404, which every non-media row used to do.
void openContentDetail(
  BuildContext context,
  WebFeedItem item, {
  String source = AnalyticsSource.unknown,
}) {
  final builder = switch (item.entityType) {
    'post' => (BuildContext _) => ContentDetailScreen(
      item: item,
      kind: ContentDetailKind.post,
      source: source,
    ),
    'devotional_series' => (BuildContext _) => ContentDetailScreen(
      item: item,
      kind: ContentDetailKind.devotional,
      source: source,
    ),
    'event' => (BuildContext _) => ContentDetailScreen(
      item: item,
      kind: ContentDetailKind.event,
      source: source,
    ),
    // A devotional entry belongs to its series; open the series.
    'devotional_entry' => (BuildContext _) => ContentDetailScreen(
      item: item,
      kind: ContentDetailKind.devotional,
      source: source,
      overrideId: item.meta.seriesId,
    ),
    _ => (BuildContext _) => MediaDetailScreen(item: item, source: source),
  };
  Navigator.push(context, MaterialPageRoute(builder: builder));
}

enum ContentDetailKind { post, devotional, event }

/// Detail for the non-media content types. They share the anatomy the design
/// repeats across the Contents Details section — title, creator, actions,
/// description — under a type-specific body.
class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({
    super.key,
    required this.item,
    required this.kind,
    this.overrideId,
    this.source = AnalyticsSource.unknown,
  });

  final WebFeedItem item;
  final ContentDetailKind kind;

  /// Where the reader came from, carried into this page's beacons.
  final String source;

  /// A devotional entry opens its parent series.
  final String? overrideId;

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  final _repo = GetIt.instance<DiscoveryRepo>();
  final _engagement = GetIt.instance<EngagementRepo>();

  CreatorProfile? _creator;
  ContentPost? _post;
  DevotionalSeriesDetail? _devotional;
  EventDetail? _event;

  bool _loading = true;
  bool _failed = false;

  final _store = GetIt.instance<EngagementStore>();

  /// What the payload said, before the store has anything newer.
  EngagementState _baseline = const EngagementState();

  String get _id => widget.overrideId ?? widget.item.entityId;

  bool _reported = false;
  bool _authed = false;

  /// Mirrors `viewerProgress.completedEntryIds`, updated as days are marked.
  Set<String> _completedEntryIds = const {};
  String? _markingEntryId;

  /// The interaction API names these differently from the feed's entityType.
  String get _targetType => switch (widget.kind) {
    ContentDetailKind.post => 'post',
    ContentDetailKind.devotional => 'devotional',
    ContentDetailKind.event => 'event',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _authed = await GetIt.instance<TokenStorageService>().hasSession;
    if (mounted) await _load();
  }

  /// Marks a devotional day read.
  ///
  /// The API records completion but has no route to undo it, so an already-read
  /// day is left alone rather than pretending it can be cleared.
  Future<void> _markDayRead(
    DevotionalSeriesDetail series,
    DevotionalEntry entry,
  ) async {
    if (_markingEntryId != null || _completedEntryIds.contains(entry.id)) {
      return;
    }
    setState(() => _markingEntryId = entry.id);
    try {
      await _repo.setDevotionalEntryProgress(entry.id);
      if (!mounted) return;
      final next = {..._completedEntryIds, entry.id};
      setState(() {
        _completedEntryIds = next;
        _markingEntryId = null;
      });

      final analytics = GetIt.instance<AnalyticsService>();
      final creatorId = _creator?.id ?? widget.item.profileCreatorId ?? '';
      analytics.trackCompletion(
        mediaId: entry.id,
        creatorId: creatorId,
        contentType: ContentTypes.devotionalEntry,
        source: widget.source,
      );
      // Finishing the last published day completes the series too.
      if (next.length >= series.entryCount) {
        analytics.trackCompletion(
          mediaId: series.id,
          creatorId: creatorId,
          contentType: ContentTypes.devotionalSeries,
          source: widget.source,
        );
      }
    } catch (e) {
      logger.w('Marking devotional day read failed', error: e);
      if (mounted) setState(() => _markingEntryId = null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      switch (widget.kind) {
        case ContentDetailKind.post:
          final post = await _repo.fetchPost(_id);
          _post = post;
          _baseline = _countsOf(post.engagement);
        case ContentDetailKind.devotional:
          final series = await _repo.fetchDevotionalSeries(_id);
          _completedEntryIds = series.completedEntryIds.toSet();
          _devotional = series;
          _baseline = _countsOf(series.engagement);
        case ContentDetailKind.event:
          final event = await _repo.fetchEvent(_id);
          _event = event;
          _baseline = _countsOf(event.engagement);
      }
      if (mounted) setState(() => _loading = false);
      _store.seed(
        targetType: _targetType,
        targetId: _id,
        likes: _baseline.likes,
        saves: _baseline.saves,
        comments: _baseline.comments,
      );
      _reportOpened();
      unawaited(_resolveCreator());
      unawaited(_hydrateInteraction());
    } catch (e) {
      logger.e('Content detail (${widget.kind.name}) failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Reader-side beacons: the page is on screen (`impression`), and the body
  /// it was opened for is available to read (`view_started`).
  ///
  /// Content entities are targeted by `contentType` + `contentId`; sending a
  /// post id as `mediaId` would attach the event to unrelated media.
  void _reportOpened() {
    if (_reported) return;
    final contentType = ContentTypes.fromEntityType(widget.item.entityType);
    if (contentType == null) return;
    _reported = true;

    final analytics = GetIt.instance<AnalyticsService>();
    final creatorId = _creator?.id ?? widget.item.profileCreatorId ?? '';
    analytics.trackImpression(
      mediaId: _id,
      creatorId: creatorId,
      contentType: contentType,
      source: widget.source,
    );
    analytics.trackViewStarted(
      mediaId: _id,
      creatorId: creatorId,
      contentType: contentType,
      source: widget.source,
    );
  }

  /// Library rows carry only a creatorId, so the header would otherwise show
  /// "0 Subscribers" and no verified badge.
  Future<void> _resolveCreator() async {
    if (widget.item.creator != null) return;
    final creatorId =
        _post?.creatorId ??
        _devotional?.creatorId ??
        _event?.creatorId ??
        widget.item.profileCreatorId;
    if (creatorId == null || creatorId.isEmpty) return;
    try {
      final creator = await _repo.fetchCreatorById(creatorId);
      if (mounted) setState(() => _creator = creator);
    } catch (e) {
      logger.w('creator lookup failed', error: e);
    }
  }

  /// These payloads carry counts but not the viewer's own state, so an already
  /// liked post opened cold showed an empty heart — and tapping it un-liked.
  Future<void> _hydrateInteraction() async {
    if (!_authed) return;
    try {
      final mine = await _engagement.fetchMyInteractions(
        targetType: _targetType,
        targetIds: [_id],
      );
      if (mounted) _store.seedInteractions(_targetType, mine);
    } catch (e) {
      logger.w('interaction state for $_id failed', error: e);
    }
  }

  /// Live state for this content: the store's, falling back to the payload's.
  EngagementState get _engagementState =>
      _store.resolve(_targetType, _id, _baseline);

  static EngagementState _countsOf(ContentEngagement e) =>
      EngagementState(likes: e.likes, saves: e.favorites, comments: e.comments);

  bool _requireAccount(String feature) {
    if (_authed) return true;
    showAuthSheet(context, feature);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.base1,
        // Rebuilt on any engagement change, wherever it was made — the card
        // this page was opened from, or the comments sheet over it.
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _store,
            builder: (context, _) => _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed) return ErrorStateView(onRetry: _load);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(onBack: () => Navigator.of(context).maybePop()),
          Padding(
            padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 13.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailTitleBlock(
                  title: _title,
                  viewsLabel: _views > 0
                      ? '${formatCount(_views)} ${AppStrings.viewsLabel}'
                      : null,
                  dateLabel: _dateLabel,
                ),
                SizedBox(height: 20.s),
                DetailCreatorRow(
                  name: _creatorName,
                  subscribersLabel:
                      '${formatCount(_subscribers)} ${AppStrings.subscribers}',
                  verified: _creator?.isVerified ?? widget.item.creatorVerified,
                  isOrganization:
                      _creator?.isOrganization ??
                      widget.item.meta.creatorType == 'organization',
                  onTap: () => openCreatorProfile(
                    context,
                    creatorId: _creator?.id ?? widget.item.profileCreatorId,
                  ),
                ),
                SizedBox(height: 20.s),
                const DetailDivider(),
                SizedBox(height: 13.s),
                DetailImpactActions(
                  likes: formatCount(_engagementState.likes),
                  saves: formatCount(_engagementState.saves),
                  liked: _engagementState.liked,
                  saved: _engagementState.saved,
                  onLike: () {
                    if (!_requireAccount('like this')) return;
                    _store.toggleLike(
                      targetType: _targetType,
                      targetId: _id,
                      fallback: _baseline,
                    );
                  },
                  onSave: () {
                    if (!_requireAccount('save this')) return;
                    _store.toggleSave(
                      targetType: _targetType,
                      targetId: _id,
                      fallback: _baseline,
                    );
                  },
                ),
                const DetailDivider(),
                SizedBox(height: 20.s),
                ..._typeBody(),
                SizedBox(height: 24.s),
                DetailCommentsPreview(
                  count: _engagementState.comments,
                  onOpen: () => openComments(
                    context,
                    targetType: _targetType,
                    targetId: _id,
                    initialCount: _engagementState.comments,
                  ),
                ),
                SizedBox(height: 40.s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _creatorName {
    final name = _creator?.displayName ?? widget.item.creatorDisplayName;
    return name.isEmpty ? AppStrings.brandName : name;
  }

  int get _subscribers =>
      _creator?.subscriberCount ?? widget.item.creator?.subscriberCount ?? 0;

  String get _title => switch (widget.kind) {
    ContentDetailKind.post => _post?.title ?? widget.item.title,
    ContentDetailKind.devotional => _devotional?.title ?? widget.item.title,
    ContentDetailKind.event => _event?.title ?? widget.item.title,
  };

  int get _views => switch (widget.kind) {
    ContentDetailKind.post => _post?.engagement.views ?? 0,
    ContentDetailKind.devotional => _devotional?.engagement.views ?? 0,
    ContentDetailKind.event => _event?.engagement.views ?? 0,
  };

  String? get _dateLabel {
    final at = switch (widget.kind) {
      ContentDetailKind.post => _post?.publishedAt,
      ContentDetailKind.event => _event?.startAt,
      ContentDetailKind.devotional => null,
    };
    if (at == null) return null;
    final local = at.toLocal();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  List<Widget> _typeBody() => switch (widget.kind) {
    ContentDetailKind.post => _postBody(),
    ContentDetailKind.devotional => _devotionalBody(),
    ContentDetailKind.event => _eventBody(),
  };

  List<Widget> _postBody() {
    final post = _post;
    if (post == null) return const [];
    final body = post.body?.trim();
    return [
      if (post.excerpt case final excerpt? when excerpt.trim().isNotEmpty) ...[
        DetailDescriptionCard(title: AppStrings.summaryLabel, body: excerpt),
        SizedBox(height: 20.s),
      ],
      if (body != null && body.isNotEmpty) MarkdownBody(source: body),
      if (post.scriptureRefs.isNotEmpty) ...[
        SizedBox(height: 20.s),
        _Chips(labels: post.scriptureRefs),
      ],
    ];
  }

  List<Widget> _devotionalBody() {
    final series = _devotional;
    if (series == null) return const [];
    return [
      if (series.description case final d? when d.trim().isNotEmpty) ...[
        DetailDescriptionCard(body: d),
        SizedBox(height: 20.s),
      ],
      DetailSectionHeading(
        '${AppStrings.daysInDevotion} · ${series.entryCount}',
      ),
      SizedBox(height: 12.s),
      for (final entry in series.entries)
        _DayRow(
          entry: entry,
          completed: _completedEntryIds.contains(entry.id),
          current: series.currentEntryId == entry.id,
          busy: _markingEntryId == entry.id,
          onToggle: _authed ? () => _markDayRead(series, entry) : null,
        ),
    ];
  }

  List<Widget> _eventBody() {
    final event = _event;
    if (event == null) return const [];
    return [
      _EventFacts(event: event),
      if (event.description case final d? when d.trim().isNotEmpty) ...[
        SizedBox(height: 20.s),
        DetailDescriptionCard(body: d),
      ],
    ];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(15.s, 12.s, 15.s, 8.s),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onBack,
        child: SizedBox(
          width: 32.s,
          height: 32.s,
          child: const Center(
            child: HugeIcon(
              icon: AppIcons.back,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 6.s),
            decoration: BoxDecoration(
              color: AppColors.fieldBg,
              borderRadius: BorderRadius.circular(999.s),
            ),
            child: Text(
              label,
              style: AppStyles.label(12, color: AppColors.brandPrimary),
            ),
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.entry,
    required this.completed,
    required this.current,
    this.onToggle,
    this.busy = false,
  });

  final DevotionalEntry entry;
  final bool completed;
  final bool current;

  /// Marks the day read. Null for signed-out readers, whose progress the API
  /// will not store.
  final VoidCallback? onToggle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.s),
      padding: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(8.s),
        border: current
            ? Border.all(color: AppColors.brandPrimary, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34.s,
            height: 34.s,
            decoration: BoxDecoration(
              color: completed ? AppColors.brandPrimary : AppColors.neutral800,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${entry.dayNumber ?? '-'}',
                style: AppStyles.heading(13),
              ),
            ),
          ),
          SizedBox(width: 12.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.heading(14, letterSpacing: -0.3),
                ),
                if (entry.memoryVerseRef case final ref?
                    when ref.trim().isNotEmpty) ...[
                  SizedBox(height: 2.s),
                  Text(
                    ref,
                    style: AppStyles.body(12, color: AppColors.neutral400),
                  ),
                ],
              ],
            ),
          ),
          if (onToggle != null) ...[
            SizedBox(width: 8.s),
            _DayCheck(completed: completed, busy: busy, onTap: onToggle!),
          ],
        ],
      ),
    );
  }
}

/// The read/unread control on a devotional day.
///
/// Deliberately a small tick rather than a button: the row already carries the
/// day number and title, and the design keeps the list quiet.
class _DayCheck extends StatelessWidget {
  const _DayCheck({
    required this.completed,
    required this.busy,
    required this.onTap,
  });

  final bool completed;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: SizedBox(
        width: 32.s,
        height: 32.s,
        child: Center(
          child: busy
              ? SizedBox(
                  width: 16.s,
                  height: 16.s,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPrimary,
                  ),
                )
              : Container(
                  width: 22.s,
                  height: 22.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed ? AppColors.green500 : Colors.transparent,
                    border: Border.all(
                      color: completed
                          ? AppColors.green500
                          : AppColors.neutral700,
                      width: 1.5,
                    ),
                  ),
                  child: completed
                      ? const Center(
                          child: HugeIcon(
                            icon: AppIcons.tick,
                            size: 13,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : null,
                ),
        ),
      ),
    );
  }
}

class _EventFacts extends StatelessWidget {
  const _EventFacts({required this.event});

  final EventDetail event;

  String _when() {
    final at = event.startAt?.toLocal();
    if (at == null) return AppStrings.notAvailable;
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    return '${relativeAge(at)} · $hour:$minute${at.hour < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Fact(icon: AppAssets.iconPin, label: _when()),
        if (event.locationLabel case final where? when where.isNotEmpty)
          _Fact(icon: AppAssets.iconPin, label: where),
        if (event.venueType case final type? when type.isNotEmpty)
          _Fact(icon: AppAssets.iconCatGlobe, label: type),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.s),
      child: Row(
        children: [
          DesignIcon(icon, width: 14.s, height: 14.s),
          SizedBox(width: 8.s),
          Expanded(
            child: Text(
              label,
              style: AppStyles.body(13, color: AppColors.neutral300),
            ),
          ),
        ],
      ),
    );
  }
}
