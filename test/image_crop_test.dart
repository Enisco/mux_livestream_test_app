import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:test_app/features/creator/repo/creator_asset_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';

Uint8List _frame(int width, int height, {required bool png}) {
  final frame = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      frame.setPixelRgba(x, y, x % 256, y % 256, (x + y) % 256, 255);
    }
  }
  return png ? img.encodePng(frame) : img.encodeJpg(frame, quality: 90);
}

bool _isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

bool _isPng(Uint8List b) =>
    b.length > 8 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4E &&
    b[3] == 0x47;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const budget = 10 * 1024 * 1024;

  group('what the crop editor is handed', () {
    test('a photograph arrives as JPEG, bounded to 1600 pixels', () async {
      Uint8List? given;
      final result = await CreatorImagePicker.cropThen(
        _frame(3000, 2000, png: false),
        'IMG_0042.jpg',
        budget,
        (bytes) async {
          given = bytes;
          return bytes;
        },
      );

      expect(given, isNotNull);
      expect(_isJpeg(given!), isTrue, reason: 'a photo has no alpha to keep');

      final size = img.decodeImage(given!)!;
      expect(size.width, 1600);
      expect(size.height, 1067);

      expect(result.image, isNotNull);
      expect(result.image!.filename, 'IMG_0042.jpg');
      expect(result.image!.mimeType, 'image/jpeg');
    });

    test('a logo that could be transparent stays PNG', () async {
      Uint8List? given;
      final result = await CreatorImagePicker.cropThen(
        _frame(2400, 2400, png: true),
        'logo.png',
        budget,
        (bytes) async {
          given = bytes;
          return bytes;
        },
      );

      expect(_isPng(given!), isTrue);
      expect(result.image!.filename, 'logo.png');
      expect(result.image!.mimeType, 'image/png');
    });

    test('the pixels survive the trip through the isolate', () async {
      // A wrong offset or stride would still answer the right size, so
      // this checks the colour rather than the shape.
      final solid = img.Image(width: 64, height: 64, numChannels: 4)
        ..clear(img.ColorRgba8(0x20, 0x90, 0xD0, 255));

      Uint8List? given;
      await CreatorImagePicker.cropThen(
        img.encodeJpg(solid, quality: 100),
        'flat.jpg',
        budget,
        (bytes) async {
          given = bytes;
          return bytes;
        },
      );

      final pixel = img.decodeImage(given!)!.getPixel(32, 32);
      expect(pixel.r, closeTo(0x20, 4));
      expect(pixel.g, closeTo(0x90, 4));
      expect(pixel.b, closeTo(0xD0, 4));
    });

    test('a picture already small enough is not enlarged', () async {
      Uint8List? given;
      await CreatorImagePicker.cropThen(
        _frame(400, 300, png: false),
        'small.jpg',
        budget,
        (bytes) async {
          given = bytes;
          return bytes;
        },
      );

      final size = img.decodeImage(given!)!;
      expect(size.width, 400);
      expect(size.height, 300);
    });

    test('camera raw never reaches it', () async {
      var opened = false;
      final result = await CreatorImagePicker.cropThen(
        _frame(80, 80, png: false),
        'DSC_1000.dng',
        budget,
        (bytes) async {
          opened = true;
          return bytes;
        },
      );

      expect(opened, isFalse);
      expect(result.failure, PickFailure.unsupported);
    });

    test('bytes nothing can decode are refused, not opened', () async {
      var opened = false;
      final result = await CreatorImagePicker.cropThen(
        Uint8List.fromList(List.filled(64, 7)),
        'broken.jpg',
        budget,
        (bytes) async {
          opened = true;
          return bytes;
        },
      );

      expect(opened, isFalse);
      expect(result.failure, PickFailure.unsupported);
    });
  });

  group('what comes back out', () {
    test('backing out of the editor is a cancel, not a failure', () async {
      final result = await CreatorImagePicker.cropThen(
        _frame(600, 400, png: false),
        'cover.jpg',
        budget,
        (_) async => null,
      );

      expect(result.isCancelled, isTrue);
      expect(result.failure, isNull);
      expect(result.image, isNull);
    });

    test('an editor that answered nothing is a cancel too', () async {
      final result = await CreatorImagePicker.cropThen(
        _frame(600, 400, png: false),
        'cover.jpg',
        budget,
        (_) async => Uint8List(0),
      );

      expect(result.isCancelled, isTrue);
    });

    test('a crop over the budget is shrunk to fit it', () async {
      final result = await CreatorImagePicker.cropThen(
        _frame(1200, 1200, png: true),
        'logo.png',
        1024,
        (bytes) async => bytes,
      );

      expect(result.failure, isNull);
      expect(result.image, isNotNull);
      expect(result.image!.size, lessThanOrEqualTo(1024));
    });

    test('the crop is what gets uploaded, not the original', () async {
      final result = await CreatorImagePicker.cropThen(
        _frame(3000, 2000, png: false),
        'IMG_1.jpg',
        budget,
        (bytes) async {
          final whole = img.decodeImage(bytes)!;
          return img.encodeJpg(
            img.copyCrop(whole, x: 0, y: 0, width: 320, height: 180),
            quality: 90,
          );
        },
      );

      final kept = img.decodeImage(result.image!.bytes)!;
      expect(kept.width, 320);
      expect(kept.height, 180);
    });
  });

  group('the shapes', () {
    test('a logo is square and masked as a circle', () {
      expect(CreatorAssetKind.avatar.cropShape, CropShape.square);
      expect(CropShape.square.aspectRatio, 1);
      expect(CropShape.square.circular, isTrue);
    });

    test('a channel banner matches the header it is drawn in', () {
      expect(CreatorAssetKind.banner.cropShape, CropShape.banner);
      expect(CropShape.banner.aspectRatio, 2);
      expect(CropShape.banner.circular, isFalse);
    });

    test('covers and thumbnails are 16:9', () {
      expect(CropShape.wide.aspectRatio, 16 / 9);
      expect(CropShape.wide.circular, isFalse);
    });
  });
}
