import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/app_styles.dart';
import '../services/mux_service.dart';
import 'player_screen.dart';

enum _Phase {
  cameraSetup,
  cameraLoading,
  cameraError,
  idle,
  creating,
  live,
  ending,
}

class StartLivestreamScreen extends StatefulWidget {
  const StartLivestreamScreen({super.key});

  @override
  State<StartLivestreamScreen> createState() => _StartLivestreamScreenState();
}

class _StartLivestreamScreenState extends State<StartLivestreamScreen> {
  _Phase _phase = _Phase.cameraSetup;

  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;

  MuxLiveStream? _muxStream;
  bool _isStreaming = false;
  bool _streamKeyVisible = false;
  Timer? _pollTimer;
  String _statusText = AppStrings.statusIdle;
  bool _statusActive = false;

  final _muxService = MuxService();

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
  }

  Future<void> _startCamera() async {
    setState(() => _phase = _Phase.cameraLoading);
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });
      _localStream = stream;
      _localRenderer.srcObject = stream;
      if (mounted) setState(() => _phase = _Phase.idle);
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.cameraError);
    }
  }

  Future<void> _createStream() async {
    setState(() => _phase = _Phase.creating);
    try {
      final stream = await _muxService.createLiveStream();
      _muxStream = stream;
      if (mounted) {
        setState(() => _phase = _Phase.live);
        _startPolling();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create stream: $e')),
      );
    }
  }

  Future<void> _startStreaming() async {
    final muxStream = _muxStream;
    final localStream = _localStream;
    if (muxStream == null || localStream == null) return;

    try {
      final pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      });
      _peerConnection = pc;

      for (final track in localStream.getTracks()) {
        await pc.addTrack(track, localStream);
      }

      final gatheringCompleter = Completer<void>();
      pc.onIceGatheringState = (RTCIceGatheringState state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !gatheringCompleter.isCompleted) {
          gatheringCompleter.complete();
        }
      };

      final offer = await pc.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });
      await pc.setLocalDescription(offer);

      // Wait for ICE gathering (10s timeout)
      await gatheringCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (!gatheringCompleter.isCompleted) gatheringCompleter.complete();
        },
      );

      final localDesc = await pc.getLocalDescription();
      if (localDesc?.sdp == null) throw Exception('No local SDP');

      final answerSdp = await _muxService.whipHandshake(
        muxStream.streamKey,
        localDesc!.sdp!,
      );
      await pc.setRemoteDescription(RTCSessionDescription(answerSdp, 'answer'));

      if (mounted) setState(() => _isStreaming = true);
    } catch (e) {
      await _peerConnection?.close();
      _peerConnection = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start streaming: $e')),
        );
      }
    }
  }

  Future<void> _stopStreaming() async {
    await _peerConnection?.close();
    _peerConnection = null;
    if (mounted) setState(() => _isStreaming = false);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final stream = _muxStream;
    if (stream == null || !mounted) return;
    try {
      final status = await _muxService.getStreamStatus(stream.id);
      if (!mounted) return;
      setState(() {
        _statusActive = status == 'active';
        _statusText = _statusActive ? AppStrings.statusActive : AppStrings.statusIdle;
      });
    } catch (_) {}
  }

  Future<void> _endStream() async {
    final stream = _muxStream;
    if (stream == null) return;
    await _stopStreaming();
    _pollTimer?.cancel();
    setState(() => _phase = _Phase.ending);
    try {
      await _muxService.disableLiveStream(stream.id);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _muxStream = null;
      _statusText = AppStrings.statusIdle;
      _statusActive = false;
      _phase = _Phase.idle;
    });
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.copied),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _peerConnection?.close();
    _localStream?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.startLiveTitle),
        backgroundColor: AppColors.background,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.cameraSetup:
      case _Phase.cameraError:
        return _buildCameraSetup();
      case _Phase.cameraLoading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case _Phase.creating:
      case _Phase.ending:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                _phase == _Phase.creating
                    ? AppStrings.creatingStream
                    : AppStrings.endingStream,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      case _Phase.idle:
      case _Phase.live:
        return _buildMain();
    }
  }

  Widget _buildCameraSetup() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.videocam_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            AppStrings.cameraPermNeeded,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _phase == _Phase.cameraError
                ? AppStrings.cameraPermDeniedBody
                : AppStrings.cameraPermBody,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_phase == _Phase.cameraError)
            OutlinedButton(
              onPressed: openAppSettings,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(AppStrings.openSettings),
            )
          else
            FilledButton.icon(
              onPressed: _startCamera,
              icon: const Icon(Icons.videocam_rounded),
              label: const Text('Enable Camera'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMain() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCameraPreview(),
          const SizedBox(height: 16),
          if (_phase == _Phase.idle)
            FilledButton.icon(
              onPressed: _createStream,
              icon: const Icon(Icons.live_tv_rounded),
              label: const Text(AppStrings.goLive),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          else ...[
            _buildStatusBadge(),
            const SizedBox(height: 16),
            _buildCredentials(),
            const SizedBox(height: 16),
            _buildStreamingToggle(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PlayerScreen.network(networkUrl: _muxStream!.hlsUrl),
                ),
              ),
              icon: const Icon(Icons.visibility_rounded),
              label: const Text(AppStrings.watchStream),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _endStream,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text(AppStrings.endStream),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surface),
            RTCVideoView(
              _localRenderer,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
            if (_isStreaming)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Row(
      children: [
        Text(
          '${AppStrings.streamStatus}: ',
          style: AppStyles.credLabel,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _statusActive
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  _statusActive ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          child: Text(
            _statusText.toUpperCase(),
            style: AppStyles.streamStatusBadge.copyWith(
              color:
                  _statusActive ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCredentials() {
    final s = _muxStream!;
    return Column(
      children: [
        _CredentialRow(
          label: AppStrings.rtmpUrl,
          value: s.rtmpIngestUrl,
          onCopy: () => _copyToClipboard(s.rtmpIngestUrl),
        ),
        const SizedBox(height: 8),
        _CredentialRow(
          label: AppStrings.streamKey,
          value: s.streamKey,
          obscure: !_streamKeyVisible,
          onCopy: () => _copyToClipboard(s.streamKey),
          trailing: TextButton(
            onPressed: () =>
                setState(() => _streamKeyVisible = !_streamKeyVisible),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _streamKeyVisible
                  ? AppStrings.hideStreamKey
                  : AppStrings.showStreamKey,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _CredentialRow(
          label: AppStrings.playbackUrl,
          value: s.hlsUrl,
          onCopy: () => _copyToClipboard(s.hlsUrl),
        ),
      ],
    );
  }

  Widget _buildStreamingToggle() {
    return _isStreaming
        ? OutlinedButton.icon(
            onPressed: _stopStreaming,
            icon: const Icon(Icons.stop_rounded),
            label: const Text(AppStrings.stopStreaming),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        : FilledButton.icon(
            onPressed: _startStreaming,
            icon: const Icon(Icons.videocam_rounded),
            label: const Text(AppStrings.startStreaming),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.obscure = false,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label.toUpperCase(), style: AppStyles.credLabel),
              const Spacer(),
              ?trailing,
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onCopy,
                child: const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            obscure ? '•' * value.length.clamp(0, 32) : value,
            style: AppStyles.credValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
