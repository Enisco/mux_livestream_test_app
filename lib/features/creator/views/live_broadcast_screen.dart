import 'dart:async';

import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/live_prayers_sheet.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/shared/services/live_socket_service.dart';
import 'package:test_app/shared/services/media_permissions.dart';
import 'package:test_app/features/creator/views/widgets/broadcast_preview.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/shared/services/screen_orientation.dart';
import 'package:test_app/shared/services/screen_wakelock.dart';
import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/views/widgets/live_broadcast_parts.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The broadcast itself.
class LiveBroadcastScreen extends StatefulWidget {
  const LiveBroadcastScreen({
    super.key,
    required this.mediaId,
    required this.rtmpIngestUrl,
    required this.streamKey,
    this.live,
    this.replayPolicy = ReplayPolicy.autoPublish,
    this.controller,
    this.ask,
    this.wakelock,
    this.playback,
  });

  final String mediaId;
  final String rtmpIngestUrl;
  final String streamKey;

  final LivestreamRepo? live;
  final ReplayPolicy replayPolicy;

  /// Supplied by a test; otherwise the screen makes its own.
  final ApiVideoLiveStreamController? controller;

  /// How the camera and microphone are asked for. Supplied by a test.
  final PermissionAsk? ask;

  /// What keeps the screen awake. Supplied by a test.
  final ScreenWakelock? wakelock;

  /// The app's own media playback, stopped on the way in. Supplied by a
  /// test; otherwise taken from the locator if it is registered.
  final PlaybackHandle? playback;

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();

  /// How long to wait for the backend to see the encoder before saying so.
  static const connectTimeout = Duration(seconds: 45);

  /// How long the ending overlay will wait for the backend to acknowledge.
  static const endTimeout = Duration(seconds: 20);
}

/// Where a broadcast is in its life, as this screen sees it.
enum LivePhase { preparing, connecting, live, ending, failed }

/// What "Try again" means for the failure on screen.
enum LiveRetry {
  /// Start over: ask for the camera, open it, arm, push.
  start,

  /// Arm and push again over a camera that is already running.
  reconnect,
}

/// What losing the RTMP push means, given where the broadcast had got to.
enum LiveLossAction {
  /// Before going live, a lost push is fatal for this attempt.
  fail,

  /// Once live it is a drop. The backend is already waiting for the encoder
  /// to return, so the push is made again rather than the broadcast ended.
  repush,

  /// Nothing to do — not started yet, already ending, or already failed.
  ignore;

  static LiveLossAction forPhase(LivePhase phase) => switch (phase) {
    LivePhase.connecting => fail,
    LivePhase.live => repush,
    LivePhase.preparing || LivePhase.ending || LivePhase.failed => ignore,
  };
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen>
    with WidgetsBindingObserver {
  late final _repo = widget.live ?? LivestreamRepo();
  late final _wakelock = widget.wakelock ?? screenWakelock;

  /// Nullable on purpose: the locator is not set up in a widget test, and
  /// the same `isRegistered` guard is how the live socket is reached.
  late final PlaybackHandle? _playback =
      widget.playback ??
      (GetIt.instance.isRegistered<PlaybackController>()
          ? GetIt.instance<PlaybackController>()
          : null);
  late final ApiVideoLiveStreamController _controller =
      widget.controller ??
      ApiVideoLiveStreamController(
        initialAudioConfig: AudioConfig(),
        initialVideoConfig: VideoConfig.withDefaultBitrate(),
        // A creator going live is talking to their own congregation, so the
        // camera that should already be pointing at them is the front one.
        initialCameraPosition: CameraPosition.front,
        onConnectionSuccess: _onRtmpUp,
        onConnectionFailed: _onRtmpFailed,
        onDisconnection: _onRtmpDown,
        onError: _onRtmpError,
      );

  LivePhase _phase = LivePhase.preparing;
  String? _failure;

  /// Whether the failure on screen is one only Settings can clear.
  bool _failureNeedsSettings = false;

  /// What "Try again" has to do about the failure on screen.
  LiveRetry _retryAs = LiveRetry.reconnect;

  LivestreamStudio _studio = LivestreamStudio.empty;
  Timer? _poll;
  StreamSubscription<LiveEvent>? _liveEvents;
  StreamSubscription<void>? _liveReconnects;
  Timer? _tick;
  Duration _elapsed = Duration.zero;

  /// 3, 2, 1, then gone.
  int _countdown = 0;
  Timer? _countdownTimer;

  bool _muted = false;
  bool _chatShown = true;
  bool _pushing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // For the whole life of the screen, not just while on air: a creator
    // framing a shot or reading a failure is no more likely to be touching
    // the phone than one who is mid-sermon, and one hold paired with one
    // release has no state machine to get wrong.
    unawaited(_wakelock.hold());
    // Nothing stopped the feed when a broadcast started, so a video still
    // playing kept its audio and the microphone put it straight into the
    // livestream.
    unawaited(_playback?.stop());
    // Asked here as well as in `_begin`, as early as the screen exists, so
    // the interface has the longest possible head start to finish rotating
    // before the encoder reads it.
    unawaited(ScreenOrientation.lockUpright());
    _begin();
  }

  @override
  void dispose() {
    unawaited(_wakelock.release());
    unawaited(ScreenOrientation.restore());
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _tick?.cancel();
    _connectWatchdog?.cancel();
    _countdownTimer?.cancel();
    unawaited(_liveEvents?.cancel());
    unawaited(_liveReconnects?.cancel());
    if (GetIt.instance.isRegistered<LiveSocketService>()) {
      GetIt.instance<LiveSocketService>().unsubscribeStudio(widget.mediaId);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A creator sent to Settings comes back to the error they left behind;
    // the permission they just granted is the whole reason they went. iOS
    // usually restarts the app on that change and never gets here, but
    // Android does, and it should not need a second tap.
    if (state == AppLifecycleState.resumed &&
        _phase == LivePhase.failed &&
        _retryAs == LiveRetry.start) {
      unawaited(_retry());
      return;
    }
    if (!_controller.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _controller.startPreview();
      // The snapshot is the authority after a spell in the background.
      _refresh();
    }
  }

  // ---- getting on air ----------------------------------------------------

  Future<void> _begin() async {
    // The lock went out in `initState`; this waits for the screen to have
    // finished turning.
    await ScreenOrientation.awaitUpright();
    if (!mounted) return;

    final access = await MediaPermissions.cameraAndMicrophone(ask: widget.ask);
    if (!mounted) return;
    if (!access.isGranted) {
      // Blocked is a different dead end from refused: iOS asks once, so
      // "Try again" against a standing no is a button that can only fail.
      return _fail(
        access.needsSettings
            ? AppStrings.goLiveCameraBlocked
            : AppStrings.goLiveNeedsCamera,
        settings: access.needsSettings,
        retryAs: LiveRetry.start,
      );
    }

    try {
      // `initialize()` guards nothing of its own: it invokes the plugin's
      // `create` again, overwrites `_eventSubscription` without cancelling
      // the old one, and leaves a second native session running.
      if (!_controller.isInitialized) await _controller.initialize();
      await _controller.startPreview();
    } catch (e) {
      // Not a permission problem — the permission was just granted. Saying
      // so sent creators to a Settings screen with nothing wrong on it.
      logger.e('Camera init failed', error: e);
      if (mounted) {
        _fail(AppStrings.goLiveCameraFailed, retryAs: LiveRetry.start);
      }
      return;
    }
    if (!mounted) return;

    try {
      // Nothing may push until the window is open.
      await _repo.armIngest(widget.mediaId);
      if (!mounted) return;
      setState(() => _phase = LivePhase.connecting);
      _armConnectWatchdog();

      await _push();
      // A push that could not even open is not worth asking the backend to
      // wait fifteen minutes for.
      if (!mounted || _phase == LivePhase.failed) return;
      await _repo.start(widget.mediaId);
      unawaited(_startWatching());
    } on LiveException catch (e) {
      if (mounted) _fail(_wording(e));
    }
  }

  Future<void> _push() async {
    if (_pushing) return;
    _pushing = true;
    try {
      await _controller.startStreaming(
        streamKey: widget.streamKey,
        url: widget.rtmpIngestUrl,
      );
    } catch (e) {
      logger.e('RTMP push failed', error: e);
      if (mounted) _fail(AppStrings.goLiveRejected);
    } finally {
      // This used to latch on for the life of the screen, so a second push
      // — after a drop — returned without doing anything.
      _pushing = false;
    }
  }

  Timer? _connectWatchdog;

  void _armConnectWatchdog() {
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(LiveBroadcastScreen.connectTimeout, () {
      if (mounted && _phase == LivePhase.connecting) {
        _fail(AppStrings.goLiveNoEncoder);
      }
    });
  }

  void _fail(
    String message, {
    bool settings = false,
    LiveRetry retryAs = LiveRetry.reconnect,
  }) {
    _connectWatchdog?.cancel();
    // Nothing on the failure screen reads the counters, and the snapshot
    // poll otherwise kept asking every few seconds for as long as the
    // creator looked at the error.
    _poll?.cancel();
    _poll = null;
    setState(() {
      _phase = LivePhase.failed;
      _failure = message;
      _failureNeedsSettings = settings;
      _retryAs = retryAs;
    });
  }

  // ---- what the counters read --------------------------------------------

  /// Follows the studio room, and keeps a slow snapshot underneath it.
  Future<void> _startWatching() async {
    await _refresh();

    // The snapshot poll below is the safety net, so a socket that cannot be
    // reached degrades to the old behaviour rather than stopping a broadcast.
    if (!GetIt.instance.isRegistered<LiveSocketService>()) {
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
      return;
    }
    final socket = GetIt.instance<LiveSocketService>();
    try {
      await socket.connect();
      socket.subscribeStudio(widget.mediaId);
    } catch (e) {
      logger.w('Live socket unavailable; falling back to polling', error: e);
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
      return;
    }

    _liveEvents = socket.events.listen(_onLiveEvent);
    // The contract asks for a refetch after a reconnect, because anything
    // that happened while the socket was away was never delivered.
    _liveReconnects = socket.reconnects.listen((_) => unawaited(_refresh()));

    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _onLiveEvent(LiveEvent event) {
    if (event.streamId.isNotEmpty && event.streamId != widget.mediaId) return;
    if (!mounted) return;

    switch (event.type) {
      case LiveEventType.viewerCount:
        setState(() {
          _studio = _studio.copyWith(
            viewerCount: event.viewerCount,
            peakViewerCount: event.peakViewerCount,
          );
        });
      case LiveEventType.statusChanged:
        final runtime = LiveRuntime.parse(event.status);
        setState(() => _studio = _studio.copyWith(runtime: runtime));
        if (runtime.isOnAir && _phase == LivePhase.connecting) {
          _onAir(DateTime.tryParse(event.data['startedAt'] as String? ?? ''));
        }
        // The encoder dropping is not the same as ending, but saying LIVE
        // through either would be a lie.
        if (runtime == LiveRuntime.reconnecting && _phase == LivePhase.live) {
          setState(() => _phase = LivePhase.connecting);
          _armConnectWatchdog();
        }
        if (runtime == LiveRuntime.ended) unawaited(_refresh());
      case LiveEventType.metricsUpdated:
      case LiveEventType.encoderStatusChanged:
      case LiveEventType.ingestStatusChanged:
      case LiveEventType.replayStatusChanged:
        // Shapes differ enough from the snapshot that re-reading it is both
        // simpler and safer than mapping each one by hand.
        unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    try {
      final studio = await _repo.studio(widget.mediaId);
      if (!mounted) return;
      setState(() => _studio = studio);

      if (studio.runtime.isOnAir && _phase == LivePhase.connecting) {
        _onAir(studio.startedAt);
      }
      // The encoder can drop mid-broadcast. Saying LIVE while the backend
      // is waiting for it back would be a lie.
      if (studio.runtime == LiveRuntime.reconnecting &&
          _phase == LivePhase.live) {
        setState(() => _phase = LivePhase.connecting);
        _armConnectWatchdog();
      }
    } catch (e) {
      // A dropped poll is not worth interrupting a broadcast for.
      logger.w('Studio snapshot failed', error: e);
    }
  }

  void _onAir(DateTime? startedAt) {
    // The backend has seen the encoder; nothing left to wait for.
    _connectWatchdog?.cancel();
    setState(() {
      _phase = LivePhase.live;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _countdown -= 1);
      if (_countdown <= 0) timer.cancel();
    });

    final began = startedAt ?? DateTime.now();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(began));
    });
  }

  // ---- stopping ----------------------------------------------------------

  Future<void> _askToEnd() async {
    final confirmed = await EndLivestreamSheet.show(
      context,
      studio: _studio,
      replayPolicy: widget.replayPolicy,
    );
    if (!confirmed || !mounted) return;
    await _end();
  }

  Future<void> _end() async {
    // Ending is already under way; a second run would stop the stream
    // twice and pop twice, and the second pop takes the screen underneath.
    if (_phase == LivePhase.ending) return;

    setState(() => _phase = LivePhase.ending);
    _poll?.cancel();
    _tick?.cancel();
    try {
      await _controller.stopStreaming();
    } catch (_) {
      // The camera is stopping either way.
    }
    try {
      await _repo.end(widget.mediaId).timeout(LiveBroadcastScreen.endTimeout);
    } on LiveException catch (e) {
      logger.w('End refused', error: e);
    } on TimeoutException catch (e) {
      // Leaving is better than holding someone on a spinner that has no way
      // out.
      logger.w('End not acknowledged in time', error: e);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  /// Backing out before going live. The session is cancelled rather than
  /// ended: it never happened, and leaving it would hold the encoder.
  Future<void> _abandon() async {
    _poll?.cancel();
    try {
      await _controller.stopStreaming();
    } catch (_) {}
    await _repo.cancel(widget.mediaId);
    await _repo.disableIngest(widget.mediaId);
    if (!mounted) return;
    Navigator.pop(context, false);
  }

  void _onRtmpUp() {
    logger.d('RTMP connected');
    // Reaching the server is not being live — the backend still has to see
    // the encoder — so the watchdog keeps running until it does.
  }

  void _onRtmpFailed(String reason) {
    logger.e('RTMP connection failed: $reason');
    if (mounted && _phase == LivePhase.connecting) {
      _fail(AppStrings.goLiveRejected);
    }
  }

  void _onRtmpDown() {
    logger.d('RTMP disconnected');
    _handleTransportLoss(AppStrings.goLiveDropped);
  }

  /// An error raised *after* the connection opened — a write that failed, a
  /// socket that broke.
  void _onRtmpError(Exception error) {
    logger.e('Live stream error', error: error);
    _handleTransportLoss(AppStrings.goLiveDropped);
  }

  /// The push stopped reaching the server.
  void _handleTransportLoss(String message) {
    if (!mounted) return;
    switch (LiveLossAction.forPhase(_phase)) {
      case LiveLossAction.fail:
        _fail(message);
      case LiveLossAction.repush:
        setState(() => _phase = LivePhase.connecting);
        _armConnectWatchdog();
        unawaited(_repush());
      case LiveLossAction.ignore:
        break;
    }
  }

  /// Another go at the same session.
  Future<void> _retry() async {
    if (_retryAs == LiveRetry.start) {
      // Nothing was ever armed or pushed; this is the first attempt again.
      setState(() {
        _phase = LivePhase.preparing;
        _failure = null;
        _failureNeedsSettings = false;
      });
      return _begin();
    }
    setState(() {
      _phase = LivePhase.connecting;
      _failure = null;
      _failureNeedsSettings = false;
    });
    _armConnectWatchdog();
    try {
      await _repo.armIngest(widget.mediaId);
      if (!mounted || _phase != LivePhase.connecting) return;
      await _repush();
      if (!mounted || _phase != LivePhase.connecting) return;
      await _repo.start(widget.mediaId);
      unawaited(_startWatching());
    } on LiveException catch (e) {
      if (mounted) _fail(_wording(e));
    }
  }

  Future<void> _repush() async {
    try {
      await _controller.stopStreaming();
    } catch (e) {
      logger.w('Could not stop the dead stream', error: e);
    }
    if (!mounted || _phase != LivePhase.connecting) return;
    await _push();
  }

  static String _wording(LiveException e) => switch (e.failure) {
    LiveFailure.noPermission => AppStrings.goLiveNeedsCamera,
    LiveFailure.conflict => AppStrings.goLiveConflict,
    LiveFailure.notArmed => AppStrings.goLiveNotArmed,
    LiveFailure.network => AppStrings.newMediaNetwork,
    LiveFailure.rejected => e.message ?? AppStrings.goLiveRejected,
  };

  // ---- the screen --------------------------------------------------------

  @override
  Widget build(BuildContext context) => PopScope(
    // Leaving mid-broadcast has to go through the sheet.
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      switch (_phase) {
        case LivePhase.live:
          _askToEnd();
        case LivePhase.ending:
          // Already on its way out; nothing to decide.
          break;
        case LivePhase.preparing || LivePhase.connecting || LivePhase.failed:
          _abandon();
      }
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller.isInitialized)
            BroadcastPreview(controller: _controller)
          else
            const ColoredBox(color: Colors.black),
          if (_phase == LivePhase.live) LiveCountdown(value: _countdown),
          SafeArea(
            child: switch (_phase) {
              LivePhase.preparing || LivePhase.connecting => _connecting(),
              LivePhase.failed => _failed(),
              LivePhase.live => _onAirOverlay(),
              // Ending has the screen to itself, below and unsafe-area'd.
              LivePhase.ending => const SizedBox.shrink(),
            },
          ),
          // Over the preview, the countdown and the notch alike.
          if (_phase == LivePhase.ending) _ending(),
        ],
      ),
    ),
  );

  Widget _connecting() => Container(
    color: AppColors.overlayDark,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44.s,
          height: 44.s,
          child: CircularProgressIndicator(
            strokeWidth: 3.s,
            color: AppColors.brandPrimary,
          ),
        ),
        SizedBox(height: 22.s),
        Text(
          AppStrings.goLiveConnecting,
          style: AppStyles.label(15, weight: AppStyles.bold),
        ),
        SizedBox(height: 8.s),
        Text(
          AppStrings.goLiveConnectingBody,
          textAlign: TextAlign.center,
          style: AppStyles.body(
            13,
            color: AppColors.neutral400,
            lineHeight: 18 / 13,
          ),
        ),
        SizedBox(height: 26.s),
        GestureDetector(
          key: const ValueKey('live-cancel'),
          behavior: HitTestBehavior.opaque,
          onTap: _abandon,
          child: Text(
            AppStrings.goLiveCancel,
            style: AppStyles.label(13, color: AppColors.neutral300),
          ),
        ),
      ],
    ),
  );

  /// No way out of this one on purpose: the broadcast is already stopping
  /// and there is nothing left to decide. [LiveBroadcastScreen.endTimeout]
  /// is what stops it being a trap.
  Widget _ending() => Container(
    key: const ValueKey('live-ending'),
    color: AppColors.overlayDark,
    alignment: Alignment.center,
    padding: EdgeInsets.symmetric(horizontal: 32.s),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44.s,
          height: 44.s,
          child: CircularProgressIndicator(
            strokeWidth: 3.s,
            color: AppColors.brandPrimary,
          ),
        ),
        SizedBox(height: 22.s),
        Text(
          AppStrings.goLiveEnding,
          style: AppStyles.label(15, weight: AppStyles.bold),
        ),
        SizedBox(height: 8.s),
        Text(
          AppStrings.goLiveEndingBody,
          textAlign: TextAlign.center,
          style: AppStyles.body(
            13,
            color: AppColors.neutral400,
            lineHeight: 18 / 13,
          ),
        ),
      ],
    ),
  );

  Widget _failed() => Container(
    color: AppColors.overlayDark,
    alignment: Alignment.center,
    padding: EdgeInsets.symmetric(horizontal: 32.s),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          color: AppColors.destructive,
          size: 30.s,
        ),
        SizedBox(height: 16.s),
        Text(
          _failure ?? AppStrings.goLiveRejected,
          textAlign: TextAlign.center,
          style: AppStyles.body(
            14,
            color: AppColors.neutral200,
            lineHeight: 20 / 14,
          ),
        ),
        SizedBox(height: 22.s),
        if (_failureNeedsSettings) ...[
          GestureDetector(
            key: const ValueKey('live-failed-settings'),
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(openAppSettings()),
            child: Text(
              AppStrings.openSettings,
              style: AppStyles.label(
                13,
                weight: AppStyles.bold,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          SizedBox(height: 14.s),
        ],
        // A failed connection is usually a network blip, and the session is
        // still sitting there waiting — so trying again should not mean
        // setting the whole broadcast up a second time.
        GestureDetector(
          key: const ValueKey('live-failed-retry'),
          behavior: HitTestBehavior.opaque,
          onTap: _retry,
          child: Text(
            AppStrings.feedRetry,
            style: AppStyles.label(
              13,
              weight: AppStyles.bold,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
        SizedBox(height: 14.s),
        GestureDetector(
          key: const ValueKey('live-failed-back'),
          behavior: HitTestBehavior.opaque,
          onTap: _abandon,
          child: Text(
            AppStrings.goLiveCancel,
            style: AppStyles.label(
              13,
              weight: AppStyles.bold,
              color: AppColors.neutral400,
            ),
          ),
        ),
      ],
    ),
  );

  /// The requests themselves, which the socket does not carry.
  Future<void> _openPrayers() =>
      showLivePrayersSheet(context, mediaId: widget.mediaId, repo: _repo);

  Widget _onAirOverlay() => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 0),
        child: LiveStatBar(
          likes: _studio.likeCount,
          viewers: _studio.viewerCount,
          giving: givingLabel(_studio),
          prayers: _studio.prayerCount,
          onOpenPrayers: () => unawaited(_openPrayers()),
          onFlipCamera: () => _controller.switchCamera(),
        ),
      ),
      const Spacer(),
      if (_chatShown)
        Padding(
          padding: EdgeInsets.fromLTRB(16.s, 0, 60.s, 10.s),
          child: const _LiveChat(),
        ),
      Padding(
        padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 12.s),
        child: Row(
          children: [
            LiveRoundButton(
              buttonKey: const ValueKey('live-mic'),
              icon: _muted
                  ? HugeIcons.strokeRoundedMicOff01
                  : HugeIcons.strokeRoundedMic01,
              active: !_muted,
              onTap: () async {
                await _controller.setIsMuted(!_muted);
                if (mounted) setState(() => _muted = !_muted);
              },
            ),
            SizedBox(width: 10.s),
            LiveRoundButton(
              buttonKey: const ValueKey('live-chat-toggle'),
              icon: HugeIcons.strokeRoundedMessage01,
              onTap: () => setState(() => _chatShown = !_chatShown),
            ),
            // The clock takes the slack and gives it back: on a small phone
            // a three-hour broadcast plus both controls and End overran the
            // row by a few pixels.
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.s),
                child: Text(
                  formatElapsed(_elapsed),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.label(13, weight: AppStyles.bold),
                ),
              ),
            ),
            GestureDetector(
              key: const ValueKey('live-end'),
              behavior: HitTestBehavior.opaque,
              onTap: _phase == LivePhase.ending ? null : _askToEnd,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 22.s, vertical: 11.s),
                decoration: BoxDecoration(
                  color: AppColors.destructive,
                  borderRadius: BorderRadius.circular(999.s),
                ),
                child: Text(
                  AppStrings.goLiveEnd,
                  style: AppStyles.label(14, weight: AppStyles.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The chat the design runs along the foot of the broadcast.
class _LiveChat extends StatelessWidget {
  const _LiveChat();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      key: const ValueKey('live-chat-placeholder'),
      padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 8.s),
      decoration: BoxDecoration(
        color: AppColors.overlayMid,
        borderRadius: BorderRadius.circular(999.s),
      ),
      child: Text(
        AppStrings.goLiveChatUnavailable,
        style: AppStyles.label(12, color: AppColors.neutral300),
      ),
    ),
  );
}
