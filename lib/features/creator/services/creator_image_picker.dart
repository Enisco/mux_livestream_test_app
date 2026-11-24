import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/keyboard.dart';

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
enum PickFailure {
  tooLarge,
  unreadable,
  unsupported,

  /// The picker itself would not open, or would not hand the file back.
  unavailable,
}

/// The refusals that say nothing about the picture itself.
///
/// There used to be two more — the library refused, and refused for good —
/// from a time when picking an image asked for the photo library first.
/// Nothing asks now: both platforms pick through an out-of-process picker
/// that hands one file over with a grant attached, so there is no
/// permission left to refuse. See `MediaPermissions`.
extension PickFailureAccess on PickFailure {
  String get accessProblem => switch (this) {
    PickFailure.unavailable => AppStrings.pickerUnavailable,
    _ => AppStrings.creatorImageUnreadable,
  };
}

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
abstract final class CreatorImagePicker {
  static const _jpeg = 'image/jpeg';
  static const _png = 'image/png';

  /// What the endpoints accept as-is; everything else is re-encoded.
  static const _passThrough = {'jpg': _jpeg, 'jpeg': _jpeg, 'png': _png};

  /// Camera raw. These decode to tens of megabytes and are never what a
  /// reader meant to use as an avatar or a cover, so they are refused by
  /// name rather than attempted and failed on size.
  ///
  /// `dng` is Apple ProRAW and Pixel RAW; the rest come off cameras people
  /// import from.
  static const _raw = {'dng', 'raw', 'cr2', 'cr3', 'nef', 'arw', 'orf', 'rw2'};

  static Future<PickResult> pick({required int maxBytes}) async {
    // The system picker is presented over Flutter's view and does not take
    // the keyboard with it. See [dismissKeyboard].
    dismissKeyboard();

    final PlatformFile? file;
    try {
      file = await FilePickerPlatform.instance.pickFile(
        type: FileType.image,
        // **Ask for JPEG, not the original.** Left on `automatic`, the
        // photo picker lists the asset's own format first and this gets
        // handed a HEIC — which is what every iPhone shoots by default.
        // Nothing downstream reads HEIC, so it had to be decoded and
        // re-encoded, and PNG is the only format `dart:ui` writes: a 12
        // megapixel frame came out between 3.7 MB and 35 MB depending on
        // the picture, against a 2 MB avatar cap. It could not succeed.
        //
        // `compatible` makes the picker transcode and list JPEG first, so
        // the file arrives as a `.jpg` and passes through untouched.
        //
        // Images only. On a video pick this same flag sets
        // `preferredAssetRepresentationMode = .compatible` on the picker,
        // which asks iOS to transcode HEVC to H.264 — the slow, failure-prone
        // path that broke picking iPhone recordings in the first place.
        darwinOptions: const DarwinOptions(
          assetRepresentationMode: DarwinAssetRepresentationMode.compatible,
        ),
      );
    } on PlatformException catch (e) {
      // The code and the details, for the same reason the media picker
      // keeps them: `load_failed` is a picture that was chosen and then
      // could not be read, every other code is the picker itself, and only
      // the code tells them apart. The details carry the system's own
      // domain, code and message, and the chain underneath them — which is
      // the whole diagnosis when a creator says the button did nothing.
      logger.w(
        'Image picker failed: ${e.code} — ${e.message}'
        '${e.details == null ? '' : ' (${e.details})'}',
      );
      return PickResult.failed(readFailure(e.code));
    } catch (e) {
      // `pickFile` rethrows whatever the platform raised: a picker already
      // open, a gallery provider that will not give the bytes up, a host
      // activity the system reclaimed while the picker was up. Unhandled,
      // each of those is a crash where a sentence will do.
      logger.w('Image picker failed', error: e);
      return const PickResult.failed(PickFailure.unavailable);
    }
    if (file == null) return const PickResult.cancelled();

    final bytes = await _bytesOf(file);
    if (bytes == null || bytes.isEmpty) {
      return const PickResult.failed(PickFailure.unreadable);
    }

    return _fromBytes(bytes, file.name, maxBytes);
  }

  /// Which platform codes mean *picked, then unreadable* rather than *the
  /// picker would not open*. See `CreatorMediaPicker.readFailure`, which
  /// reads the same codes for the same reason.
  @visibleForTesting
  static PickFailure readFailure(String code) => switch (code) {
    'file_picker_error' || 'load_failed' => PickFailure.unreadable,
    _ => PickFailure.unavailable,
  };

  /// Turning read bytes into something the endpoints accept, within the
  /// budget they accept it in.
  ///
  /// Three outcomes, cheapest first:
  ///
  ///  * **Already fine** — a JPEG or PNG inside [maxBytes] is sent exactly
  ///    as it was picked. No decode, no quality lost. With the picker asked
  ///    for a compatible representation this is now the common case.
  ///  * **Needs shrinking** — a JPEG or PNG over the cap, or a format the
  ///    endpoints do not read (HEIC, WebP, GIF, AVIF). Decoded smaller and
  ///    written back out as PNG. An animated GIF keeps only its first
  ///    frame, which is what an avatar or a cover shows anyway.
  ///  * **Not a picture worth trying** — camera raw, or bytes no codec on
  ///    this device recognises.
  static Future<PickResult> _fromBytes(
    Uint8List bytes,
    String filename,
    int maxBytes,
  ) async {
    final extension = _extensionOf(filename);
    if (_raw.contains(extension)) {
      return const PickResult.failed(PickFailure.unsupported);
    }

    final passThrough = _passThrough[extension];
    if (passThrough != null && bytes.lengthInBytes <= maxBytes) {
      return PickResult.picked(
        PickedImage(bytes: bytes, filename: filename, mimeType: passThrough),
      );
    }

    // Past here it is either a format the endpoints do not read, or one they
    // do that arrived over the ceiling. Both are answered by decoding it
    // smaller, which first needs its size.
    final size = await _dimensions(bytes);
    if (size == null) {
      // No codec on this device could read it. If the extension was one the
      // endpoints accept then the only thing known to be wrong with it is
      // that it is too big, and saying so is more use to a reader than
      // calling their JPEG an unsupported format.
      return PickResult.failed(
        passThrough != null ? PickFailure.tooLarge : PickFailure.unsupported,
      );
    }

    // A header that parsed is not a picture that decodes: a truncated file
    // gets this far. Encoding failing outright is a different answer from
    // encoding fine and still not fitting, and telling someone to shrink a
    // corrupt file would send them somewhere that cannot help.
    final png = await _shrinkToFit(bytes, size, maxBytes);
    if (png == null) {
      return const PickResult.failed(PickFailure.unsupported);
    }
    if (png.lengthInBytes > maxBytes) {
      return const PickResult.failed(PickFailure.tooLarge);
    }
    return PickResult.picked(
      PickedImage(
        bytes: png,
        filename: '${_stem(filename)}.png',
        mimeType: _png,
      ),
    );
  }

  /// Decodes small enough to fit [maxBytes], and writes PNG.
  ///
  /// Answers `null` only when nothing could be encoded at all. Bytes that
  /// came out larger than the budget are still returned, so the caller can
  /// tell a picture it could not shrink from one it could not read.
  ///
  /// Decoding at a target size rather than full size and scaling after is
  /// deliberate: `instantiateImageCodec` does the reduction inside the
  /// codec, so a 12 megapixel frame never has to exist in memory at full
  /// size. That is the same read-it-all-first mistake that made the old
  /// picker fall over on big files, and it would be worse here, where the
  /// decoded bitmap is four bytes a pixel.
  ///
  /// PNG of photographic content runs around two bytes a pixel, so the
  /// budget gives a first guess at how many pixels can be kept. The guess
  /// is only that — a noisy picture costs more, a flat one far less — so
  /// the result is measured and the guess halved until it fits. Three
  /// attempts take the pixel budget down to a quarter, and since the
  /// measurement is what decides, a picture needing more than that was
  /// never going to arrive at a size worth showing.
  static Future<Uint8List?> _shrinkToFit(
    Uint8List bytes,
    (int, int) size,
    int maxBytes,
  ) async {
    final (width, height) = size;
    if (width <= 0 || height <= 0) return null;

    var budget = maxBytes;
    Uint8List? smallest;
    for (var attempt = 0; attempt < 3; attempt++) {
      final scale = _scaleFor(width, height, budget);
      final encoded = await _encodePng(
        bytes,
        width: (width * scale).round().clamp(1, width),
        height: (height * scale).round().clamp(1, height),
      );
      if (encoded == null) return null;
      if (encoded.lengthInBytes <= maxBytes) return encoded;
      smallest = encoded;
      budget ~/= 2;
    }
    return smallest;
  }

  /// How far to shrink so the pixel count fits a byte budget, never
  /// enlarging: a small picture that is somehow over the cap is a picture
  /// PNG cannot help, and stretching it would only cost more.
  static double _scaleFor(int width, int height, int budget) {
    const bytesPerPixel = 2;
    final allowed = budget / bytesPerPixel;
    final pixels = width * height;
    if (pixels <= allowed) return 1;
    return math.sqrt(allowed / pixels);
  }

  /// The picture's size without decoding it.
  static Future<(int, int)?> _dimensions(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } catch (e) {
      logger.w('Could not read the picked image\'s size', error: e);
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static String _extensionOf(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
  }

  /// Reads the picture, wherever the platform put it.
  ///
  /// `readAsBytes` is the picker's own reader: a local file on mobile, a
  /// blob on the web, without this having to know which. It throws rather
  /// than answering empty when the file is gone or unreadable, which is a
  /// failure to report, not to crash on.
  static Future<Uint8List?> _bytesOf(PlatformFile file) async {
    try {
      return await file.readAsBytes();
    } catch (e) {
      logger.w('Could not read picked image', error: e);
      return null;
    }
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static Future<Uint8List?> _encodePng(
    Uint8List bytes, {
    required int width,
    required int height,
  }) async {
    ui.Image? decoded;
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: width,
        targetHeight: height,
      );
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
