import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show relativeAge, formatCount;
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/shared/components/auth_sheet.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Opens the comments for a target (Figma `10861-117621`).
///
/// A sheet, not a page: it takes the height left under the media and leaves the
/// player itself uncovered, so a video keeps playing while the reader reads.
/// [topInset] is that media's height — pass the measured hero, so the sheet
/// lands exactly on its bottom edge whatever the media is.
Future<void> openComments(
  BuildContext context, {
  required String targetType,
  required String targetId,
  int initialCount = 0,
  double? topInset,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  // No scrim at all: the design shows the player at full brightness above the
  // sheet, and a dim over it would read as "disabled" while it is still
  // playing. Tapping it closes the sheet.
  barrierColor: Colors.transparent,
  builder: (_) => CommentsSheet(
    targetType: targetType,
    targetId: targetId,
    initialCount: initialCount,
    topInset: topInset,
  ),
);

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.initialCount = 0,
    this.topInset,
  });

  final String targetType;
  final String targetId;
  final int initialCount;

  /// Height of the media above the sheet. Null when there is none to clear.
  final double? topInset;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _repo = GetIt.instance<EngagementRepo>();
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();

  List<MediaComment> _items = const [];
  String? _cursor;
  bool _loading = true;
  bool _failed = false;
  bool _authed = false;
  bool _posting = false;
  int _count = 0;

  /// Replies already fetched, keyed by their parent.
  final Map<String, List<MediaComment>> _replies = {};
  final Set<String> _expanded = {};
  final Set<String> _loadingReplies = {};

  /// The comment being replied to, if any.
  MediaComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _authed = await GetIt.instance<TokenStorageService>().hasSession;
    if (mounted) await _load();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await _repo.fetchComments(
        targetType: widget.targetType,
        targetId: widget.targetId,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _cursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      logger.w('Comments load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _loading) return;
    final cursor = _cursor;
    _cursor = null; // guard against a second page while this one is in flight
    try {
      final page = await _repo.fetchComments(
        targetType: widget.targetType,
        targetId: widget.targetId,
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _cursor = page.nextCursor;
      });
    } catch (e) {
      logger.w('Comments page failed', error: e);
      _cursor = cursor;
    }
  }

  Future<void> _toggleReplies(MediaComment comment) async {
    if (_expanded.contains(comment.id)) {
      setState(() => _expanded.remove(comment.id));
      return;
    }
    setState(() => _expanded.add(comment.id));
    if (_replies.containsKey(comment.id)) return;

    setState(() => _loadingReplies.add(comment.id));
    try {
      final page = await _repo.fetchReplies(commentId: comment.id);
      if (!mounted) return;
      setState(() {
        _replies[comment.id] = page.items;
        _loadingReplies.remove(comment.id);
      });
    } catch (e) {
      logger.w('Replies failed', error: e);
      if (mounted) setState(() => _loadingReplies.remove(comment.id));
    }
  }

  /// Applies a vote optimistically, then reconciles with what the server says.
  Future<void> _vote(MediaComment comment, CommentVote vote) async {
    if (!_requireAccount()) return;

    _replaceComment(_locallyVoted(comment, vote));
    try {
      final updated = await _repo.voteComment(
        commentId: comment.id,
        vote: vote,
      );
      if (updated != null && mounted) _replaceComment(updated);
    } catch (e) {
      logger.w('Comment vote failed', error: e);
      // Put it back the way it was.
      if (mounted) _replaceComment(comment);
    }
  }

  MediaComment _locallyVoted(MediaComment c, CommentVote vote) {
    final had = c.myVote;
    final clearing = had == vote;
    var likes = c.likeCount;
    var dislikes = c.dislikeCount;

    if (had == CommentVote.like) likes -= 1;
    if (had == CommentVote.dislike) dislikes -= 1;
    if (!clearing && vote == CommentVote.like) likes += 1;
    if (!clearing && vote == CommentVote.dislike) dislikes += 1;

    return c.copyWith(
      likeCount: likes < 0 ? 0 : likes,
      dislikeCount: dislikes < 0 ? 0 : dislikes,
      myVote: clearing ? null : vote,
      clearVote: clearing,
    );
  }

  void _replaceComment(MediaComment updated) {
    setState(() {
      _items = [for (final c in _items) c.id == updated.id ? updated : c];
      for (final entry in _replies.entries) {
        _replies[entry.key] = [
          for (final r in entry.value) r.id == updated.id ? updated : r,
        ];
      }
    });
  }

  bool _requireAccount() {
    if (_authed) return true;
    showAuthSheet(context, AppStrings.commentFeature);
    return false;
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _posting) return;
    if (!_requireAccount()) return;

    setState(() => _posting = true);
    final parent = _replyingTo;
    try {
      final created = await _repo.postComment(
        targetType: widget.targetType,
        targetId: widget.targetId,
        body: body,
        parentCommentId: parent?.id,
      );
      if (!mounted) return;
      _composer.clear();
      _composerFocus.unfocus();
      setState(() {
        _posting = false;
        _replyingTo = null;
        _count += 1;
        if (created == null) return;
        if (parent == null) {
          _items = [created, ..._items];
        } else {
          _replies[parent.id] = [...?_replies[parent.id], created];
          _expanded.add(parent.id);
          _items = [
            for (final c in _items)
              c.id == parent.id ? c.copyWith(replyCount: c.replyCount + 1) : c,
          ];
        }
      });
    } catch (e) {
      logger.w('Posting comment failed', error: e);
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.commentFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).height;

    // Sit on the media's bottom edge. With no media to clear, leave a strip so
    // it still reads as a sheet rather than a new screen. Either way it can
    // never eat the whole screen or collapse to nothing.
    final top = (widget.topInset ?? screen * 0.12).clamp(0.0, screen * 0.6);

    return Padding(
      padding: EdgeInsets.only(top: top),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(top > 0 ? 16.s : 0),
        ),
        child: ColoredBox(
          color: AppColors.base1,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
              Padding(
                padding: EdgeInsets.only(bottom: keyboard),
                child: _Composer(
                  controller: _composer,
                  focusNode: _composerFocus,
                  posting: _posting,
                  signedIn: _authed,
                  onRequireAccount: _requireAccount,
                  replyingTo: _replyingTo?.author?.displayName,
                  onCancelReply: () => setState(() => _replyingTo = null),
                  onSend: _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 14.s, 12.s, 10.s),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ),
          SizedBox(width: 8.s),
          Text(
            '${AppStrings.comments} · $_count',
            style: AppStyles.heading(15),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 30.s,
              height: 30.s,
              child: Center(
                child: Container(
                  width: 20.s,
                  height: 20.s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.neutral400),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14.s,
                    color: AppColors.neutral400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed) return ErrorStateView(onRetry: _load);
    if (_items.isEmpty) return const _NoComments();

    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 24.s),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final comment = _items[index];
        final expanded = _expanded.contains(comment.id);
        return _CommentTile(
          comment: comment,
          replies: expanded ? _replies[comment.id] ?? const [] : const [],
          expanded: expanded,
          loadingReplies: _loadingReplies.contains(comment.id),
          onToggleReplies: comment.replyCount == 0
              ? null
              : () => _toggleReplies(comment),
          onReply: () {
            if (!_requireAccount()) return;
            setState(() => _replyingTo = comment);
            _composerFocus.requestFocus();
          },
          onVote: (vote) => _vote(comment, vote),
          onVoteReply: (reply, vote) => _vote(reply, vote),
        );
      },
    );
  }
}

class _NoComments extends StatelessWidget {
  const _NoComments();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMessage01,
            color: AppColors.neutral700,
            size: 40.s,
          ),
          SizedBox(height: 14.s),
          Text(AppStrings.noCommentsYet, style: AppStyles.heading(15)),
          SizedBox(height: 6.s),
          Text(
            AppStrings.beTheFirstToComment,
            textAlign: TextAlign.center,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
        ],
      ),
    ),
  );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.replies,
    required this.expanded,
    required this.loadingReplies,
    required this.onReply,
    required this.onVote,
    required this.onVoteReply,
    this.onToggleReplies,
  });

  final MediaComment comment;
  final List<MediaComment> replies;
  final bool expanded;
  final bool loadingReplies;
  final VoidCallback onReply;
  final ValueChanged<CommentVote> onVote;
  final void Function(MediaComment, CommentVote) onVoteReply;
  final VoidCallback? onToggleReplies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentBody(comment: comment, onReply: onReply, onVote: onVote),
        if (onToggleReplies != null)
          Padding(
            padding: EdgeInsets.only(left: 44.s, top: 2.s),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleReplies,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18.s,
                    color: AppColors.brandPrimary,
                  ),
                  SizedBox(width: 4.s),
                  Text(
                    expanded
                        ? '${AppStrings.hideReplies} ${comment.replyCount} '
                              '${comment.replyCount == 1 ? AppStrings.replyWord : AppStrings.repliesWord}'
                        : AppStrings.showReplies,
                    style: AppStyles.label(
                      12,
                      color: AppColors.brandPrimary,
                      weight: AppStyles.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (expanded) ...[
          if (loadingReplies)
            Padding(
              padding: EdgeInsets.only(left: 44.s, top: 10.s),
              child: SizedBox(
                width: 16.s,
                height: 16.s,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          // The design runs a hairline down the reply column.
          for (final reply in replies)
            Container(
              margin: EdgeInsets.only(left: 20.s),
              padding: EdgeInsets.only(left: 16.s),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.neutral800)),
              ),
              child: _CommentBody(
                comment: reply,
                compact: true,
                onVote: (vote) => onVoteReply(reply, vote),
              ),
            ),
        ],
        SizedBox(height: 14.s),
      ],
    );
  }
}

/// One comment: avatar, name row, body, and the vote/reply actions.
class _CommentBody extends StatelessWidget {
  const _CommentBody({
    required this.comment,
    required this.onVote,
    this.onReply,
    this.compact = false,
  });

  final MediaComment comment;
  final ValueChanged<CommentVote> onVote;

  /// Replies carry no Reply link of their own in the design.
  final VoidCallback? onReply;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    final name = author?.displayName ?? AppStrings.someone;
    return Padding(
      padding: EdgeInsets.only(top: compact ? 12.s : 10.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(name: name, size: compact ? 28.s : 32.s),
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
                    if (author?.isCreator ?? false) ...[
                      SizedBox(width: 6.s),
                      const _CreatorPill(),
                    ],
                    SizedBox(width: 6.s),
                    Text(
                      relativeAge(comment.createdAt),
                      style: AppStyles.label(11, color: AppColors.neutral400),
                    ),
                  ],
                ),
                SizedBox(height: 4.s),
                Text(
                  comment.body,
                  style: AppStyles.body(13, lineHeight: 19 / 13),
                ),
                SizedBox(height: 8.s),
                Row(
                  children: [
                    _VoteButton(
                      icon: HugeIcons.strokeRoundedThumbsUp,
                      count: comment.likeCount,
                      active: comment.myVote == CommentVote.like,
                      onTap: () => onVote(CommentVote.like),
                    ),
                    SizedBox(width: 18.s),
                    _VoteButton(
                      icon: HugeIcons.strokeRoundedThumbsDown,
                      count: comment.dislikeCount,
                      active: comment.myVote == CommentVote.dislike,
                      onTap: () => onVote(CommentVote.dislike),
                      hideZero: true,
                    ),
                    if (onReply != null) ...[
                      SizedBox(width: 18.s),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onReply,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedMessage01,
                              color: AppColors.brandPrimary,
                              size: 15,
                            ),
                            SizedBox(width: 5.s),
                            Text(
                              AppStrings.reply,
                              style: AppStyles.label(
                                12,
                                color: AppColors.brandPrimary,
                                weight: AppStyles.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 6.s),
          Icon(
            Icons.more_vert_rounded,
            size: 17.s,
            color: AppColors.neutral400,
          ),
        ],
      ),
    );
  }
}

class _CreatorPill extends StatelessWidget {
  const _CreatorPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 7.s, vertical: 1.s),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(9.s),
      border: Border.all(color: AppColors.neutral400),
    ),
    child: Text(
      AppStrings.creatorBadge,
      style: AppStyles.label(10, color: AppColors.textPrimary),
    ),
  );
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.count,
    required this.active,
    required this.onTap,
    this.hideZero = false,
  });

  final List<List<dynamic>> icon;
  final int count;
  final bool active;
  final VoidCallback onTap;

  /// The design shows no number beside the thumbs-down until there is one.
  final bool hideZero;

  @override
  Widget build(BuildContext context) {
    final colour = active ? AppColors.brandPrimary : AppColors.neutral400;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: colour, size: 15),
          if (count > 0 || !hideZero) ...[
            SizedBox(width: 5.s),
            Text(formatCount(count), style: AppStyles.label(12, color: colour)),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.purple400, AppColors.cyan400],
        ),
      ),
      child: Text(initial, style: AppStyles.heading(13)),
    );
  }
}

/// The floating "Add a comment" pill.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.posting,
    required this.onSend,
    required this.onCancelReply,
    required this.signedIn,
    required this.onRequireAccount,
    this.replyingTo,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool posting;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;
  final bool signedIn;

  /// Raises the sign-in sheet. Called before a guest can start typing, rather
  /// than after they have written something we cannot post.
  final VoidCallback onRequireAccount;
  final String? replyingTo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.s, 6.s, 12.s, 10.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingTo case final name?)
              Padding(
                padding: EdgeInsets.only(left: 8.s, bottom: 6.s),
                child: Row(
                  children: [
                    Text(
                      '${AppStrings.replyingTo} $name',
                      style: AppStyles.label(12, color: AppColors.neutral400),
                    ),
                    SizedBox(width: 8.s),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCancelReply,
                      child: Icon(
                        Icons.close_rounded,
                        size: 15.s,
                        color: AppColors.neutral400,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(8.s, 8.s, 8.s, 8.s),
              decoration: BoxDecoration(
                color: AppColors.neutral900,
                borderRadius: BorderRadius.circular(28.s),
              ),
              child: Row(
                children: [
                  const _Avatar(name: 'You', size: 32),
                  SizedBox(width: 10.s),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // A guest is asked to sign in before typing, not after
                      // writing something that cannot be posted.
                      onTap: signedIn ? null : onRequireAccount,
                      child: IgnorePointer(
                        ignoring: !signedIn,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.s),
                          decoration: BoxDecoration(
                            color: AppColors.base1,
                            borderRadius: BorderRadius.circular(20.s),
                            border: Border.all(color: AppColors.neutral800),
                          ),
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            style: AppStyles.body(13),
                            cursorColor: AppColors.brandPrimary,
                            onSubmitted: (_) => onSend(),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(2000),
                            ],
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 11.s,
                              ),
                              hintText: AppStrings.addAComment,
                              hintStyle: AppStyles.body(
                                13,
                                color: AppColors.neutral400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.s),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: posting
                        ? null
                        : (signedIn ? onSend : onRequireAccount),
                    child: SizedBox(
                      width: 38.s,
                      height: 38.s,
                      child: Center(
                        child: posting
                            ? SizedBox(
                                width: 16.s,
                                height: 16.s,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.brandPrimary,
                                ),
                              )
                            : const HugeIcon(
                                icon: HugeIcons.strokeRoundedSent,
                                color: AppColors.brandPrimary,
                                size: 22,
                              ),
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
}
