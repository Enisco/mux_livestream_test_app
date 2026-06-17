import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_styles.dart';
import 'video_thumbnail_widget.dart';

class VideoCard extends StatelessWidget {
  final String filePath;
  final VoidCallback onTap;

  const VideoCard({super.key, required this.filePath, required this.onTap});

  String get _fileName => filePath.split(Platform.pathSeparator).last;

  String get _fileExt {
    final name = _fileName;
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1).toUpperCase() : 'VIDEO';
  }

  Color get _extColor => switch (_fileExt) {
    'MP4' => AppColors.fmtMp4,
    'MKV' => AppColors.fmtMkv,
    'AVI' => AppColors.fmtAvi,
    'MOV' => AppColors.fmtMov,
    'WEBM' => AppColors.fmtWebm,
    _ => AppColors.fmtDefault,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      // clipBehavior ensures the thumbnail is clipped to the card's rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ThumbnailSection(videoPath: filePath),
                Expanded(
                  child: _InfoSection(
                    name: _fileName,
                    path: filePath,
                    ext: _fileExt,
                    extColor: _extColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailSection extends StatelessWidget {
  final String videoPath;
  const _ThumbnailSection({required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12.0),
        bottomLeft: Radius.circular(12.0),
      ),
      child: SizedBox(
        width: 80.0,
        height: 70.0,
        child: VideoThumbnailWidget(videoPath: videoPath),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String name;
  final String path;
  final String ext;
  final Color extColor;

  const _InfoSection({
    required this.name,
    required this.path,
    required this.ext,
    required this.extColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Right padding reserves space for the remove button.
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 32.0 + 4.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: AppStyles.videoTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4.0),
          Row(
            children: [
              _ExtBadge(ext: ext, color: extColor),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  path,
                  style: AppStyles.videoPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExtBadge extends StatelessWidget {
  final String ext;
  final Color color;
  const _ExtBadge({required this.ext, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(ext, style: AppStyles.extBadge.copyWith(color: color)),
    );
  }
}
