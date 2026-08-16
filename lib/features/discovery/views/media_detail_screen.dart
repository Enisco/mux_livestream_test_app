import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';
import 'package:test_app/core/locator.dart';
import 'package:test_app/features/discovery/views/widgets/audio_hero.dart';
import 'package:test_app/features/engagement/views/comments_sheet.dart';
import 'package:test_app/features/discovery/views/widgets/video_hero.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/analytics/views/widgets/promoted_impression_tracker.dart';
import 'package:test_app/features/creator/views/creator_profile_screen.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/media_detail.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/analytics_service.dart';
import 'package:test_app/shared/services/app_session_service.dart';
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
  final _playback = getIt<PlaybackController>();

  /// Measures the hero so the comments sheet can stop exactly below it. Video
  /// and audio heroes are different heights, so this is measured, not assumed.
  final _heroKey = GlobalKey();

  /// Starts from the detail aggregate's inline batch, then grows by page.
  List<WebFeedItem> _suggestions = const [];
  String? _suggestionsCursor;
  bool _loadingSuggestions = false;
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
        _suggestions = detail.suggestions;
        // The aggregate carries no cursor, so a full page inline means there is
        // probably more; the route itself confirms when asked.
        _suggestionsCursor = detail.suggestions.isEmpty ? null : 'start';
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

  /// Everything a playback beacon needs about what is on this screen.
  PlaybackTarget get _target => PlaybackTarget(
    mediaId: _mediaId,
    creatorId:
        _detail?.creator?.creatorId ?? widget.item.creator?.creatorId ?? '',
    mediaType: _mediaType,
    source: widget.source,
  );

  String? get _mediaType =>
      _detail?.playback?.mediaType ??
      MediaTypes.normalize(_detail?.media.type) ??
      widget.item.mediaType;

  void _openSuggestion(WebFeedItem suggestion) {
    GetIt.instance<AnalyticsService>().trackContentClick(
      mediaId: suggestion.entityId,
      contentType: ContentTypes.fromEntityType(suggestion.entityType),
      creatorId: suggestion.creator?.creatorId ?? '',
      mediaType: suggestion.mediaType,
      source: AnalyticsSource.suggestedContent,
      promotion: suggestion.promotion,
    );
    openContentDetail(
      context,
      suggestion,
      source: AnalyticsSource.suggestedContent,
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
        // The hero sits outside the scroll view so the page slides beneath it
        // and playback is never interrupted by the reader reading on.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(key: _heroKey, child: _buildHero()),
            Expanded(
              child: SingleChildScrollView(
                child: _loading
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 64.s),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      )
                    : _error != null
                    ? _buildError()
                    : _buildInfo(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The hero's laid-out height, or null before it has been measured.
  double? get _heroHeight {
    final box = _heroKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.size.height;
  }

  Widget _buildHero() {
    // Audio gets its own listening layout — a 16:9 frame with a play overlay
    // would be a video screen wearing a track's name.
    if (_mediaType == MediaTypes.music) {
      return AudioHero(
        playback: _playback,
        target: _target,
        title: _detail?.media.title.isNotEmpty == true
            ? _detail!.media.title
            : widget.item.title,
        creatorName:
            _detail?.creator?.displayName ?? widget.item.creatorDisplayName,
        artworkUrl:
            _detail?.playback?.thumbnailUrl ?? widget.item.meta.thumbnailUrl,
        playbackUrl: _detail?.playback?.playbackUrl,
      );
    }

    return VideoHero(
      playback: _playback,
      target: _target,
      videoController: _playback.videoController,
      playbackUrl: _detail?.playback?.playbackUrl,
      thumbnailUrl:
          _detail?.playback?.thumbnailUrl ?? widget.item.meta.thumbnailUrl,
      onBack: () => Navigator.of(context).maybePop(),
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
                topCommentCreatedAt: top?.createdAt,
                onOpen: () => openComments(
                  context,
                  targetType: InteractionTargets.media,
                  targetId: _mediaId,
                  initialCount: media.comments,
                  topInset: _heroHeight,
                ),
              ),
            ],
          ),
        ),
        const DetailDivider(),
        if (_suggestions.isNotEmpty) _buildUpNext(),
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

  Widget _buildError() => ErrorStateView(onRetry: _fetchDetail);

  /// Pulls another page of "Up next".
  ///
  /// The detail aggregate returns a first batch inline; anything past that comes
  /// from the suggestions route, which is the only way to see more than ten.
  Future<void> _loadMoreSuggestions() async {
    if (_loadingSuggestions || _suggestionsCursor == null) return;
    setState(() => _loadingSuggestions = true);
    try {
      final page = await _repo.fetchContentSuggestions(
        targetType: 'media',
        targetId: _mediaId,
        // 'start' is our own marker for "inline batch only, never paged yet".
        cursor: _suggestionsCursor == 'start' ? null : _suggestionsCursor,
        // Never re-offer something already on the list, or the media itself.
        excludeEntityIds: [_mediaId, ..._suggestions.map((s) => s.entityId)],
      );
      if (!mounted) return;
      setState(() {
        _suggestions = [..._suggestions, ...page.items];
        _suggestionsCursor = page.nextCursor;
        _loadingSuggestions = false;
      });
    } catch (e) {
      logger.w('Up next page failed', error: e);
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Widget _buildUpNext() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 18.s, 16.s, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionHeading(AppStrings.upNext),
          SizedBox(height: 18.s),
          for (final s in _suggestions)
            Padding(
              padding: EdgeInsets.only(bottom: 18.s),
              child: PromotedImpressionTracker(
                promotion: s.promotion,
                mediaId: s.entityId,
                contentType: ContentTypes.fromEntityType(s.entityType),
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
                  playback: _playback,
                  source: AnalyticsSource.suggestedContent,
                ),
              ),
            ),
          if (_suggestionsCursor != null) ...[
            SizedBox(height: 8.s),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _loadMoreSuggestions,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 22.s,
                    vertical: 11.s,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22.s),
                    border: Border.all(color: AppColors.neutral700),
                  ),
                  child: Text(
                    _loadingSuggestions
                        ? AppStrings.loading
                        : AppStrings.showMore,
                    style: AppStyles.label(13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
