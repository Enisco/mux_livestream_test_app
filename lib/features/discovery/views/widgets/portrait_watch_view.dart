import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:test_app/features/discovery/views/widgets/playback_settings_sheet.dart';
import 'package:test_app/features/discovery/views/widgets/watch_rail.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/live_badge.dart';
import 'package:test_app/shared/components/video_fit.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// Watching an upright video, on the whole screen.
///
/// The media detail's other surface. A video shaped like the phone it is
/// being watched on does not want a frame with a page under it — it wants
/// the screen, with the controls over the picture rather than beside it.
/// [VideoFit.shapeOf] decides which of the two a video gets; this is the
/// [VideoShape.portrait] one.
///
/// **Everything the page offers is on the rail.** The standard layout puts
/// like, save, share and give in a row under the title and the comments in
/// a block below that. None of them may be lost by coming here, so they are
/// all on the right-hand column, in the order a thumb reaches them.
///
/// **The page is not gone, it is under.** Suggestions and the full
/// description still matter — they are what a reader watches next — so the
/// whole standard page is a sheet that comes up from the bottom edge. The
/// video keeps playing behind it, which is the same promise the inline hero
/// makes when the page scrolls under it.
class PortraitWatchView extends StatefulWidget {
  /// How much of the screen a sheet over this video may take.
  ///
  /// It used to be 0.92, which left a sliver of video nobody could make
  /// anything of. At 0.7 the picture keeps a real share of the screen and
  /// shrinks into it, the way it does on every other short-video app.
  /// Public because the comment thread has to stop in the same place.
  static const sheetMax = 0.7;

  const PortraitWatchView({
    super.key,
    required this.playback,
    required this.target,
    required this.title,
    this.videoController,
    this.playbackUrl,
    this.thumbnailUrl,
    this.creatorName,
    this.creatorHandle,
    this.avatarUrl,
    this.description,
    this.likes = '',
    this.saves = '',
    this.comments = '',
    this.liked = false,
    this.saved = false,
    this.following = false,
    this.hasCreator = false,
    this.canGive = false,
    this.isLive = false,
    this.onBack,
    this.onCreator,
    this.onFollow,
    this.onLike,
    this.onSave,
    this.onComments,
    this.onShare,
    this.onGive,
    this.page,
  });

  final PlaybackHandle playback;
  final PlaybackTarget target;
  final VideoController? videoController;
  final String? playbackUrl;
  final String? thumbnailUrl;

  final String title;
  final String? creatorName;
  final String? creatorHandle;
  final String? avatarUrl;
  final String? description;

  /// Already formatted, so this view never has to know how a count is
  /// written. The standard row takes them the same way.
  final String likes;
  final String saves;
  final String comments;

  final bool liked;
  final bool saved;
  final bool following;

  /// Whether there is a ministry to show at all. Without one the avatar and
  /// the follow badge would be a control for nothing.
  final bool hasCreator;

  /// Whether this content's ministry can receive a gift.
  final bool canGive;

  /// Broadcasting right now: no scrubber, and the LIVE badge instead.
  final bool isLive;

  final VoidCallback? onBack;
  final VoidCallback? onCreator;
  final VoidCallback? onFollow;
  final VoidCallback? onLike;
  final VoidCallback? onSave;

  /// Awaited, not fired and forgotten: the picture shrinks out of the
  /// way while the thread is up, and this future is what says when it
  /// has come back down.
  final Future<void> Function()? onComments;
  final VoidCallback? onShare;
  final VoidCallback? onGive;

  /// The standard page, to put under the video on the swipe-up sheet.
  ///
  /// **Content only — it must not scroll itself.** The sheet owns the one
  /// scroll view, with the grab handle as its first item, because that is
  /// what makes the handle draggable: a `DraggableScrollableSheet` is moved
  /// by the scrollable holding its controller and by nothing else. A handle
  /// sitting beside that scrollable looks exactly like a handle and does
  /// nothing at all.
  final Widget Function(BuildContext)? page;

  @override
  State<PortraitWatchView> createState() => _PortraitWatchViewState();
}

class _PortraitWatchViewState extends State<PortraitWatchView> {
  String get _mediaId => widget.target.mediaId;

  /// How tall the sheet is while it is shut: a grab handle and the line that
  /// says there is more under it.
  static const _sheetShut = 62.0;

  bool _autoStarted = false;

  /// How far up the sheet has been pulled, 0 shut and 1 open. The controls
  /// over the video fade out as it rises — they are controls for a picture
  /// that is no longer the thing being looked at.
  double _sheetOpen = 0;

  /// Briefly shown after a tap, then gone again, so the picture is not
  /// covered by a button for the whole watch.
  bool _showPlayPause = false;
  Timer? _hidePlayPause;

  bool _descriptionOpen = false;

  /// The comment thread is up over the video.
  bool _commentsOpen = false;

  /// The last change to the covered fraction came from a drag, so the
  /// picture must track the finger rather than animate after it.
  bool _draggingSheet = false;

  /// How much of the screen is under a sheet right now, 0 to [sheetMax].
  double get _covered => math.max(
    _sheetOpen * PortraitWatchView.sheetMax,
    _commentsOpen ? PortraitWatchView.sheetMax : 0.0,
  );

  final _sheetController = DraggableScrollableController();

  /// The sheet's shut height as a fraction of this screen, worked out in
  /// build and kept so [_shutSheet] knows where to animate back to.
  double _shutExtent = 0.08;

  @override
  void initState() {
    super.initState();
    _autoStart();
  }

  @override
  void didUpdateWidget(PortraitWatchView old) {
    super.didUpdateWidget(old);
    // The URL lands with the detail fetch, a beat after the screen opens.
    if (old.playbackUrl != widget.playbackUrl) _autoStart();
  }

  @override
  void dispose() {
    _hidePlayPause?.cancel();
    _sheetController.dispose();
    // Same reason as the inline hero: by the time a visibility callback
    // fires on teardown this State is already unmounted.
    widget.playback.pauseIfActive(_mediaId);
    super.dispose();
  }

  /// Opening a video means watching it, so it starts on arrival rather than
  /// asking for one more tap. Mirrors `VideoHero`.
  void _autoStart() {
    if (_autoStarted) return;
    final url = widget.playbackUrl;
    if (url == null || url.isEmpty) return;
    _autoStarted = true;

    // Starting playback publishes state synchronously, and this runs from
    // initState/didUpdateWidget — inside the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.playback.isActive(_mediaId)) {
        if (!widget.playback.isPlaying(_mediaId)) widget.playback.resume();
        return;
      }
      widget.playback.play(
        target: widget.target,
        url: url,
        kind: PlaybackKind.video,
      );
    });
  }

  /// Opens the thread and holds the picture small until it is shut.
  Future<void> _openComments() async {
    final open = widget.onComments;
    if (open == null) return;
    setState(() {
      _draggingSheet = false;
      _commentsOpen = true;
    });
    try {
      await open();
    } finally {
      if (mounted) setState(() => _commentsOpen = false);
    }
  }

  void _togglePlay() {
    final url = widget.playbackUrl;
    if (widget.playback.isActive(_mediaId)) {
      widget.playback.togglePlayPause();
    } else if (url != null && url.isNotEmpty) {
      widget.playback.play(
        target: widget.target,
        url: url,
        kind: PlaybackKind.video,
      );
    }
    setState(() => _showPlayPause = true);
    _hidePlayPause?.cancel();
    _hidePlayPause = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showPlayPause = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // With the page pulled up, back belongs to the page: it puts it down
      // again. Leaving the video outright would lose the reader's place for
      // a gesture they meant as "close this".
      canPop: _sheetOpen < 0.02,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _shutSheet();
      },
      child: _buildScreen(context),
    );
  }

  void _shutSheet() {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      _shutExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Widget _buildScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: VisibilityDetector(
        key: Key('portrait-watch-$_mediaId'),
        onVisibilityChanged: (info) {
          // Covered by another route, or gone from the tree: nothing is
          // showing this video any more, so it must not play on unseen.
          // The sheet does not count — it is a sibling in the same stack,
          // and a reader reading the description still wants the sound.
          if (!mounted || info.visibleFraction > 0) return;
          // Unless the fullscreen route is what is covering it, which is
          // still this video being watched. Same guard as the inline hero:
          // a video can be handed to this view while that route is open, if
          // the decoder reported its shape late.
          if (widget.playback.fullscreen.value) return;
          widget.playback.pauseIfActive(_mediaId);
        },
        child: ValueListenableBuilder<PlaybackState>(
          valueListenable: widget.playback.state,
          builder: (context, state, _) {
            final active = state.isActive(_mediaId);
            return Stack(
              fit: StackFit.expand,
              children: [
                // Shrinks into whatever the sheet leaves it, pinned to
                // the top, rather than staying full-bleed behind a panel
                // that covers most of it.
                AnimatedFractionallySizedBox(
                  // A drag has to track the finger; a sheet that opens on
                  // its own gets to animate.
                  duration: _draggingSheet
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  widthFactor: 1,
                  heightFactor: 1 - _covered,
                  child: _media(state, active),
                ),

                // A tap anywhere on the picture plays or pauses. There is no
                // separate play button sitting over the video the whole time.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePlay,
                ),

                // Not `&& !state.playing`: the engine reports `playing` the
                // moment it is told to, which is before a frame exists.
                if (active && state.buffering && !state.completed)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  ),

                _chrome(context, state, active),

                if (widget.page != null) _sheet(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _media(PlaybackState state, bool active) {
    final controller = widget.videoController;
    // `position > Duration.zero` is the same guard the inline hero uses: it
    // is what tells us a frame exists to show, rather than a black box where
    // the still used to be.
    if (active && controller != null && state.position > Duration.zero) {
      return Video(
        controller: controller,
        controls: null,
        fit: VideoFit.fullBleed,
      );
    }
    final url = widget.thumbnailUrl;
    if (url == null || url.isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    // `contain`, matching the video it stands in for, so the picture does
    // not jump size when the first frame arrives.
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : const ColoredBox(color: Colors.black),
    );
  }

  /// Everything drawn over the picture, fading as the sheet comes up.
  Widget _chrome(BuildContext context, PlaybackState state, bool active) {
    // The controls fade out faster than the sheet rises, so they are gone
    // well before it is fully up. **Pointers have to stop at the same
    // point**, not at the top of the travel: between the two, a reader
    // dragging the page past halfway would be tapping a rail they can no
    // longer see.
    final opacity = (1 - _sheetOpen * 1.6).clamp(0.0, 1.0);
    return IgnorePointer(
      ignoring: opacity <= 0,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 120),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A gradient top and bottom, because white text over a video is
            // only legible if the video is dark exactly there, and it is not.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.22, 0.55, 1],
                  colors: [
                    Color(0x8C000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xB3000000),
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),

            _topBar(context),
            if (_showPlayPause) _playPauseFlash(state, active),
            _rail(context),
            _bottomInfo(context),
            if (!widget.isLive) _scrubber(context, state, active),
          ],
        ),
      ),
    );
  }

  /// How much room the top bar takes, so the rail can keep clear of it.
  static const _topBarHeight = 52.0;

  Widget _topBar(BuildContext context) {
    // `Align`, not a bare `SafeArea`: this is a child of a stack that
    // expands its children, so the row would otherwise be handed the whole
    // height and centre itself down the middle of the picture.
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
          child: Row(
            children: [
              GTubeBackButton(onTap: widget.onBack, size: 20, box: 32),
              const Spacer(),
              if (widget.isLive) const LiveBadge(),
              // Resolution and speed. On the standard layout this lives on the
              // hero's bottom bar, which this view does not have.
              IconButton(
                key: const ValueKey('portrait-playback-settings'),
                onPressed: () => showPlaybackSettings(
                  context,
                  playback: widget.playback,
                  isLive: widget.isLive,
                ),
                icon: const Icon(
                  Icons.settings_rounded,
                  color: Colors.white,
                  size: 20,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playPauseFlash(PlaybackState state, bool active) {
    final playing = active && state.isPlaying(_mediaId);
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  /// The right-hand column. Order is deliberate: the ministry at the top
  /// where the eye starts, then the two taps a reader makes most, then the
  /// ones they make rarely, then sound at the bottom by the thumb.
  Widget _rail(BuildContext context) {
    return Positioned(
      right: 8,
      // Bounded at the top by the back arrow and bottom by the scrubber.
      // Without the top bound a `Positioned` would hand the column all the
      // height it asked for and the stack would quietly clip the overflow —
      // and the overflow is the top of the column, which is the ministry.
      // Losing follow off the top edge of a short phone is not a thing to
      // find out from a reader.
      top: MediaQuery.paddingOf(context).top + _topBarHeight,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          // Clear of the scrubber and the shut sheet below it. The scrubber
          // sits at `_sheetShut` and its touch target is taller than the
          // track it draws, so this has to clear the target, not the line.
          padding: const EdgeInsets.only(bottom: _sheetShut + 44),
          child: SingleChildScrollView(
            // Anchored at the bottom, where the thumb is, so it is the
            // ministry that moves out of reach rather than the sound. On any
            // ordinary phone the column fits and this never scrolls at all.
            reverse: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.hasCreator) ...[
                  WatchRailAvatar(
                    displayName:
                        widget.creatorName ?? widget.creatorHandle ?? '',
                    avatarUrl: widget.avatarUrl,
                    following: widget.following,
                    onTap: widget.onCreator ?? () {},
                    onFollow: widget.onFollow ?? () {},
                  ),
                  const SizedBox(height: WatchRail.gapAfterAvatar),
                ],
                WatchRailAction(
                  // Filled and brand-coloured once it is the viewer's own
                  // like: the count moving by one is easy to miss, and that
                  // is the only other sign the tap landed.
                  icon: widget.liked
                      ? IconsaxPlusBold.heart
                      : IconsaxPlusLinear.heart,
                  label: widget.likes,
                  color: widget.liked ? AppColors.brandPrimary : Colors.white,
                  onTap: widget.onLike,
                ),
                const SizedBox(height: WatchRail.gap),
                WatchRailAction(
                  icon: IconsaxPlusLinear.message,
                  label: widget.comments,
                  onTap: _openComments,
                ),
                const SizedBox(height: WatchRail.gap),
                WatchRailAction(
                  // The same glyph the feed cards use. This rail had an
                  // `archive` box, so the control that saves a video
                  // looked like a different action here than on the card
                  // the reader tapped to get here.
                  asset: AppAssets.iconFeedBookmark,
                  label: widget.saves,
                  color: widget.saved ? AppColors.brandPrimary : Colors.white,
                  onTap: widget.onSave,
                ),
                const SizedBox(height: WatchRail.gap),
                WatchRailAction(
                  icon: IconsaxPlusLinear.send_2,
                  label: AppStrings.share,
                  onTap: widget.onShare,
                ),
                if (widget.canGive) ...[
                  const SizedBox(height: WatchRail.gap),
                  WatchRailAction(
                    icon: IconsaxPlusLinear.gift,
                    label: AppStrings.give,
                    color: AppColors.brandPrimary,
                    onTap: widget.onGive,
                  ),
                ],
                const SizedBox(height: WatchRail.gap),
                ValueListenableBuilder<bool>(
                  valueListenable: widget.playback.muted,
                  builder: (context, muted, _) => WatchRailAction(
                    icon: muted
                        ? IconsaxPlusLinear.volume_slash
                        : IconsaxPlusLinear.volume_high,
                    label: muted
                        ? AppStrings.watchUnmute
                        : AppStrings.watchSound,
                    onTap: widget.playback.toggleMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The ministry, the title and the description, bottom left — clear of the
  /// rail on the right.
  Widget _bottomInfo(BuildContext context) {
    final handle = widget.creatorHandle;
    final description = widget.description?.trim();
    return Positioned(
      left: 12,
      // Leaves the rail its column.
      right: 76,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: _sheetShut + 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (handle != null && handle.isNotEmpty)
                GestureDetector(
                  onTap: widget.onCreator,
                  child: Text(
                    handle.startsWith('@') ? handle : '@$handle',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                widget.title,
                maxLines: _descriptionOpen ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () =>
                      setState(() => _descriptionOpen = !_descriptionOpen),
                  child: Text(
                    description,
                    // Shut, it is a hint that there is something to open.
                    // Open, it still stops — the whole description belongs
                    // on the page under the sheet, not over the picture.
                    maxLines: _descriptionOpen ? 6 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.35,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _scrubber(BuildContext context, PlaybackState state, bool active) {
    final total = active ? state.duration.inMilliseconds.toDouble() : 0.0;
    if (total <= 0) return const SizedBox.shrink();
    final position = state.position.inMilliseconds.toDouble().clamp(0.0, total);
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.paddingOf(context).bottom + _sheetShut,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2.5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white30,
          thumbColor: Colors.white,
          overlayColor: Colors.white24,
          trackShape: const RectangularSliderTrackShape(),
        ),
        child: Slider(
          value: position,
          max: total,
          onChanged: (v) =>
              widget.playback.seek(Duration(milliseconds: v.round())),
        ),
      ),
    );
  }

  /// The standard page, shut against the bottom edge until pulled up.
  Widget _sheet(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final shut = (_sheetShut / height).clamp(0.04, 0.3);
    _shutExtent = shut;
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (note) {
        // How far between shut and open, for the controls to fade against.
        final span = note.maxExtent - note.minExtent;
        final open = span <= 0 ? 0.0 : (note.extent - note.minExtent) / span;
        if ((open - _sheetOpen).abs() > 0.01) {
          setState(() {
            _draggingSheet = true;
            _sheetOpen = open.clamp(0.0, 1.0);
          });
        }
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: shut,
        minChildSize: shut,
        maxChildSize: PortraitWatchView.sheetMax,
        snap: true,
        builder: (context, controller) => DecoratedBox(
          decoration: const BoxDecoration(
            // A shade above the page behind it. On `base1` the panel was
            // the same black as everything else, so sliding it up read as
            // the video going out rather than a layer arriving over it.
            color: AppColors.sheetSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          // One scroll view for the handle and the page together. Shut, it
          // is 62 pixels tall and shows the handle; a drag upward from
          // there is already at offset zero, so the sheet takes the gesture
          // and rises rather than scrolling.
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [_sheetHandle(), widget.page!(context)],
          ),
        ),
      ),
    );
  }

  Widget _sheetHandle() {
    return SizedBox(
      height: _sheetShut,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // Said in words, because a bare handle on a full-screen video is
          // not obviously a handle.
          Opacity(
            opacity: (1 - _sheetOpen * 2).clamp(0.0, 1.0),
            child: Text(
              AppStrings.watchMore,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
