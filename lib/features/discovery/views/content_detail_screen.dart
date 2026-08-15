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
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount, relativeAge;
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/models/discovery_models/content_detail.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/components/design_icon.dart';
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
    ),
    'devotional_series' => (BuildContext _) => ContentDetailScreen(
      item: item,
      kind: ContentDetailKind.devotional,
    ),
    'event' => (BuildContext _) => ContentDetailScreen(
      item: item,
      kind: ContentDetailKind.event,
    ),
    // A devotional entry belongs to its series; open the series.
    'devotional_entry' => (BuildContext _) => ContentDetailScreen(
      item: item,
      kind: ContentDetailKind.devotional,
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
  });

  final WebFeedItem item;
  final ContentDetailKind kind;

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

  bool _liked = false;
  bool _saved = false;
  bool _busy = false;
  int _likes = 0;
  int _saves = 0;

  String get _id => widget.overrideId ?? widget.item.entityId;

  /// The interaction API names these differently from the feed's entityType.
  String get _targetType => switch (widget.kind) {
    ContentDetailKind.post => 'post',
    ContentDetailKind.devotional => 'devotional',
    ContentDetailKind.event => 'event',
  };

  @override
  void initState() {
    super.initState();
    _load();
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
          _likes = post.engagement.likes;
          _saves = post.engagement.favorites;
        case ContentDetailKind.devotional:
          final series = await _repo.fetchDevotionalSeries(_id);
          _devotional = series;
          _likes = series.engagement.likes;
          _saves = series.engagement.favorites;
        case ContentDetailKind.event:
          final event = await _repo.fetchEvent(_id);
          _event = event;
          _likes = event.engagement.likes;
          _saves = event.engagement.favorites;
      }
      if (mounted) setState(() => _loading = false);
      unawaited(_resolveCreator());
    } catch (e) {
      logger.e('Content detail (${widget.kind.name}) failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
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

  Future<void> _toggle({
    required String type,
    required bool active,
    required void Function(bool on) apply,
  }) async {
    if (_busy) return;
    apply(!active);
    setState(() => _busy = true);
    try {
      await _engagement.toggleInteraction(
        targetType: _targetType,
        targetId: _id,
        interactionType: type,
      );
    } catch (e) {
      logger.w('toggle $type failed', error: e);
      if (mounted) apply(active);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.base1,
        body: SafeArea(child: _body()),
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
                  likes: formatCount(_likes),
                  saves: formatCount(_saves),
                  liked: _liked,
                  saved: _saved,
                  onLike: () => _toggle(
                    type: 'like',
                    active: _liked,
                    apply: (on) => setState(() {
                      _liked = on;
                      _likes = (_likes + (on ? 1 : -1)).clamp(0, 1 << 31);
                    }),
                  ),
                  onSave: () => _toggle(
                    type: 'favorite',
                    active: _saved,
                    apply: (on) => setState(() {
                      _saved = on;
                      _saves = (_saves + (on ? 1 : -1)).clamp(0, 1 << 31);
                    }),
                  ),
                ),
                const DetailDivider(),
                SizedBox(height: 20.s),
                ..._typeBody(),
                SizedBox(height: 24.s),
                DetailCommentsPreview(count: _comments),
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

  int get _comments => switch (widget.kind) {
    ContentDetailKind.post => _post?.engagement.comments ?? 0,
    ContentDetailKind.devotional => _devotional?.engagement.comments ?? 0,
    ContentDetailKind.event => _event?.engagement.comments ?? 0,
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
          completed: series.isCompleted(entry.id),
          current: series.currentEntryId == entry.id,
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
  });

  final DevotionalEntry entry;
  final bool completed;
  final bool current;

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
        ],
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
