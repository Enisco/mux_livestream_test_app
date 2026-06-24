import 'dart:async';

import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/app_styles.dart';
import '../core/logger.dart';
import '../features/creator/repo/creator_repo.dart';
import '../utils/local_storage.dart';
import 'player_screen.dart';

// Credentials loaded from LocalStorage after "Go Live" is tapped.
class _StreamCredentials {
  final String creatorId;
  final String rtmpIngestUrl;
  final String streamKey;
  final String liveMediaId;
  final String muxLiveStreamId;

  const _StreamCredentials({
    required this.creatorId,
    required this.rtmpIngestUrl,
    required this.streamKey,
    required this.liveMediaId,
    required this.muxLiveStreamId,
  });
}

enum _Phase { initializing, error, idle, creating, live, ending }

class StartLivestreamScreen extends StatefulWidget {
  const StartLivestreamScreen({super.key});

  @override
  State<StartLivestreamScreen> createState() => _StartLivestreamScreenState();
}

class _StartLivestreamScreenState extends State<StartLivestreamScreen>
    with WidgetsBindingObserver {
  late final ApiVideoLiveStreamController _controller;

  _Phase _phase = _Phase.initializing;
  String? _initError;

  _StreamCredentials? _credentials;
  bool _isStreaming = false;
  bool _streamKeyVisible = false;
  String? _playbackUrl;
  String? _sessionId;

  String _clientSessionId() =>
      _sessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = ApiVideoLiveStreamController(
      initialAudioConfig: AudioConfig(),
      initialVideoConfig: VideoConfig.withDefaultBitrate(),
      onConnectionSuccess: _onConnectionSuccess,
      onConnectionFailed: _onConnectionFailed,
      onDisconnection: _onDisconnection,
      onError: _onError,
    );

    _controller
        .initialize()
        .then((_) async {
          await _controller.startPreview();
          if (mounted) setState(() => _phase = _Phase.idle);
        })
        .catchError((Object e) {
          logger.e('Camera/mic init failed', error: e);
          if (mounted) {
            setState(() {
              _phase = _Phase.error;
              _initError = e.toString();
            });
          }
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.startPreview();
    }
  }

  // ── RTMP event callbacks ─────────────────────────────────────────────────────

  void _onConnectionSuccess() {
    logger.d('RTMP connected ✓');
    if (mounted) setState(() => _isStreaming = true);
  }

  void _onConnectionFailed(String reason) {
    logger.e('RTMP connection failed: $reason');
    if (!mounted) return;
    setState(() => _isStreaming = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Connection failed: $reason')));
  }

  void _onDisconnection() {
    logger.d('RTMP disconnected');
    if (mounted) setState(() => _isStreaming = false);
  }

  void _onError(Exception error) {
    logger.e('Live stream error', error: error);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Stream error: $error')));
    }
  }

  // ── Go Live ──────────────────────────────────────────────────────────────────

  Future<void> _goLive() async {
    setState(() => _phase = _Phase.creating);
    try {
      final creatorId = LocalStorage.creatorId;
      final rtmpUrl = LocalStorage.streamRtmpUrl;
      final streamKey = LocalStorage.streamKeyRef;
      final playbackId = LocalStorage.muxLivePlaybackId;
      final muxStreamId = LocalStorage.muxLiveStreamId ?? '';

      logger.d(
        'GoLive: credentials from storage\n'
        '  creatorId:    $creatorId\n'
        '  muxStreamId:  $muxStreamId\n'
        '  playbackId:   $playbackId\n'
        '  rtmpUrl:      $rtmpUrl\n'
        '  streamKey:    $streamKey\n'
        '  → expected full RTMP push target: $rtmpUrl/$streamKey\n'
        '  → expected HLS URL: ${playbackId != null ? "https://stream.mux.com/$playbackId.m3u8" : "N/A"}',
      );

      if (creatorId == null ||
          rtmpUrl == null ||
          streamKey == null ||
          playbackId == null) {
        throw Exception(
          'Stream credentials not found. Please sign out and sign in again.',
        );
      }

      final repo = GetIt.instance<CreatorRepo>();
      final mediaId = await repo.startLivestream(creatorId);
      String resolvedMediaId = mediaId ?? LocalStorage.liveMediaId ?? '';

      // If already-live was returned and we have no cached mediaId, fetch it from the status endpoint
      if (resolvedMediaId.isEmpty) {
        try {
          final status = await repo.getCreatorLiveStatus(creatorId);
          if (status.mediaId != null) resolvedMediaId = status.mediaId!;
        } catch (e) {
          logger.e('GoLive: could not resolve mediaId from status', error: e);
        }
      }

      if (mediaId != null) {
        await LocalStorage.setString(LocalStorage.liveMediaIdKey, mediaId);
      } else if (resolvedMediaId.isNotEmpty) {
        await LocalStorage.setString(
          LocalStorage.liveMediaIdKey,
          resolvedMediaId,
        );
      }
      logger.d('GoLive: liveMediaId = $resolvedMediaId');

      _credentials = _StreamCredentials(
        creatorId: creatorId,
        rtmpIngestUrl: rtmpUrl,
        streamKey: streamKey,
        liveMediaId: resolvedMediaId,
        muxLiveStreamId: muxStreamId,
      );

      if (mounted) {
        setState(() => _phase = _Phase.live);
        _fetchAndCachePlaybackUrl();
      }
    } catch (e, st) {
      logger.e('Failed to go live', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start stream: $e')));
    }
  }

  // ── RTMP streaming ───────────────────────────────────────────────────────────

  Future<void> _startStreaming() async {
    final creds = _credentials;
    if (creds == null) return;
    try {
      logger.d(
        'RTMP → startStreaming\n'
        '  url: ${creds.rtmpIngestUrl}\n'
        '  key: ${creds.streamKey}',
      );
      await _controller.startPreview();
      await _controller.startStreaming(
        streamKey: creds.streamKey,
        url: creds.rtmpIngestUrl,
      );
      // _isStreaming flips to true via _onConnectionSuccess
    } catch (e, st) {
      logger.e('RTMP startStreaming failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start streaming: $e')),
        );
      }
    }
  }

  Future<void> _fetchAndCachePlaybackUrl() async {
    final mediaId = _credentials?.liveMediaId;
    if (mediaId == null || mediaId.isEmpty) return;
    try {
      final token = await GetIt.instance<CreatorRepo>().getPlaybackToken(
        mediaId,
        _clientSessionId(),
      );
      logger.i('Playback URL ready: ${token.hlsUrl}');
      if (mounted) setState(() => _playbackUrl = token.hlsUrl);
    } catch (e) {
      logger.e('Failed to fetch playback token', error: e);
    }
  }

  Future<void> _stopStreaming() async {
    try {
      await _controller.stopStreaming();
    } catch (_) {}
    if (mounted) setState(() => _isStreaming = false);
  }

  Future<void> _endStream() async {
    setState(() => _phase = _Phase.ending);
    try {
      await _controller.stop();
    } catch (_) {}
    final mediaId = (_credentials?.liveMediaId.isNotEmpty == true)
        ? _credentials!.liveMediaId
        : LocalStorage.liveMediaId ?? '';
    logger.d('_endStream: mediaId = "$mediaId"');
    if (mediaId.isNotEmpty) {
      try {
        await GetIt.instance<CreatorRepo>().endLivestream(mediaId);
      } catch (e) {
        logger.e('_endStream: backend end call failed', error: e);
      }
    } else {
      logger.w('_endStream: no mediaId available, skipping backend end call');
    }
    if (!mounted) return;
    setState(() {
      _credentials = null;
      _isStreaming = false;
      _playbackUrl = null;
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

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.goLive),
        backgroundColor: AppColors.background,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.initializing:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case _Phase.error:
        return _buildErrorState();
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

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            size: 64,
            color: AppColors.textTertiary,
          ),
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
            _initError ?? AppStrings.cameraPermDeniedBody,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
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
              onPressed: _goLive,
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
              onPressed: () async {
                final mediaId = _credentials?.liveMediaId;
                if (mediaId == null || mediaId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(AppStrings.noMediaIdError)),
                  );
                  return;
                }
                try {
                  final token = await GetIt.instance<CreatorRepo>()
                      .getPlaybackToken(mediaId, _clientSessionId());
                  logger.i('WatchStream: opening player → ${token.hlsUrl}');
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PlayerScreen.network(networkUrl: token.hlsUrl),
                    ),
                  );
                } catch (e) {
                  logger.e(
                    'WatchStream: failed to get playback token',
                    error: e,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not load stream: $e')),
                    );
                  }
                }
              },
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
            ApiVideoCameraPreview(controller: _controller),
            if (_isStreaming)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
        Text('${AppStrings.streamStatus}: ', style: AppStyles.credLabel),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isStreaming
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isStreaming ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          child: Text(
            (_isStreaming ? AppStrings.statusActive : AppStrings.statusIdle)
                .toUpperCase(),
            style: AppStyles.streamStatusBadge.copyWith(
              color: _isStreaming ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCredentials() {
    final c = _credentials!;
    return Column(
      children: [
        _CredentialRow(
          label: AppStrings.streamId,
          value: c.liveMediaId.isNotEmpty
              ? c.liveMediaId
              : AppStrings.fetchingUrl,
          onCopy: () =>
              c.liveMediaId.isNotEmpty ? _copyToClipboard(c.liveMediaId) : null,
        ),
        const SizedBox(height: 8),
        _CredentialRow(
          label: AppStrings.rtmpUrl,
          value: c.rtmpIngestUrl,
          onCopy: () => _copyToClipboard(c.rtmpIngestUrl),
        ),
        const SizedBox(height: 8),
        _CredentialRow(
          label: AppStrings.streamKey,
          value: c.streamKey,
          obscure: !_streamKeyVisible,
          onCopy: () => _copyToClipboard(c.streamKey),
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
          value: _playbackUrl ?? AppStrings.fetchingUrl,
          onCopy: () =>
              _playbackUrl != null ? _copyToClipboard(_playbackUrl!) : null,
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

// ── Credential row widget ──────────────────────────────────────────────────────

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
