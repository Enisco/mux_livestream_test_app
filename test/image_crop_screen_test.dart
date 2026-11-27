import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/shared/components/image_crop_screen.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

Uint8List _frame(int width, int height) {
  final frame = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      frame.setPixelRgb(x, y, x % 256, y % 256, (x * y) % 256);
    }
  }
  return img.encodeJpg(frame, quality: 90);
}

Widget _host(Widget child) => SizingBuilder(
  baseSize: const Size(390, 844),
  respectSystemFontScale: false,
  builder: (_) =>
      WidgetsApp(color: const Color(0xFF000000), builder: (_, _) => child),
);

PrimaryButton _confirm(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byKey(const ValueKey('crop-confirm')));

void main() {
  testWidgets('nothing can be confirmed before the image has been read', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ImageCropScreen(
          bytes: _frame(600, 400),
          shape: CropShape.wide,
          title: AppStrings.cropCoverTitle,
        ),
      ),
    );

    expect(_confirm(tester).enabled, isFalse);
    expect(find.byKey(const ValueKey('crop-reset')), findsNothing);
  });

  testWidgets('the title is the caller\'s, not the screen\'s', (tester) async {
    await tester.pumpWidget(
      _host(
        ImageCropScreen(
          bytes: _frame(600, 400),
          shape: CropShape.square,
          title: AppStrings.cropLogoTitle,
        ),
      ),
    );

    expect(find.text(AppStrings.cropLogoTitle), findsOneWidget);
    expect(find.text(AppStrings.cropPhotoTitle), findsNothing);
  });

  testWidgets('a cropper offered over a screen that is gone is a cancel', (
    tester,
  ) async {
    // `Navigator.of` on a dead context throws; this must read as backing
    // out instead.
    late BuildContext captured;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final present = cropTo(
      captured,
      shape: CropShape.wide,
      title: AppStrings.cropCoverTitle,
    );

    // Tear the tree down under it.
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    expect(captured.mounted, isFalse);

    expect(await present(_frame(40, 40)), isNull);
  });

  testWidgets('confirming hands back the cropped bytes', (tester) async {
    // The only test here that drives the real editor. It parses and
    // crops in isolates, so it needs real asynchrony, not a pumped clock.
    Object? answer = #unset;
    late BuildContext host;

    await tester.pumpWidget(
      SizingBuilder(
        baseSize: const Size(390, 844),
        respectSystemFontScale: false,
        builder: (_) => MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      final pending = ImageCropScreen.show(
        host,
        bytes: _frame(600, 400),
        shape: CropShape.wide,
        title: AppStrings.cropCoverTitle,
      ).then((value) => answer = value);

      // Settle the route in, then wait for the editor's parse to land.
      // `enabled` is the screen's own account of whether it is ready.
      final button = find.byKey(const ValueKey('crop-confirm'));
      for (var tick = 0; tick < 200; tick++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        // The route has to arrive before the button exists to ask.
        if (button.evaluate().isNotEmpty && _confirm(tester).enabled) break;
      }
      expect(
        _confirm(tester).enabled,
        isTrue,
        reason: 'the editor never finished reading the image',
      );

      await tester.tap(button);
      for (var tick = 0; tick < 200 && answer == #unset; tick++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
      await pending;
    });

    expect(answer, isA<Uint8List>());
    final cropped = img.decodeImage(answer! as Uint8List)!;
    expect(cropped.width / cropped.height, closeTo(16 / 9, 0.02));
    // A JPEG in is a JPEG out: the editor encodes back into the format it
    // was handed, which is what `cropThen` names the result for.
    expect(img.findFormatForData(answer! as Uint8List), img.ImageFormat.jpg);
    expect(
      (answer! as Uint8List).lengthInBytes,
      lessThan(_frame(600, 400).lengthInBytes),
      reason: 'a crop of a picture should not outweigh the whole picture',
    );
  });

  testWidgets('a circular frame moves and resizes, like the rest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ImageCropScreen(
          bytes: _frame(600, 400),
          shape: CropShape.square,
          title: AppStrings.cropLogoTitle,
        ),
      ),
    );

    final crop = tester.widget<Crop>(find.byType(Crop));
    expect(crop.withCircleUi, isTrue);
    // It moves and resizes like every other frame. Without that it could
    // only slide at whatever size it opened, and a face in a wide group
    // photo would be out of reach.
    expect(crop.fixCropRect, isFalse);
    expect(
      crop.cornerDotBuilder!(32, EdgeAlignment.topLeft),
      isA<DotControl>(),
    );
  });

  testWidgets('a rectangular frame resizes, and says so with handles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ImageCropScreen(
          bytes: _frame(600, 400),
          shape: CropShape.wide,
          title: AppStrings.cropCoverTitle,
        ),
      ),
    );

    final crop = tester.widget<Crop>(find.byType(Crop));
    expect(crop.fixCropRect, isFalse);
    expect(
      crop.cornerDotBuilder!(32, EdgeAlignment.topLeft),
      isA<DotControl>(),
      reason: 'a handle is drawn only where one can be grabbed',
    );
  });

  testWidgets('the frame moves over a picture that holds still', (
    tester,
  ) async {
    // Interactive mode pans and zooms the picture under a frame that
    // cannot move, and scales it to cover the viewport the moment it is
    // ready — so the editor opened on a picture already pushed past its
    // own edges. Out of that mode the frame is what the reader drags,
    // and the whole picture stays in view.
    await tester.pumpWidget(
      _host(
        ImageCropScreen(
          bytes: _frame(1200, 800),
          shape: CropShape.wide,
          title: AppStrings.cropThumbnailTitle,
        ),
      ),
    );

    expect(tester.widget<Crop>(find.byType(Crop)).interactive, isFalse);
  });

  testWidgets('resetting builds the editor again rather than refitting it', (
    tester,
  ) async {
    // Building it again is the one reset that leaves nothing of the old
    // framing behind; the controller's own puts the frame back without
    // clearing everything it tracks alongside it.
    Object? answer = #unset;
    late BuildContext host;

    await tester.pumpWidget(
      SizingBuilder(
        baseSize: const Size(390, 844),
        respectSystemFontScale: false,
        builder: (_) => MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      unawaited(
        ImageCropScreen.show(
          host,
          bytes: _frame(1200, 800),
          shape: CropShape.wide,
          title: AppStrings.cropThumbnailTitle,
        ).then((value) => answer = value),
      );

      final reset = find.byKey(const ValueKey('crop-reset'));
      for (var tick = 0; tick < 200; tick++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (reset.evaluate().isNotEmpty) break;
      }
      expect(reset, findsOneWidget, reason: 'the editor never became ready');
    });

    // Outside `runAsync`, and settled first: the pushed route ignores
    // pointers until its transition finishes, and the pumps above ran on
    // a clock that never advanced.
    await tester.pumpAndSettle();

    final before = tester.widget<Crop>(find.byType(Crop)).key;
    await tester.tap(find.byKey(const ValueKey('crop-reset')));
    await tester.pump();

    final rebuilt = tester.widget<Crop>(find.byType(Crop));
    expect(rebuilt.key, isNot(before));
    // The control the reader just pressed stays where it was.
    expect(find.byKey(const ValueKey('crop-reset')), findsOneWidget);

    expect(answer, #unset);
  });

  testWidgets('the frame does not move when the crop is asked for', (
    tester,
  ) async {
    late BuildContext host;
    await tester.pumpWidget(
      SizingBuilder(
        baseSize: const Size(390, 844),
        respectSystemFontScale: false,
        builder: (_) => MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      unawaited(
        ImageCropScreen.show(
          host,
          bytes: _frame(1200, 800),
          shape: CropShape.wide,
          title: AppStrings.cropThumbnailTitle,
        ),
      );
      final button = find.byKey(const ValueKey('crop-confirm'));
      for (var tick = 0; tick < 200; tick++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (button.evaluate().isNotEmpty && _confirm(tester).enabled) break;
      }
    });
    await tester.pumpAndSettle();

    // The editor refits itself whenever its viewport changes size, which
    // throws away the reader's framing. Confirming must not resize it.
    final before = tester.getSize(find.byType(Crop));
    await tester.tap(find.byKey(const ValueKey('crop-confirm')));
    await tester.pump();

    expect(
      tester.getSize(find.byType(Crop)),
      before,
      reason: 'the editor was resized while it was cropping',
    );
  });

  testWidgets('the handles clear the edge the system gestures from', (
    tester,
  ) async {
    // Android takes the outer ~20dp for its back gesture, and a drag that
    // starts in there never reaches the handle. The frame opened wide
    // enough that the handles sat inside that strip.
    const systemEdge = 20.0;

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late BuildContext host;
    await tester.pumpWidget(
      SizingBuilder(
        baseSize: const Size(390, 844),
        respectSystemFontScale: false,
        builder: (_) => MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      unawaited(
        ImageCropScreen.show(
          host,
          bytes: _frame(900, 1400),
          shape: CropShape.wide,
          title: AppStrings.cropThumbnailTitle,
        ),
      );
      for (var tick = 0; tick < 200; tick++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        if (find.byType(DotControl).evaluate().isNotEmpty) break;
      }
    });
    await tester.pumpAndSettle();

    final dots = find.byType(DotControl);
    expect(dots, findsNWidgets(4));

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (var i = 0; i < 4; i++) {
      final box = tester.getRect(dots.at(i));
      expect(
        box.left,
        greaterThanOrEqualTo(systemEdge),
        reason: 'a handle reaches into the back-gesture strip on the left',
      );
      expect(
        width - box.right,
        greaterThanOrEqualTo(systemEdge),
        reason: 'a handle reaches into the back-gesture strip on the right',
      );
    }
  });

  testWidgets('the well is the shape of the crop it holds', (tester) async {
    // A fixed-height well is about 4:1 on a phone, so `BoxFit.cover`
    // sliced the top and bottom off every 16:9 crop put in it.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 360,
            child: ThumbnailWell(
              image: PickedImage(
                bytes: _frame(1600, 900),
                filename: 'cover.jpg',
                mimeType: 'image/jpeg',
              ),
              onPick: () {},
            ),
          ),
        ),
      ),
    );

    final well = tester.getSize(find.byKey(const ValueKey('media-thumbnail')));
    expect(
      well.width / well.height,
      closeTo(CropShape.wide.aspectRatio, 0.2),
      reason: 'the slot has to fit what the editor hands it',
    );
  });

  test('evidence for a payout is never cropped', () {
    final source = File(
      'lib/features/creator/services/giving_evidence_upload.dart',
    ).readAsStringSync();

    expect(source, contains('CreatorImagePicker.pick('));
    expect(
      source,
      isNot(contains('crop:')),
      reason: 'evidence must reach the reviewer as it was photographed',
    );
  });
}
