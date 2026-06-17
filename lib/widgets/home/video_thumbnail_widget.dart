import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/app_colors.dart';

class VideoThumbnailWidget extends StatelessWidget {
  final String videoPath;

  static final _cache = <String, Future<Uint8List?>>{};

  static const _channel = MethodChannel('gtube/thumbnail');

  const VideoThumbnailWidget({super.key, required this.videoPath});

  static Future<Uint8List?> _generate(String path) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 240,
          quality: 72,
        );
      }
      if (Platform.isMacOS) {
        final result = await _channel.invokeMethod<Uint8List>('generate', path);
        return result;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _cache.putIfAbsent(videoPath, () => _generate(videoPath)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Placeholder(loading: true);
        }
        final data = snapshot.data;
        if (data == null) return const _Placeholder(loading: false);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true),
            const _PlayOverlay(),
          ],
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  final bool loading;
  const _Placeholder({required this.loading});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.video_file_rounded,
                color: AppColors.textTertiary,
                size: 24,
              ),
      ),
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 28.0,
        height: 28.0,
        decoration: BoxDecoration(
          color: AppColors.overlayMid,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 16.0,
        ),
      ),
    );
  }
}
