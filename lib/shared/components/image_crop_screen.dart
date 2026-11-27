import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Frames a picked image at [shape]'s ratio before it is uploaded.
///
/// Answers the cropped bytes, or `null` when the reader backed out.
class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({
    super.key,
    required this.bytes,
    required this.shape,
    required this.title,
  });

  /// Must be PNG or JPEG; see `CreatorImagePicker.cropThen`.
  final Uint8List bytes;

  final CropShape shape;
  final String title;

  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List bytes,
    required CropShape shape,
    required String title,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) =>
            ImageCropScreen(bytes: bytes, shape: shape, title: title),
      ),
    );
  }

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final _controller = CropController();

  /// `nothing` until the editor has parsed the image. Cropping before
  /// then trips an assert inside it.
  CropStatus _status = CropStatus.nothing;

  bool _failed = false;

  /// Latched, so a reset's reload does not blink the controls off.
  bool _everReady = false;

  /// Bumped to build the editor afresh. See [_reset].
  int _generation = 0;

  /// How much of the viewport the frame opens across.
  ///
  /// The frame is centred and its handles are 32 wide, centred on its
  /// corners, so each one reaches `(1 - this) / 2` of the width minus 16
  /// from the screen edge. Android puts its back gesture in the outer
  /// 20dp or so, and anything inside that never reaches the handle: at
  /// 0.9 the handle started 3.5 from the edge of a 390 screen and the
  /// system swallowed the drag. 0.8 starts it at 23.
  static const _initialFrame = 0.8;

  bool get _ready => _status == CropStatus.ready;
  bool get _working => _status == CropStatus.cropping;

  /// Builds the editor again from nothing, which is the one reset that
  /// leaves no state behind. It costs a re-parse, which the spinner
  /// covers.
  void _reset() => setState(() {
    _generation++;
    _status = CropStatus.nothing;
    _failed = false;
  });

  void _confirm() {
    if (!_ready) return;
    setState(() => _failed = false);
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure(:final cause, :final stackTrace):
        logger.w(
          'Could not crop the picked image',
          error: cause,
          stackTrace: stackTrace,
        );
        setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _editor()),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(15.s, 12.s, 15.s, 12.s),
      child: Row(
        children: [
          GTubeBackButton(onTap: () => Navigator.of(context).maybePop()),
          SizedBox(width: 12.s),
          Expanded(
            child: Text(
              widget.title,
              style: AppStyles.label(15, weight: AppStyles.semiBold),
            ),
          ),
          if (_everReady)
            GestureDetector(
              key: const ValueKey('crop-reset'),
              behavior: HitTestBehavior.opaque,
              onTap: _reset,
              child: Text(
                AppStrings.cropReset,
                style: AppStyles.label(
                  13,
                  color: AppColors.brandPrimary,
                  weight: AppStyles.semiBold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _editor() {
    return Stack(
      children: [
        Positioned.fill(
          child: Crop(
            key: ValueKey(_generation),
            image: widget.bytes,
            controller: _controller,
            aspectRatio: widget.shape.aspectRatio,
            withCircleUi: widget.shape.circular,
            // The frame is what moves: dragging slides it over a picture
            // that holds still, and the corners resize it. The package
            // wires that to the same gesture as pinch-to-zoom and will
            // only do one of them, so there is no zoom here — the frame
            // shrinking to 40pt reaches the same tight crops, and the
            // bytes come from the full-resolution source either way.
            interactive: false,
            fixCropRect: false,
            initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
              size: _initialFrame,
              aspectRatio: widget.shape.aspectRatio,
            ),
            baseColor: AppColors.background,
            maskColor: AppColors.background.withValues(alpha: 0.72),
            radius: widget.shape.circular ? 0 : 10,
            // Every frame resizes, a circle included: its handles sit at
            // the corners of the square the circle is inscribed in, which
            // is the only place there is to put them.
            cornerDotBuilder: (size, alignment) =>
                const DotControl(color: AppColors.textPrimary),
            progressIndicator: const Center(
              child: CircularProgressIndicator(
                color: AppColors.brandPrimary,
                strokeWidth: 2.5,
              ),
            ),
            onStatusChanged: (status) {
              if (!mounted) return;
              setState(() {
                _status = status;
                if (status == CropStatus.ready) _everReady = true;
              });
            },
            imageCropper: _affordableCropper,
            onCropped: _onCropped,
          ),
        ),
        // The hint, the failure and the busy spinner all live in here
        // rather than beside the button, because the editor refits the
        // image — losing the reader's framing — whenever its own box
        // changes size, and anything in the column below would do that.
        if (_everReady || _failed)
          Positioned(
            left: 15.s,
            right: 15.s,
            bottom: 10.s,
            child: Text(
              _failed ? AppStrings.cropFailed : AppStrings.cropHint,
              textAlign: TextAlign.center,
              style: AppStyles.caption(
                11,
                color: _failed ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ),
        if (_working)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x660E0E1A),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// One child, whose height never changes. See the editor's overlays.
  Widget _footer() {
    return Padding(
      padding: EdgeInsets.fromLTRB(15.s, 12.s, 15.s, 16.s),
      child: SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          key: const ValueKey('crop-confirm'),
          label: AppStrings.cropConfirm,
          enabled: _ready,
          onPressed: _confirm,
        ),
      ),
    );
  }
}

/// A [CropPresenter] that puts [ImageCropScreen] over [context].
///
/// It runs after the system picker closes, by which time [context] may be
/// gone; that answers `null`, which reads as backing out.
CropPresenter cropTo(
  BuildContext context, {
  required CropShape shape,
  required String title,
}) {
  return (bytes) async {
    if (!context.mounted) return null;
    return ImageCropScreen.show(
      context,
      bytes: bytes,
      shape: shape,
      title: title,
    );
  };
}

/// The package's own cropper encodes at 100, which is roughly five times
/// the bytes for no visible difference at the sizes these are shown.
const _jpegQuality = 88;

/// The package's cropping, encoding at [_jpegQuality]. Const and
/// fieldless so the editor can send it to an isolate.
class _AffordableCropper extends ImageCropper<img.Image> {
  const _AffordableCropper();

  @override
  RectValidator<img.Image> get rectValidator => defaultRectValidator;

  @override
  RectCropper<img.Image> get rectCropper => _cropRect;

  @override
  CircleCropper<img.Image> get circleCropper => _cropCircle;
}

const _affordableCropper = _AffordableCropper();

/// Top-level so the isolate can reach it.
Uint8List _cropRect(
  img.Image original, {
  required Offset topLeft,
  required Size size,
  required ImageFormat? outputFormat,
}) {
  final cropped = img.copyCrop(
    original,
    x: topLeft.dx.toInt(),
    y: topLeft.dy.toInt(),
    width: size.width.toInt(),
    height: size.height.toInt(),
  );
  return outputFormat == ImageFormat.jpeg
      ? img.encodeJpg(cropped, quality: _jpegQuality)
      : img.encodePng(cropped);
}

/// Unreached — the editor crops the square around a circular mask. Here
/// because the interface asks for it.
Uint8List _cropCircle(
  img.Image original, {
  required Offset center,
  required double radius,
  required ImageFormat? outputFormat,
}) {
  final square = original.numChannels == 4
      ? original
      : original.convert(numChannels: 4);
  return img.encodePng(
    img.copyCropCircle(
      square,
      centerX: center.dx.toInt(),
      centerY: center.dy.toInt(),
      radius: radius.toInt(),
    ),
  );
}
