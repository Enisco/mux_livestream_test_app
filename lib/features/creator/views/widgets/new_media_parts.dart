import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The pieces the New video and New audio screens are made of. They are the
/// same screen with different copy, different ceilings and a different tile
/// on the file card.

/// A rounded rectangle drawn with a dashed outline, which is how the design
/// marks the two drop targets.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.radius = 10,
    this.color = AppColors.neutral700,
  });

  final Widget child;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashPainter(radius: radius.s, color: color),
    child: child,
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(
          metric.extractPath(at, math.min(at + dash, metric.length)),
          paint,
        );
        at += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.radius != radius || old.color != color;
}

/// Nothing chosen yet: what will be accepted, and the way in.
class MediaPickCard extends StatelessWidget {
  const MediaPickCard({
    super.key,
    required this.hint,
    required this.selectLabel,
    required this.onPick,
    this.busy = false,
  });

  /// What the API will take, in the creator's terms — the two kinds have
  /// different containers and very different ceilings.
  final String hint;
  final String selectLabel;

  final VoidCallback onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) => DashedBorder(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 16.s),
      child: Row(
        children: [
          Container(
            width: 44.s,
            height: 44.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandPrimary.withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCloudUpload,
              color: AppColors.brandPrimary,
              size: 20.s,
            ),
          ),
          SizedBox(width: 12.s),
          Expanded(
            child: Text(
              hint,
              style: AppStyles.label(
                12,
                color: AppColors.neutral400,
                lineHeight: 16 / 12,
              ),
            ),
          ),
          SizedBox(width: 10.s),
          GestureDetector(
            key: const ValueKey('media-select'),
            behavior: HitTestBehavior.opaque,
            onTap: busy ? null : onPick,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 10.s),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.s),
                border: Border.all(color: AppColors.neutral700),
              ),
              child: Text(
                selectLabel,
                style: AppStyles.label(13, weight: AppStyles.bold),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A chosen file, with how far its bytes have got.
///
/// The design writes this line as "Processing 64% · 1.2 GB". It says
/// **Uploading** here instead: at this point the bytes are still going to
/// Mux, and "Processing" already means something else in the studio — the
/// transcode that happens after, which the Content tab labels.
class MediaFileCard extends StatelessWidget {
  const MediaFileCard({
    super.key,
    required this.kind,
    required this.file,
    required this.sent,
    required this.onRemove,
    this.failed = false,
  });

  /// Audio leads with a square tile carrying a headphones mark and its own
  /// progress bar; video leads with a landscape still. That is the only
  /// difference between the two designs.
  final MediaUploadKind kind;

  final PickedMediaFile file;

  /// Bytes on the wire so far. Equal to the file size once it is all in.
  final int sent;

  /// The upload could not start or could not finish. Without this the card
  /// sat at "Uploading 0%" after a refusal, long after the snackbar had
  /// gone — and the monthly quota makes that the likeliest ending of all.
  final bool failed;

  final VoidCallback onRemove;

  bool get _done => sent >= file.size;

  @override
  Widget build(BuildContext context) {
    final percent = file.size <= 0
        ? 0
        : ((sent / file.size) * 100).clamp(0, 100).floor();

    return DashedBorder(
      child: Padding(
        padding: EdgeInsets.all(12.s),
        child: Row(
          children: [
            _Tile(kind: kind, progress: failed ? 0 : percent / 100),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    file.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(14, weight: AppStyles.bold),
                  ),
                  SizedBox(height: 6.s),
                  Row(
                    children: [
                      HugeIcon(
                        icon: failed
                            ? HugeIcons.strokeRoundedAlert02
                            : _done
                            ? HugeIcons.strokeRoundedCheckmarkCircle02
                            : HugeIcons.strokeRoundedRefresh,
                        color: failed
                            ? AppColors.destructive
                            : AppColors.brandPrimary,
                        size: 13.s,
                      ),
                      SizedBox(width: 5.s),
                      Expanded(
                        child: Text(
                          failed
                              ? '${AppStrings.newMediaUploadFailed} · '
                                    '${formatBytes(file.size)}'
                              : _done
                              ? '${AppStrings.newMediaUploaded} · '
                                    '${formatBytes(file.size)}'
                              : '${AppStrings.newMediaUploading} $percent% · '
                                    '${formatBytes(file.size)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyles.label(
                            12,
                            weight: AppStyles.bold,
                            color: failed
                                ? AppColors.destructive
                                : AppColors.brandPrimary,
                            lineHeight: 16 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.s),
            GestureDetector(
              key: const ValueKey('media-remove'),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: EdgeInsets.all(4.s),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  color: AppColors.destructive,
                  size: 18.s,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The square headphones tile audio leads with, or the landscape still
/// video does. The bar along the foot is the design's, and only audio
/// carries it.
class _Tile extends StatelessWidget {
  const _Tile({required this.kind, required this.progress});

  final MediaUploadKind kind;

  /// 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final audio = kind.isAudio;
    return ClipRRect(
      key: ValueKey(audio ? 'media-tile-audio' : 'media-tile-video'),
      borderRadius: BorderRadius.circular(8.s),
      child: SizedBox(
        width: audio ? 64.s : 72.s,
        height: 64.s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.brandAltDark),
            Center(
              child: HugeIcon(
                icon: audio
                    ? HugeIcons.strokeRoundedHeadphones
                    : HugeIcons.strokeRoundedVideo01,
                color: audio ? AppColors.neutral200 : AppColors.neutral500,
                size: 20.s,
              ),
            ),
            if (audio)
              Align(
                alignment: Alignment.bottomLeft,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(height: 3.s, color: AppColors.brandPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "1.2 GB", "640 MB" — the way the design writes a file size.
String formatBytes(int bytes) {
  const kb = 1024;
  if (bytes >= kb * kb * kb) {
    return '${(bytes / (kb * kb * kb)).toStringAsFixed(1)} GB';
  }
  if (bytes >= kb * kb) return '${(bytes / (kb * kb)).round()} MB';
  if (bytes >= kb) return '${(bytes / kb).round()} KB';
  return '$bytes B';
}

/// The thumbnail well: an amber invitation, or the picture once chosen.
class ThumbnailWell extends StatelessWidget {
  const ThumbnailWell({
    super.key,
    required this.image,
    required this.onPick,
    this.emptyLabel,
  });

  final PickedImage? image;
  final VoidCallback onPick;

  /// What the empty well invites. An event calls it cover art rather than
  /// a thumbnail, though it goes to the same kind of S3 ticket.
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('media-thumbnail'),
    behavior: HitTestBehavior.opaque,
    onTap: onPick,
    child: DashedBorder(
      child: SizedBox(
        height: 96.s,
        width: double.infinity,
        child: image == null
            ? Center(
                child: _pill(emptyLabel ?? AppStrings.newMediaThumbnailCta),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.s),
                    child: Image.memory(image!.bytes, fit: BoxFit.cover),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8.s),
                      child: _pill(AppStrings.newMediaThumbnailChange),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _pill(String label) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 7.s),
    decoration: BoxDecoration(
      color: AppColors.brandPrimary.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999.s),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedImage02,
          color: AppColors.brandPrimary,
          size: 13.s,
        ),
        SizedBox(width: 6.s),
        Text(
          label,
          style: AppStyles.label(
            12,
            weight: AppStyles.bold,
            color: AppColors.brandPrimary,
            lineHeight: 16 / 12,
          ),
        ),
      ],
    ),
  );
}

/// "Title required" — the label, with the word the design sets in grey.
class RequiredLabel extends StatelessWidget {
  const RequiredLabel(this.text, {super.key, this.required = true});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: text,
      style: AppStyles.label(12, weight: AppStyles.medium, lineHeight: 16 / 12),
      children: [
        if (required)
          TextSpan(
            text: ' ${AppStrings.newMediaRequired}',
            style: AppStyles.label(
              12,
              color: AppColors.neutral500,
              lineHeight: 16 / 12,
            ),
          ),
      ],
    ),
  );
}

/// How it ended: live, scheduled, or put away as a draft.
class PublishedCard extends StatelessWidget {
  const PublishedCard({
    super.key,
    required this.title,
    required this.body,
    required this.onDone,
  });

  final String title;
  final String body;
  final VoidCallback onDone;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.overlayDark,
    builder: (dialogContext) => PublishedCard(
      title: title,
      body: body,
      onDone: () => Navigator.pop(dialogContext),
    ),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.base2,
    insetPadding: EdgeInsets.symmetric(horizontal: 44.s),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.s)),
    child: Padding(
      padding: EdgeInsets.fromLTRB(24.s, 26.s, 24.s, 20.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.s,
            height: 56.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.green500.withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedRocket01,
              color: AppColors.green500,
              size: 26.s,
            ),
          ),
          SizedBox(height: 16.s),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppStyles.heading(20, letterSpacing: -0.5),
          ),
          SizedBox(height: 8.s),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppStyles.body(
              13,
              color: AppColors.neutral400,
              lineHeight: 18 / 13,
            ),
          ),
          SizedBox(height: 18.s),
          GestureDetector(
            key: const ValueKey('published-done'),
            behavior: HitTestBehavior.opaque,
            onTap: onDone,
            child: Text(
              AppStrings.newMediaDone,
              style: AppStyles.label(
                13,
                weight: AppStyles.bold,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
