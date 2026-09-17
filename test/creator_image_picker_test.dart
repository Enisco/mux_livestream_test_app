import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:test_app/features/creator/repo/creator_asset_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';

/// Stands in for the platform picker, so the decisions the service makes about
/// what came back can be exercised without a gallery.
class _FakePicker extends FilePicker with MockPlatformInterfaceMixin {
  _FakePicker(this.result);

  final FilePickerResult? result;
  FileType? askedFor;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool Function(String)? onFileFilter,
  }) async {
    askedFor = type;
    return result;
  }
}

FilePickerResult _oneFile({
  required String name,
  required String extension,
  required Uint8List bytes,
}) => FilePickerResult([
  PlatformFile(
    name: name,
    size: bytes.lengthInBytes,
    bytes: bytes,
    // No path: the service must fall back to the in-memory bytes.
  ),
]);

/// A real, decodable PNG, so the transcode path has something to work on.
Future<Uint8List> _png(int side) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    Paint()..color = const Color(0xFFFF8800),
  );
  final image = await recorder.endRecording().toImage(side, side);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// The avatar ceiling staging reports in `constraints.maxSizeBytes`.
final _avatarMax = CreatorAssetKind.avatar.maxBytes;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List png;

  setUpAll(() async {
    png = await _png(8);
  });

  test('backing out of the picker is not a failure', () async {
    FilePicker.platform = _FakePicker(null);

    final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

    expect(result.isCancelled, isTrue);
    expect(result.failure, isNull);
    expect(result.image, isNull);
  });

  test('it asks the platform for images, not for any file', () async {
    final fake = _FakePicker(null);
    FilePicker.platform = fake;

    await CreatorImagePicker.pick(maxBytes: _avatarMax);

    expect(fake.askedFor, FileType.image);
  });

  test('a PNG passes through untouched', () async {
    FilePicker.platform = _FakePicker(
      _oneFile(name: 'logo.png', extension: 'png', bytes: png),
    );

    final image = (await CreatorImagePicker.pick(maxBytes: _avatarMax)).image!;

    expect(image.mimeType, 'image/png');
    expect(image.filename, 'logo.png');
    expect(image.bytes, png, reason: 'no re-encode was needed');
  });

  test('a JPG is named as a JPEG for the API', () async {
    FilePicker.platform = _FakePicker(
      _oneFile(name: 'photo.JPG', extension: 'JPG', bytes: png),
    );

    final image = (await CreatorImagePicker.pick(maxBytes: _avatarMax)).image!;

    expect(image.mimeType, 'image/jpeg');
  });

  test('anything else is re-encoded to PNG and renamed to match', () async {
    // An iPhone hands over HEIC, which the upload endpoints do not accept.
    // The bytes here are a PNG wearing a .heic name: what matters is that the
    // service does not trust the extension and re-encodes.
    FilePicker.platform = _FakePicker(
      _oneFile(name: 'IMG_0042.heic', extension: 'heic', bytes: png),
    );

    final image = (await CreatorImagePicker.pick(maxBytes: _avatarMax)).image!;

    expect(image.mimeType, 'image/png');
    expect(
      image.filename,
      'IMG_0042.png',
      reason: 'the extension must not contradict the bytes',
    );
  });

  test('an undecodable file is reported, not thrown', () async {
    FilePicker.platform = _FakePicker(
      _oneFile(
        name: 'broken.heic',
        extension: 'heic',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    );

    final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

    expect(result.failure, PickFailure.unsupported);
    expect(result.image, isNull);
  });

  test('an empty file is reported as unreadable', () async {
    FilePicker.platform = _FakePicker(
      _oneFile(name: 'empty.png', extension: 'png', bytes: Uint8List(0)),
    );

    expect(
      (await CreatorImagePicker.pick(maxBytes: _avatarMax)).failure,
      PickFailure.unreadable,
    );
  });

  test('anything over the ceiling is turned away', () async {
    final huge = Uint8List(_avatarMax + 1);
    FilePicker.platform = _FakePicker(
      _oneFile(name: 'huge.png', extension: 'png', bytes: huge),
    );

    expect(
      (await CreatorImagePicker.pick(maxBytes: _avatarMax)).failure,
      PickFailure.tooLarge,
    );
  });

  test('the two assets carry the ceilings staging reports', () {
    expect(CreatorAssetKind.avatar.maxBytes, 2 * 1024 * 1024);
    expect(CreatorAssetKind.banner.maxBytes, 8 * 1024 * 1024);
  });

  test('the ceiling is checked after any transcode, not before', () async {
    // A small source can decode to a large PNG, and it is the encoded result
    // that gets uploaded — so that is what has to fit.
    final wide = await _png(2200);
    expect(
      wide.lengthInBytes,
      lessThan(_avatarMax),
      reason: 'the source itself is within the ceiling',
    );

    FilePicker.platform = _FakePicker(
      _oneFile(name: 'shot.heic', extension: 'heic', bytes: wide),
    );

    final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);
    if (result.image case final image?) {
      expect(image.size, lessThanOrEqualTo(_avatarMax));
    } else {
      expect(result.failure, PickFailure.tooLarge);
    }
  });
}
