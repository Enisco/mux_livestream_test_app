import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/player/views/player_screen.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/media_detail.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/app_session_service.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class MediaDetailScreen extends StatefulWidget {
  const MediaDetailScreen({
    super.key,
    required this.item,
    this.source = AnalyticsSource.unknown,
  });

  final WebFeedItem item;

  final String source;

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  final _repo = GetIt.instance<DiscoveryRepo>();
  final _engagementRepo = GetIt.instance<EngagementRepo>();

  MediaDetailData? _detail;
  bool _loading = true;
  String? _error;

  bool _hasLiked = false;
  bool _hasSaved = false;
  bool _interactionLoading = false;

  int _likes = 0;
  int _saves = 0;
  bool _following = false;
  bool _followBusy = false;

  final List<MediaComment> _comments = [];
  bool _commentsLoading = false;
  bool _commentsLoadingMore = false;
  String? _commentsCursor;
  bool _commentsLoaded = false;
  bool _impressionSent = false;

  String get _clientSessionId =>
      GetIt.instance<AppSessionService>().clientSessionId;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repo.fetchMediaDetail(
        widget.item.entityId,
        clientSessionId: _clientSessionId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _hasLiked = detail.viewer?.hasLiked ?? false;
        _hasSaved = detail.viewer?.hasSaved ?? false;
        _likes = detail.media.likes;
        _saves = detail.media.favorites;
        _following =
            detail.viewer?.isFollowingCreator ??
            detail.creator?.isFollowing ??
            false;
      });
      _trackOrganicImpression();
      if (!_commentsLoaded) _fetchComments();
    } catch (e) {
      logger.e(
        'MediaDetail: fetch failed for ${widget.item.entityId}',
        error: e,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchComments({bool loadMore = false}) async {
    if (loadMore) {
      if (_commentsLoadingMore || _commentsCursor == null) return;
      setState(() => _commentsLoadingMore = true);
    } else {
      if (_commentsLoading) return;
      setState(() => _commentsLoading = true);
    }
    try {
      final result = await _engagementRepo.fetchComments(
        targetType: 'media',
        targetId: widget.item.entityId,
        cursor: loadMore ? _commentsCursor : null,
      );
      if (!mounted) return;
      setState(() {
        if (!loadMore) _comments.clear();
        _comments.addAll(result.items);
        _commentsCursor = result.nextCursor;
        _commentsLoaded = true;
        _commentsLoading = false;
        _commentsLoadingMore = false;
      });
    } catch (e) {
      logger.e('MediaDetail: comments fetch failed', error: e);
      if (mounted) {
        setState(() {
          _commentsLoading = false;
          _commentsLoadingMore = false;
        });
      }
    }
  }

  Future<void> _toggleLike() => _toggleInteraction(
    type: 'like',
    active: _hasLiked,
    apply: (on) => setState(() {
      _hasLiked = on;
      _likes = (_likes + (on ? 1 : -1)).clamp(0, 1 << 31);
    }),
  );

  Future<void> _toggleSave() => _toggleInteraction(
    type: 'favorite',
    active: _hasSaved,
    apply: (on) => setState(() {
      _hasSaved = on;
      _saves = (_saves + (on ? 1 : -1)).clamp(0, 1 << 31);
    }),
  );

  /// Optimistic toggle: flip locally, roll back if the server refuses. The API
  /// only knows like/favorite/amen/share — there is no dislike.
  Future<void> _toggleInteraction({
    required String type,
    required bool active,
    required void Function(bool on) apply,
  }) async {
    if (_interactionLoading) return;
    final mediaId = _detail?.media.id ?? widget.item.entityId;
    apply(!active);
    setState(() => _interactionLoading = true);
    try {
      await _engagementRepo.toggleInteraction(
        targetType: 'media',
        targetId: mediaId,
        interactionType: type,
      );
    } catch (e) {
      logger.e('toggle $type failed', error: e);
      if (mounted) apply(active);
    } finally {
      if (mounted) setState(() => _interactionLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final creatorId = _detail?.creator?.creatorId;
    if (creatorId == null || _followBusy) return;
    final was = _following;
    setState(() {
      _following = !was;
      _followBusy = true;
    });
    try {
      await _repo.setFollowing(creatorId, follow: !was);
    } catch (e) {
      logger.w('follow failed', error: e);
      if (mounted) setState(() => _following = was);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  void _trackOrganicImpression() {
    if (_impressionSent) return;
    final creatorId = _detail?.creator?.creatorId;
    if (creatorId == null || creatorId.isEmpty) return;
    _impressionSent = true;
    GetIt.instance<AnalyticsService>().trackImpression(
      mediaId: _mediaId,
      creatorId: creatorId,
      mediaType: _mediaType,
      source: widget.source,
    );
  }

  String get _mediaId => _detail?.media.id.isNotEmpty == true
      ? _detail!.media.id
      : widget.item.entityId;

  String? get _mediaType =>
      _detail?.playback?.mediaType ??
      MediaTypes.normalize(_detail?.media.type) ??
      widget.item.mediaType;

  void _openSuggestion(WebFeedItem suggestion) {
    GetIt.instance<AnalyticsService>().trackContentClick(
      mediaId: suggestion.entityId,
      creatorId: suggestion.creator?.creatorId ?? '',
      mediaType: suggestion.mediaType,
      source: AnalyticsSource.suggestedContent,
      promotion: suggestion.promotion,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailScreen(
          item: suggestion,
          source: AnalyticsSource.suggestedContent,
        ),
      ),
    );
  }

  void _openPlayer() {
    final url = _detail?.playback?.playbackUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Playback not available')));
      return;
    }
    final title = _detail?.media.title.isNotEmpty == true
        ? _detail!.media.title
        : widget.item.title;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen.network(
          networkUrl: url,
          title: title,
          mediaId: _mediaId,
          creatorId: _detail?.creator?.creatorId,
          mediaType: _mediaType,
          source: widget.source,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The design has no app bar — the back arrow floats over the hero.
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHero(),
              if (_loading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 64.s),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                )
              else if (_error != null)
                _buildError()
              else
                _buildInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final thumbnailUrl =
        _detail?.playback?.thumbnailUrl ?? widget.item.meta.thumbnailUrl;
    final canPlay = _detail?.playback?.playbackUrl.isNotEmpty == true;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.surfaceVariant),
          if (thumbnailUrl != null)
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1.0],
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
          Positioned(
            left: 15.s,
            top: MediaQuery.paddingOf(context).top + 12.s,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                width: 32.s,
                height: 32.s,
                child: Center(
                  child: DesignIcon(
                    AppAssets.iconArrowLeft,
                    width: 20.s,
                    height: 14.s,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          if (canPlay)
            Center(
              child: GestureDetector(
                onTap: _openPlayer,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    final detail = _detail!;
    final media = detail.media;
    final creator = detail.creator;
    final title = media.title.isNotEmpty ? media.title : widget.item.title;
    final description = media.description?.trim();
    final top = _comments.isEmpty ? null : _comments.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.s, 16.s, 16.s, 13.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailTitleBlock(
                title: title,
                viewsLabel: media.views > 0
                    ? '${formatCount(media.views)} Views'
                    : null,
                dateLabel: _publishedLabel(media.publishedAt),
              ),
              if (creator != null) ...[
                SizedBox(height: 23.s),
                DetailCreatorRow(
                  name: creator.displayName,
                  subscribersLabel:
                      '${formatCount(creator.subscriberCount)} Subscribers',
                  verified: creator.isVerified,
                  isOrganization: creator.isOrganization,
                  following: _following,
                  busy: _followBusy,
                  onTap: () =>
                      openCreatorProfile(context, creatorId: creator.creatorId),
                  onFollow: _toggleFollow,
                ),
              ],
              SizedBox(height: 23.s),
              const DetailDivider(),
              SizedBox(height: 13.s),
              DetailImpactActions(
                likes: formatCount(_likes),
                saves: formatCount(_saves),
                liked: _hasLiked,
                saved: _hasSaved,
                onLike: _interactionLoading ? null : _toggleLike,
                onSave: _interactionLoading ? null : _toggleSave,
              ),
              const DetailDivider(),
              if (description != null && description.isNotEmpty) ...[
                SizedBox(height: 23.s),
                DetailDescriptionCard(body: description),
              ],
              SizedBox(height: 23.s),
              DetailCommentsPreview(
                count: media.comments,
                topComment: top?.body,
                topCommentAuthor: top?.author?.displayName,
              ),
            ],
          ),
        ),
        const DetailDivider(),
        if (detail.suggestions.isNotEmpty) _buildUpNext(detail),
        SizedBox(height: 32.s),
      ],
    );
  }

  /// "June 12, 2026" under the title.
  static String? _publishedLabel(DateTime? at) {
    if (at == null) return null;
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
    final local = at.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  Widget _buildError() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.s, vertical: 64.s),
      child: Column(
        children: [
          Text(
            AppStrings.failedToLoad,
            textAlign: TextAlign.center,
            style: AppStyles.heading(16),
          ),
          SizedBox(height: 16.s),
          SizedBox(
            width: 200.s,
            child: PrimaryButton(
              label: AppStrings.feedRetry,
              height: 44,
              onPressed: _fetchDetail,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpNext(MediaDetailData detail) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 18.s, 16.s, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionHeading(AppStrings.upNext),
          SizedBox(height: 18.s),
          for (final s in detail.suggestions)
            Padding(
              padding: EdgeInsets.only(bottom: 18.s),
              child: PromotedImpressionTracker(
                promotion: s.promotion,
                mediaId: s.entityId,
                creatorId: s.creator?.creatorId ?? '',
                mediaType: s.mediaType,
                source: AnalyticsSource.suggestedContent,
                // The design's "Up next" rows are the same mobile card the
                // feed uses, not a compact thumbnail row.
                child: FeedCard(
                  data: FeedCardMapper.toCardData(s),
                  onTap: () => _openSuggestion(s),
                  onCreatorTap: () => openCreatorProfile(
                    context,
                    creatorId: s.profileCreatorId,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
