import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import 'package:test_app/core/logger.dart';

/// An image the reader chose, in a form the API will accept.
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;

  /// Already renamed to match [mimeType] when the source was transcoded, so
  /// the extension never contradicts the bytes.
  final String filename;

  /// Always one the upload endpoints accept — `image/jpeg` or `image/png`.
  final String mimeType;

  int get size => bytes.lengthInBytes;
}

/// Why a pick could not be used.
enum PickFailure { tooLarge, unreadable, unsupported }

class PickResult {
  const PickResult._({this.image, this.failure});

  const PickResult.picked(PickedImage image) : this._(image: image);
  const PickResult.failed(PickFailure failure) : this._(failure: failure);

  /// The reader backed out of the picker. Not a failure.
  const PickResult.cancelled() : this._();

  final PickedImage? image;
  final PickFailure? failure;

  bool get isCancelled => image == null && failure == null;
}

/// Picks an avatar or banner and hands back something uploadable.
///
/// Two things stand between the gallery and the API, and both are handled
/// here rather than at the call site:
///
///  * **HEIC.** iPhones shoot HEIC by default, and the upload endpoints accept
///    only `image/jpeg` and `image/png`. Anything that is not already one of
///    those is decoded and re-encoded as PNG, which Flutter can do natively —
///    iOS decodes HEIC through the platform codec.
///  * **Size.** The two assets have different ceilings, which the ceiling is
///    passed in for. Both were read off staging's own
///    `constraints.maxSizeBytes` — see [CreatorAssetKind] — and the check
///    happens after any transcode, since the re-encoded bytes are what get
///    uploaded.
abstract final class CreatorImagePicker {
  static const _jpeg = 'image/jpeg';
  static const _png = 'image/png';

  /// What the endpoints accept as-is; everything else is re-encoded.
  static const _passThrough = {'jpg': _jpeg, 'jpeg': _jpeg, 'png': _png};

  static Future<PickResult> pick({required int maxBytes}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final file = result?.files.singleOrNull;
    if (file == null) return const PickResult.cancelled();

    final bytes = await _bytesOf(file);
    if (bytes == null || bytes.isEmpty) {
      return const PickResult.failed(PickFailure.unreadable);
    }

    final extension = (file.extension ?? '').toLowerCase();
    final passThrough = _passThrough[extension];
    final stem = _stem(file.name);

    if (passThrough != null) {
      return _sized(
        PickedImage(bytes: bytes, filename: file.name, mimeType: passThrough),
        maxBytes,
      );
    }

    // HEIC, WebP, anything else: re-encode to something the API names.
    final png = await _toPng(bytes);
    if (png == null) return const PickResult.failed(PickFailure.unsupported);
    return _sized(
      PickedImage(bytes: png, filename: '$stem.png', mimeType: _png),
      maxBytes,
    );
  }

  static PickResult _sized(PickedImage image, int maxBytes) =>
      image.size > maxBytes
      ? const PickResult.failed(PickFailure.tooLarge)
      : PickResult.picked(image);

  /// `withData` is not set on the pick, so bytes come from the path on mobile
  /// and from memory on the platforms that have no path.
  static Future<Uint8List?> _bytesOf(PlatformFile file) async {
    if (file.bytes case final bytes?) return bytes;
    if (file.path case final path?) {
      try {
        return await File(path).readAsBytes();
      } catch (e) {
        logger.w('Could not read picked image', error: e);
      }
    }
    return null;
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static Future<Uint8List?> _toPng(Uint8List bytes) async {
    ui.Image? decoded;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      decoded = (await codec.getNextFrame()).image;
      final data = await decoded.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) {
      logger.w('Could not re-encode picked image as PNG', error: e);
      return null;
    } finally {
      decoded?.dispose();
    }
  }
}
