import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:test_app/features/creator/repo/creator_asset_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';

/// Stands in for the platform picker, so the decisions the service makes about
/// what came back can be exercised without a gallery.
class _FakePicker extends FilePickerPlatform with MockPlatformInterfaceMixin {
  _FakePicker(this.result, {this.throws});

  final PlatformFile? result;

  /// What the platform channel raises instead of answering. The picker
  /// rethrows `PlatformException` for `already_active`, an activity the
  /// system reclaimed, and a provider that will not give the bytes up.
  final Object? throws;

  FileType? askedFor;
  DarwinOptions? darwinAskedWith;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    askedFor = type;
    darwinAskedWith = darwinOptions;
    if (throws case final error?) throw error;
    return result;
  }
}

/// A picked file with no file on disk behind it, so the service has to read
/// it through the picker's own reader rather than by path.
final class _FakeFile extends PlatformFile {
  _FakeFile({required this.name, required this.bytes, this.unreadable = false});

  @override
  final String name;

  final Uint8List bytes;

  /// Whether reading it throws, as a file the provider will not hand over
  /// does.
  final bool unreadable;

  @override
  Uri get uri => Uri.dataFromBytes(bytes);

  @override
  XFile get xFile => XFile.fromData(bytes, name: name);

  @override
  int? lengthSync() => bytes.lengthInBytes;

  @override
  Future<int?> length() async => bytes.lengthInBytes;

  @override
  Future<Uint8List> readAsBytes() async {
    if (unreadable) throw StateError('the provider would not hand it over');
    return bytes;
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

_FakeFile _oneFile({
  required String name,
  required String extension,
  required Uint8List bytes,
}) => _FakeFile(name: name, bytes: bytes);

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
    FilePickerPlatform.instance = _FakePicker(null);

    final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

    expect(result.isCancelled, isTrue);
    expect(result.failure, isNull);
    expect(result.image, isNull);
  });

  test('it asks the platform for images, not for any file', () async {
    final fake = _FakePicker(null);
    FilePickerPlatform.instance = fake;

    await CreatorImagePicker.pick(maxBytes: _avatarMax);

    expect(fake.askedFor, FileType.image);
  });

  test('a PNG passes through untouched', () async {
    FilePickerPlatform.instance = _FakePicker(
      _oneFile(name: 'logo.png', extension: 'png', bytes: png),
    );

    final image = (await CreatorImagePicker.pick(maxBytes: _avatarMax)).image!;

    expect(image.mimeType, 'image/png');
    expect(image.filename, 'logo.png');
    expect(image.bytes, png, reason: 'no re-encode was needed');
  });

  test('a JPG is named as a JPEG for the API', () async {
    FilePickerPlatform.instance = _FakePicker(
      _oneFile(name: 'photo.JPG', extension: 'JPG', bytes: png),
    );

    final image = (await CreatorImagePicker.pick(maxBytes: _avatarMax)).image!;

    expect(image.mimeType, 'image/jpeg');
  });

  test('anything else is re-encoded to PNG and renamed to match', () async {
    // An iPhone hands over HEIC, which the upload endpoints do not accept.
    FilePickerPlatform.instance = _FakePicker(
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
    FilePickerPlatform.instance = _FakePicker(
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
    FilePickerPlatform.instance = _FakePicker(
      _oneFile(name: 'empty.png', extension: 'png', bytes: Uint8List(0)),
    );

    expect(
      (await CreatorImagePicker.pick(maxBytes: _avatarMax)).failure,
      PickFailure.unreadable,
    );
  });

  test('anything over the ceiling is turned away', () async {
    final huge = Uint8List(_avatarMax + 1);
    FilePickerPlatform.instance = _FakePicker(
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

    FilePickerPlatform.instance = _FakePicker(
      _oneFile(name: 'shot.heic', extension: 'heic', bytes: wide),
    );

    final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);
    if (result.image case final image?) {
      expect(image.size, lessThanOrEqualTo(_avatarMax));
    } else {
      expect(result.failure, PickFailure.tooLarge);
    }
  });

  group('the representation iOS is asked for', () {
    test('it asks for a compatible one, so images arrive as JPEG', () async {
      // Left on `automatic` the photo picker lists the asset's own format
      // first and hands over HEIC, which is what every iPhone shoots. The
      // endpoints do not read HEIC, so it had to be re-encoded, and PNG is
      // all `dart:ui` writes: a 12 megapixel frame came back between 3.7 MB
      // and 35 MB against a 2 MB avatar ceiling. It could never succeed.
      final fake = _FakePicker(null);
      FilePickerPlatform.instance = fake;

      await CreatorImagePicker.pick(maxBytes: _avatarMax);

      expect(
        fake.darwinAskedWith?.assetRepresentationMode,
        DarwinAssetRepresentationMode.compatible,
      );
    });

    test('and compressionQuality stays at 0, which that mode requires', () {
      // `DarwinOptions.validate` throws if the two are combined: a specific
      // representation asked for and then recompressed is a contradiction.
      const options = DarwinOptions(
        assetRepresentationMode: DarwinAssetRepresentationMode.compatible,
      );
      expect(() => options.validate(0), returnsNormally);
      expect(() => options.validate(70), throwsArgumentError);
    });
  });

  group('a picture too big for the ceiling it is going to', () {
    test('is shrunk to fit rather than refused', () async {
      // The old path re-encoded at full size and then measured, so a photo
      // over the cap was simply turned away. Nothing a reader could do about
      // it: every picture their phone takes is over a 2 MB cap once PNG has
      // had it.
      final source = await _png(400);
      // A flat colour compresses to very little, so the ceiling has to sit
      // under that for the shrink to be the thing under test.
      const ceiling = 800;
      expect(source.lengthInBytes, greaterThan(ceiling));

      FilePickerPlatform.instance = _FakePicker(
        _oneFile(name: 'shot.png', extension: 'png', bytes: source),
      );

      final result = await CreatorImagePicker.pick(maxBytes: ceiling);
      final image = result.image;
      expect(image, isNotNull, reason: 'it should fit, not fail');
      expect(image!.bytes.lengthInBytes, lessThanOrEqualTo(ceiling));
      expect(image.mimeType, 'image/png');

      // And it is still a real picture, just a smaller one.
      final codec = await ui.instantiateImageCodec(image.bytes);
      final decoded = (await codec.getNextFrame()).image;
      expect(decoded.width, lessThan(400));
      expect(decoded.width, greaterThan(0));
      decoded.dispose();
    });

    test(
      'and one that cannot be made to fit is reported as too large',
      () async {
        // A ceiling no picture can meet still has to answer, not hang.
        final source = await _png(400);
        FilePickerPlatform.instance = _FakePicker(
          _oneFile(name: 'shot.png', extension: 'png', bytes: source),
        );

        final result = await CreatorImagePicker.pick(maxBytes: 8);

        expect(result.failure, PickFailure.tooLarge);
        expect(result.image, isNull);
      },
    );
  });

  test('a truncated file is unsupported, not too large', () async {
    // The header parses, so its size is known, and then the pixels run out.
    // Calling that "too large" would send a reader off to resize a file
    // that resizing cannot fix.
    final whole = await _png(200);
    final cut = Uint8List.sublistView(whole, 0, whole.lengthInBytes ~/ 2);

    FilePickerPlatform.instance = _FakePicker(
      _oneFile(name: 'cut.png', extension: 'png', bytes: cut),
    );

    final result = await CreatorImagePicker.pick(maxBytes: 64);

    expect(result.failure, PickFailure.unsupported);
    expect(result.image, isNull);
  });

  group('camera raw', () {
    test('is refused by name rather than attempted', () async {
      // ProRAW and Pixel RAW decode to tens of megabytes and are never what
      // a reader meant as an avatar. Refusing on format says why; letting it
      // through to be refused on size does not.
      for (final name in ['IMG_1.dng', 'DSC_1.nef', 'P1.arw', 'x.CR3']) {
        FilePickerPlatform.instance = _FakePicker(
          _oneFile(name: name, extension: '', bytes: png),
        );
        final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);
        expect(result.failure, PickFailure.unsupported, reason: name);
      }
    });
  });

  group('what the picker itself does', () {
    test('a picker that throws is a failure, not a crash', () async {
      // This is the crash readers reported: the plugin rethrows and nothing
      // above it was catching.
      FilePickerPlatform.instance = _FakePicker(
        null,
        throws: PlatformException(code: 'already_active'),
      );

      final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

      expect(result.failure, PickFailure.unavailable);
      expect(result.image, isNull);
    });

    test('and anything else it raises is too', () async {
      FilePickerPlatform.instance = _FakePicker(
        null,
        throws: StateError('no host'),
      );

      final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

      expect(result.failure, PickFailure.unavailable);
    });

    test('but a picture it could not read is reported as that', () async {
      // `file_picker_error` is a picture that *was* chosen and then could
      // not be loaded. Calling that "the gallery would not open" sent the
      // creator to look for a permission problem that was never there —
      // picking holds no permission on either platform.
      FilePickerPlatform.instance = _FakePicker(
        null,
        throws: PlatformException(
          code: 'file_picker_error',
          message: 'Failed to process any images',
        ),
      );

      final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

      expect(result.failure, PickFailure.unreadable);
    });

    test('and so is the newer plugin\'s name for the same case', () {
      expect(
        CreatorImagePicker.readFailure('load_failed'),
        PickFailure.unreadable,
      );
      // Everything else is the picker itself, with nothing to suggest.
      for (final code in ['already_active', 'no_activity', 'whatever']) {
        expect(
          CreatorImagePicker.readFailure(code),
          PickFailure.unavailable,
          reason: code,
        );
      }
    });

    test('a picture the provider will not hand over is unreadable', () async {
      // `readAsBytes` is the picker's own reader and it throws rather than
      // answering empty. Unhandled that is a crash on a screen whose only
      // honest report is one sentence.
      FilePickerPlatform.instance = _FakePicker(
        _FakeFile(name: 'a.png', bytes: Uint8List(0), unreadable: true),
      );

      final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

      expect(result.failure, PickFailure.unreadable);
      expect(result.image, isNull);
    });

    test('backing out of it is not a failure at all', () async {
      FilePickerPlatform.instance = _FakePicker(null);

      final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

      expect(result.failure, isNull);
      expect(result.image, isNull);
    });
  });

  group('the sentence a refusal is reported with', () {
    test('every failure has one', () {
      for (final failure in PickFailure.values) {
        expect(failure.accessProblem, isNotEmpty, reason: failure.name);
      }
    });

    test('and none of them sends the reader to Settings', () {
      // There is no switch to find: neither picker holds a permission, so
      // a sentence pointing at Settings would be pointing at nothing.
      for (final failure in PickFailure.values) {
        expect(
          failure.accessProblem.toLowerCase(),
          isNot(contains('settings')),
          reason: failure.name,
        );
      }
    });

    test('and the remedy it names is one every platform has', () {
      // The old wording said "open it in Photos", which on Android is an
      // app that is not installed for a service the phone is not on. The
      // cause that actually mattered was an iPhone HEVC recording, and
      // that is fixed in the plugin rather than worded around here.
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        final sentence = PickFailure.unreadable.accessProblem.toLowerCase();
        expect(sentence, isNot(contains('icloud')), reason: '$platform');
        expect(sentence, isNot(contains('photos')), reason: '$platform');
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('a pick that is cropped first', () {
    test('the editor is offered the picture before anything else is', () async {
      FilePickerPlatform.instance = _FakePicker(
        _FakeFile(name: 'logo.png', bytes: png),
      );

      final offered = <Uint8List>[];
      final result = await CreatorImagePicker.pick(
        maxBytes: _avatarMax,
        crop: (bytes) async {
          offered.add(bytes);
          return bytes;
        },
      );

      expect(
        offered,
        hasLength(1),
        reason: 'a crop that was asked for has to actually be offered',
      );
      expect(result.image, isNotNull);
    });

    test('and is not offered it when no cropper was asked for', () async {
      FilePickerPlatform.instance = _FakePicker(
        _FakeFile(name: 'logo.png', bytes: png),
      );

      final result = await CreatorImagePicker.pick(maxBytes: _avatarMax);

      expect(result.image, isNotNull);
      expect(result.image!.filename, 'logo.png');
    });

    test('backing out of the editor leaves nothing picked', () async {
      FilePickerPlatform.instance = _FakePicker(
        _FakeFile(name: 'logo.png', bytes: png),
      );

      final result = await CreatorImagePicker.pick(
        maxBytes: _avatarMax,
        crop: (_) async => null,
      );

      expect(result.isCancelled, isTrue);
      expect(result.image, isNull);
      expect(result.failure, isNull);
    });

    test('a picker that would not open never reaches the editor', () async {
      var opened = false;
      FilePickerPlatform.instance = _FakePicker(
        null,
        throws: PlatformException(code: 'already_active'),
      );

      final result = await CreatorImagePicker.pick(
        maxBytes: _avatarMax,
        crop: (bytes) async {
          opened = true;
          return bytes;
        },
      );

      expect(opened, isFalse);
      expect(result.failure, PickFailure.unavailable);
    });
  });
}
