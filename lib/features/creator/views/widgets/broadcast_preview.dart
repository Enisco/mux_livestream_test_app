// ignore_for_file: invalid_use_of_internal_member
// `textureId`, `addWidgetListener` and `removeWidgetListener` are marked
// internal to the plugin because its own preview widget is meant to be the
// only caller.

import 'dart:async';
import 'dart:math' as math;

import 'package:apivideo_live_stream/apivideo_live_stream.dart';
import 'package:flutter/widgets.dart';

import 'package:test_app/shared/components/video_fit.dart';

/// The camera, framed the way the people watching it will see it.
class BroadcastPreview extends StatefulWidget {
  const BroadcastPreview({super.key, required this.controller, this.frame});

  final ApiVideoLiveStreamController controller;

  /// The camera's own frame, if a test wants to state it. Otherwise the
  /// controller is asked, and 720x1280 stands in until it answers.
  final Size? frame;

  @override
  State<BroadcastPreview> createState() => _BroadcastPreviewState();
}

class _BroadcastPreviewState extends State<BroadcastPreview> {
  late final _listener = ApiVideoLiveStreamWidgetListener(
    onTextureReady: _textureReady,
  );

  late int _textureId = widget.controller.textureId;
  late Size _frame = widget.frame ?? const Size(720, 1280);

  @override
  void initState() {
    super.initState();
    widget.controller.addWidgetListener(_listener);
    if (widget.frame == null) unawaited(_readFrame());
  }

  @override
  void dispose() {
    widget.controller.removeWidgetListener(_listener);
    // The preview is deliberately left running.
    super.dispose();
  }

  void _textureReady() {
    if (!mounted) return;
    setState(() => _textureId = widget.controller.textureId);
    if (widget.frame == null) unawaited(_readFrame());
  }

  /// The controller answers the configured resolution, which is written
  /// landscape-first (`Resolution.RESOLUTION_720` is `Size(1280, 720)`)
  /// however the camera is actually pointing.
  Future<void> _readFrame() async {
    final Size? size;
    try {
      size = await widget.controller.videoSize;
    } catch (_) {
      return;
    }
    if (!mounted || size == null || size.isEmpty) return;
    final upright = Size(
      math.min(size.width, size.height),
      math.max(size.width, size.height),
    );
    if (upright != _frame) setState(() => _frame = upright);
  }

  @override
  Widget build(BuildContext context) {
    if (_textureId == ApiVideoLiveStreamController.kUninitializedTextureId) {
      return const SizedBox.shrink();
    }
    return Center(
      child: AspectRatio(
        aspectRatio: VideoFit.landscapeAspect,
        child: ClipRect(
          child: FittedBox(
            fit: VideoFit.landscapeFrame,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _frame.width,
              height: _frame.height,
              child: Texture(textureId: _textureId),
            ),
          ),
        ),
      ),
    );
  }
}
