import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/app_styles.dart';
import '../core/logger.dart';
import '../features/discovery/models/media_detail.dart';
import '../features/discovery/models/web_feed_item.dart';
import '../features/discovery/repo/discovery_repo.dart';
import '../features/engagement/models/engagement_models.dart';
import '../features/engagement/repo/engagement_repo.dart';
import 'player_screen.dart';

class MediaDetailScreen extends StatefulWidget {
  const MediaDetailScreen({super.key, required this.item});

  final WebFeedItem item;

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  final _repo = GetIt.instance<DiscoveryRepo>();
  final _engagementRepo = GetIt.instance<EngagementRepo>();

  MediaDetailData? _detail;
  bool _loading = true;
  String? _error;
  bool _descExpanded = false;
  String? _sessionId;

  // Like / dislike
  bool _hasLiked = false;
  bool _hasDisliked = false;
  bool _interactionLoading = false;

  // Comments
  final List<MediaComment> _comments = [];
  bool _commentsLoading = false;
  bool _commentsLoadingMore = false;
  String? _commentsCursor;
  bool _commentsLoaded = false;

  String _clientSessionId() =>
      _sessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

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
        clientSessionId: _clientSessionId(),
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        _hasLiked = detail.viewer?.hasLiked ?? false;
        _hasDisliked = detail.viewer?.hasDisliked ?? false;
      });
      if (!_commentsLoaded) _fetchComments();
    } catch (e) {
      logger.e('MediaDetail: fetch failed for ${widget.item.entityId}', error: e);
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

  Future<void> _toggleLike() async {
    if (_interactionLoading) return;
    final mediaId = _detail?.media.id ?? widget.item.entityId;
    final wasLiked = _hasLiked;
    setState(() {
      _hasLiked = !_hasLiked;
      if (_hasLiked) _hasDisliked = false;
      _interactionLoading = true;
    });
    try {
      await _engagementRepo.toggleInteraction(
        targetType: 'media',
        targetId: mediaId,
        interactionType: 'like',
      );
    } catch (e) {
      logger.e('toggleLike failed', error: e);
      if (mounted) setState(() => _hasLiked = wasLiked);
    } finally {
      if (mounted) setState(() => _interactionLoading = false);
    }
  }

  Future<void> _toggleDislike() async {
    if (_interactionLoading) return;
    final mediaId = _detail?.media.id ?? widget.item.entityId;
    final wasDisliked = _hasDisliked;
    setState(() {
      _hasDisliked = !_hasDisliked;
      if (_hasDisliked) _hasLiked = false;
      _interactionLoading = true;
    });
    try {
      await _engagementRepo.toggleInteraction(
        targetType: 'media',
        targetId: mediaId,
        interactionType: 'dislike',
      );
    } catch (e) {
      logger.e('toggleDislike failed', error: e);
      if (mounted) setState(() => _hasDisliked = wasDisliked);
    } finally {
      if (mounted) setState(() => _interactionLoading = false);
    }
  }

  void _openPlayer() {
    final url = _detail?.playback?.playbackUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playback not available')),
      );
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
          mediaId: widget.item.entityId,
          creatorId: _detail?.creator?.creatorId,
          source: 'home_feed',
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _detail?.media.title.isNotEmpty == true
        ? _detail!.media.title
        : widget.item.title;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: _loading
            ? null
            : Text(title, style: AppStyles.appBarTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              _buildError()
            else
              _buildInfo(),
          ],
        ),
      ),
    );
  }

  // 16:9 thumbnail with play overlay
  Widget _buildHero() {
    final thumbnailUrl =
        _detail?.playback?.thumbnailUrl ?? widget.item.meta.thumbnailUrl;
    final canPlay =
        _detail?.playback?.playbackUrl.isNotEmpty == true;

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
          // Gradient to make play button pop
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
    final title = detail.media.title.isNotEmpty
        ? detail.media.title
        : widget.item.title;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + type row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              if (detail.playback?.durationSeconds != null) ...[
                const SizedBox(width: 12),
                Text(
                  _formatDuration(detail.playback!.durationSeconds!),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),

          // Creator row
          if (detail.creator != null) ...[
            const SizedBox(height: 14),
            _buildCreatorRow(detail.creator!),
          ],

          // Description
          if (detail.media.description?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            _buildDescription(detail.media.description!),
          ],

          // Watch button or unavailable notice
          const SizedBox(height: 20),
          if (detail.playback?.playbackUrl.isNotEmpty == true)
            FilledButton.icon(
              onPressed: _openPlayer,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(AppStrings.watchNow),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.block_rounded, color: AppColors.textTertiary, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Playback not available',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),

          // Like / Dislike
          const SizedBox(height: 16),
          _buildEngagementRow(),

          // Comments
          const SizedBox(height: 28),
          _buildComments(),

          // Suggestions
          if (detail.suggestions.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text(
              'MORE LIKE THIS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            ...detail.suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SuggestionCard(
                  item: s,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaDetailScreen(item: s),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCreatorRow(MediaCreatorInfo creator) {
    return Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            creator.displayName.isNotEmpty
                ? creator.displayName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      creator.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (creator.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 15,
                    ),
                  ],
                ],
              ),
              Text('@${creator.handle}', style: AppStyles.videoPath),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(String description) {
    return GestureDetector(
      onTap: () => setState(() => _descExpanded = !_descExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.55,
            ),
            maxLines: _descExpanded ? null : 3,
            overflow:
                _descExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            _descExpanded ? 'Show less' : 'more',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementRow() {
    return Row(
      children: [
        _InteractionButton(
          icon: _hasLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
          label: 'Like',
          active: _hasLiked,
          onTap: _interactionLoading ? null : _toggleLike,
        ),
        const SizedBox(width: 8),
        _InteractionButton(
          icon: _hasDisliked
              ? Icons.thumb_down_rounded
              : Icons.thumb_down_outlined,
          label: 'Dislike',
          active: _hasDisliked,
          onTap: _interactionLoading ? null : _toggleDislike,
        ),
      ],
    );
  }

  Widget _buildComments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMMENTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        if (_commentsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No comments yet',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            ),
          )
        else ...[
          ..._comments.map((c) => _CommentCard(comment: c)),
          if (_commentsCursor != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _commentsLoadingMore
                    ? null
                    : () => _fetchComments(loadMore: true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                ),
                child: _commentsLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text('Load more comments'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.error_outline_rounded,
            size: 52,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Could not load content',
            style: AppStyles.emptyTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: AppStyles.emptySubtitle,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _fetchDetail,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final total = seconds.toInt();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ── Like / Dislike button ─────────────────────────────────────────────────────

class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.textTertiary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comment card ──────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final MediaComment comment;

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    final initial = author?.displayName.isNotEmpty == true
        ? author!.displayName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      author?.displayName ?? 'Anonymous',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (author?.isVerified == true) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.primary,
                        size: 13,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (comment.likeCount > 0 || comment.replyCount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (comment.likeCount > 0) ...[
                        const Icon(
                          Icons.thumb_up_outlined,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${comment.likeCount}',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (comment.replyCount > 0)
                        Text(
                          '${comment.replyCount} ${comment.replyCount == 1 ? 'reply' : 'replies'}',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                    ],
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

// ── Compact suggestion card ───────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.item, required this.onTap});

  final WebFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 108,
              height: 60,
              child: item.meta.thumbnailUrl != null
                  ? Image.network(
                      item.meta.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _SuggestionPlaceholder(),
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : const _SuggestionPlaceholder(),
                    )
                  : const _SuggestionPlaceholder(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppStyles.videoTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.creator != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.creator!.displayName,
                    style: AppStyles.videoPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _SuggestionPlaceholder extends StatelessWidget {
  const _SuggestionPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.surfaceVariant,
    child: Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: AppColors.textTertiary,
        size: 22,
      ),
    ),
  );
}
