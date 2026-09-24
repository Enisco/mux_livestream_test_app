import 'dart:async';

import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/views/widgets/live_broadcast_parts.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The broadcast itself.
///
/// The camera pushes RTMP straight to Mux with [ApiVideoLiveStreamController],
/// the same controller the older `StartLivestreamScreen` uses. What is new
/// here is the order around it, which the contract requires and that screen
/// never did:
///
///  * **arm** the ingest window before pushing — Mux refuses encoder data
///    while ingest is disabled, and it is disabled by default;
///  * **start** the session, which sits at `connecting` until the provider
///    sees the encoder;
///  * poll the studio snapshot for the counters, because the contract
///    carries them over Socket.IO and the app has no socket client
///    (OPEN_ISSUES 35);
///  * **end** with a reason, rather than just stopping the camera.
///
/// Leaving without going live cancels the session, so a half-made broadcast
/// is never left holding the encoder.
class LiveBroadcastScreen extends StatefulWidget {
  const LiveBroadcastScreen({
    super.key,
    required this.mediaId,
    required this.rtmpIngestUrl,
    required this.streamKey,
    this.live,
    this.replayPolicy = ReplayPolicy.autoPublish,
    this.controller,
  });

  final String mediaId;
  final String rtmpIngestUrl;
  final String streamKey;

  final LivestreamRepo? live;
  final ReplayPolicy replayPolicy;

  /// Supplied by a test; otherwise the screen makes its own.
  final ApiVideoLiveStreamController? controller;

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

enum _Phase { preparing, connecting, live, ending, failed }

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen>
    with WidgetsBindingObserver {
  late final _repo = widget.live ?? LivestreamRepo();
  late final ApiVideoLiveStreamController _controller =
      widget.controller ??
      ApiVideoLiveStreamController(
        initialAudioConfig: AudioConfig(),
        initialVideoConfig: VideoConfig.withDefaultBitrate(),
        onConnectionSuccess: _onRtmpUp,
        onConnectionFailed: _onRtmpFailed,
        onDisconnection: _onRtmpDown,
        onError: _onRtmpError,
      );

  _Phase _phase = _Phase.preparing;
  String? _failure;

  LivestreamStudio _studio = LivestreamStudio.empty;
  Timer? _poll;
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
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _tick?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _controller.startPreview();
      // The snapshot is the authority after a spell in the background.
      _refresh();
    }
  }

  // ---- getting on air ----------------------------------------------------

  Future<void> _begin() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!mounted) return;
    if (!camera.isGranted || !mic.isGranted) {
      return _fail(AppStrings.goLiveNeedsCamera);
    }

    try {
      await _controller.initialize();
      await _controller.startPreview();
    } catch (e) {
      logger.e('Camera init failed', error: e);
      if (mounted) _fail(AppStrings.goLiveNeedsCamera);
      return;
    }
    if (!mounted) return;

    try {
      // Nothing may push until the window is open.
      await _repo.armIngest(widget.mediaId);
      if (!mounted) return;
      setState(() => _phase = _Phase.connecting);

      await _push();
      // A push that could not even open is not worth asking the backend to
      // wait fifteen minutes for.
      if (!mounted || _phase == _Phase.failed) return;
      await _repo.start(widget.mediaId);
      _startPolling();
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
    }
  }

  void _fail(String message) {
    setState(() {
      _phase = _Phase.failed;
      _failure = message;
    });
  }

  // ---- what the counters read --------------------------------------------

  void _startPolling() {
    _refresh();
    // The contract publishes these over a socket; polling is what the app
    // can do today, and four seconds is gentle enough to keep up with.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final studio = await _repo.studio(widget.mediaId);
      if (!mounted) return;
      setState(() => _studio = studio);

      if (studio.runtime.isOnAir && _phase == _Phase.connecting) {
        _onAir(studio.startedAt);
      }
      // The encoder can drop mid-broadcast. Saying LIVE while the backend
      // is waiting for it back would be a lie.
      if (studio.runtime == LiveRuntime.reconnecting && _phase == _Phase.live) {
        setState(() => _phase = _Phase.connecting);
      }
    } catch (e) {
      // A dropped poll is not worth interrupting a broadcast for.
      logger.w('Studio snapshot failed', error: e);
    }
  }

  void _onAir(DateTime? startedAt) {
    setState(() {
      _phase = _Phase.live;
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
    setState(() => _phase = _Phase.ending);
    _poll?.cancel();
    _tick?.cancel();
    try {
      await _controller.stopStreaming();
    } catch (_) {
      // The camera is stopping either way.
    }
    try {
      await _repo.end(widget.mediaId);
    } on LiveException catch (e) {
      logger.w('End refused', error: e);
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

  void _onRtmpUp() => logger.d('RTMP connected');

  void _onRtmpFailed(String reason) {
    logger.e('RTMP connection failed: $reason');
    if (mounted && _phase == _Phase.connecting) {
      _fail(AppStrings.goLiveRejected);
    }
  }

  void _onRtmpDown() => logger.d('RTMP disconnected');

  void _onRtmpError(Exception error) =>
      logger.e('Live stream error', error: error);

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
        case _Phase.live:
          _askToEnd();
        case _Phase.ending:
          // Already on its way out; nothing to decide.
          break;
        case _Phase.preparing || _Phase.connecting || _Phase.failed:
          _abandon();
      }
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller.isInitialized)
            ApiVideoCameraPreview(controller: _controller)
          else
            const ColoredBox(color: Colors.black),
          if (_phase == _Phase.live) LiveCountdown(value: _countdown),
          SafeArea(
            child: switch (_phase) {
              _Phase.preparing || _Phase.connecting => _connecting(),
              _Phase.failed => _failed(),
              _Phase.live || _Phase.ending => _onAirOverlay(),
            },
          ),
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
        GestureDetector(
          key: const ValueKey('live-failed-back'),
          behavior: HitTestBehavior.opaque,
          onTap: _abandon,
          child: Text(
            AppStrings.goLiveCancel,
            style: AppStyles.label(
              13,
              weight: AppStyles.bold,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _onAirOverlay() => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 0),
        child: Row(
          children: [
            const LivePill(),
            SizedBox(width: 8.s),
            LiveStatPill(
              pillKey: const ValueKey('live-likes'),
              icon: HugeIcons.strokeRoundedThumbsUp,
              value: '${_studio.likeCount}',
            ),
            SizedBox(width: 8.s),
            LiveStatPill(
              pillKey: const ValueKey('live-viewers'),
              icon: HugeIcons.strokeRoundedView,
              value: '${_studio.viewerCount}',
            ),
            SizedBox(width: 8.s),
            Flexible(
              child: LiveStatPill(
                pillKey: const ValueKey('live-giving'),
                icon: HugeIcons.strokeRoundedGift,
                value: givingLabel(_studio),
              ),
            ),
            const Spacer(),
            LiveRoundButton(
              buttonKey: const ValueKey('live-flip'),
              icon: HugeIcons.strokeRoundedCamera01,
              onTap: () => _controller.switchCamera(),
            ),
          ],
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
            const Spacer(),
            Text(
              formatElapsed(_elapsed),
              style: AppStyles.label(13, weight: AppStyles.bold),
            ),
            SizedBox(width: 12.s),
            GestureDetector(
              key: const ValueKey('live-end'),
              behavior: HitTestBehavior.opaque,
              onTap: _phase == _Phase.ending ? null : _askToEnd,
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
///
/// Comments on a livestream are ordinary media comments, and the app
/// already reads and writes them — but nothing pushes them, and there is no
/// live chat channel in the contract at all (OPEN_ISSUES 37). Rather than
/// invent messages, this says plainly that it is not wired yet.
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
