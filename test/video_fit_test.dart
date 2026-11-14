import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/shared/components/video_fit.dart';

/// Every `Video(...)` constructor call in [source], with its arguments.
///
/// Found by balancing brackets rather than by a regular expression, so a
/// nested call in an argument cannot end the match early. `FullscreenVideo(`
/// and the like are skipped: the character before the match has to be one
/// that cannot be part of an identifier.
List<String> _videoCalls(String source) {
  final calls = <String>[];
  final word = RegExp(r'[A-Za-z0-9_]');
  var i = source.indexOf('Video(');
  while (i >= 0) {
    if (i == 0 || !word.hasMatch(source[i - 1])) {
      var depth = 0;
      var j = i + 'Video'.length;
      while (j < source.length) {
        if (source[j] == '(') depth++;
        if (source[j] == ')') {
          depth--;
          if (depth == 0) {
            j++;
            break;
          }
        }
        j++;
      }
      calls.add(source.substring(i, j));
    }
    i = source.indexOf('Video(', i + 1);
  }
  return calls;
}

Map<String, List<String>> _everyVideoCallUnderLib() {
  final found = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    if (!source.contains("import 'package:media_kit_video/")) continue;
    final calls = _videoCalls(source);
    if (calls.isNotEmpty) found[entity.path] = calls;
  }
  return found;
}

void main() {
  group('what a landscape frame does with an upright video', () {
    // A phone livestream replay, as measured on staging: 720x1280.
    const upright = Size(720, 1280);
    const sermon = Size(1280, 720);
    // The 16:9 frame the detail hero draws, on a 390-wide design.
    const frame = Size(390, 390 * 9 / 16);

    test('fills the frame instead of leaving pillars beside it', () {
      final filled = applyBoxFit(VideoFit.landscapeFrame, upright, frame);
      expect(filled.destination.width, closeTo(frame.width, 0.01));
      expect(filled.destination.height, closeTo(frame.height, 0.01));
    });

    test('which is the thing the old fit did not do', () {
      // Guards the decision itself: BoxFit.contain put a 9:16 replay in a
      // narrow strip with most of the frame left black.
      final lettered = applyBoxFit(BoxFit.contain, upright, frame);
      expect(lettered.destination.width, lessThan(frame.width / 3));
    });

    test('never stretches — the crop is the only thing it gives up', () {
      final filled = applyBoxFit(VideoFit.landscapeFrame, upright, frame);
      expect(
        filled.source.width / filled.source.height,
        closeTo(frame.width / frame.height, 0.01),
        reason:
            'the slice taken out of the source is frame-shaped, so the '
            'picture keeps its proportions',
      );
      expect(filled.source.width, closeTo(upright.width, 0.01));
      expect(filled.source.height, lessThan(upright.height));
    });

    test('leaves a landscape sermon exactly as it was', () {
      final now = applyBoxFit(VideoFit.landscapeFrame, sermon, frame);
      final before = applyBoxFit(BoxFit.contain, sermon, frame);
      expect(now.destination.width, closeTo(before.destination.width, 0.01));
      expect(now.destination.height, closeTo(before.destination.height, 0.01));
      expect(now.source.height, closeTo(sermon.height, 0.01));
    });
  });

  group('a surface that is the whole screen keeps the whole picture', () {
    const sermon = Size(1280, 720);
    const upright = Size(720, 1280);
    // A phone is not 16:9 either way up.
    const phone = Size(390, 844);
    const rotated = Size(844, 390);

    test('a sermon on the player screen is not cropped', () {
      final shown = applyBoxFit(VideoFit.fullBleed, sermon, phone);
      expect(shown.source.width, closeTo(sermon.width, 0.01));
      expect(shown.source.height, closeTo(sermon.height, 0.01));
    });

    test('because filling that one would cost most of its width', () {
      // Why [VideoFit.landscapeFrame] must never reach a full-bleed
      // surface: 9:19.5 is nothing like 16:9.
      final filled = applyBoxFit(BoxFit.cover, sermon, phone);
      expect(filled.source.width, lessThan(sermon.width / 3));
    });

    test('and fullscreen shows all of it rather than a wider slice', () {
      final shown = applyBoxFit(VideoFit.fullBleed, sermon, rotated);
      expect(shown.source.height, closeTo(sermon.height, 0.01));
      final filled = applyBoxFit(BoxFit.cover, sermon, rotated);
      expect(filled.source.height, lessThan(sermon.height * 0.85));
    });

    test('an upright replay keeps its whole frame there too', () {
      final shown = applyBoxFit(VideoFit.fullBleed, upright, phone);
      expect(shown.source.height, closeTo(upright.height, 0.01));
      // It still fills the width, which is why the player screen never
      // looked wrong for a phone livestream.
      expect(shown.destination.width, closeTo(phone.width, 0.01));
    });
  });

  group('every player frame says which rule it follows', () {
    test('no video surface names a raw BoxFit', () {
      final offenders = <String>[];
      _everyVideoCallUnderLib().forEach((path, calls) {
        for (final call in calls) {
          if (call.contains('BoxFit.')) offenders.add(path);
        }
      });
      expect(
        offenders,
        isEmpty,
        reason:
            'a player frame picks its fit from VideoFit, so the choice '
            'is made once and can be read in one place',
      );
    });

    test('and none of them leaves it to the default', () {
      // media_kit's own default is BoxFit.contain, so an omitted `fit` is
      // the pillarboxed frame coming back without anyone writing it down.
      final offenders = <String>[];
      _everyVideoCallUnderLib().forEach((path, calls) {
        for (final call in calls) {
          if (!call.contains('fit:')) offenders.add(path);
        }
      });
      expect(offenders, isEmpty);
    });

    test('each surface takes the fit its shape calls for', () {
      const framed = [
        'lib/features/home/views/widgets/feed_video_surface.dart',
      ];
      const fullBleed = [
        'lib/features/player/views/player_screen.dart',
        'lib/features/discovery/views/vertical_feed_screen.dart',
      ];

      final found = _everyVideoCallUnderLib();
      for (final path in [...framed, ...fullBleed]) {
        expect(found[path], isNotNull, reason: '$path draws no video any more');
      }
      for (final path in framed) {
        for (final call in found[path]!) {
          expect(call, contains('VideoFit.landscapeFrame'), reason: path);
        }
      }
      for (final path in fullBleed) {
        for (final call in found[path]!) {
          expect(call, contains('VideoFit.fullBleed'), reason: path);
        }
      }
    });

    test('and the hero holds one of each, the right way round', () {
      // The inline hero is a 16:9 frame in a page; the fullscreen route it
      // pushes is the whole screen. One file, two different answers.
      const path = 'lib/features/discovery/views/widgets/video_hero.dart';
      final source = File(path).readAsStringSync();
      final cut = source.indexOf('class _FullscreenVideoState');
      expect(cut, greaterThan(0), reason: 'the fullscreen route moved');

      final inline = _videoCalls(source.substring(0, cut));
      final full = _videoCalls(source.substring(cut));
      expect(inline, hasLength(1));
      expect(full, hasLength(1));
      expect(inline.single, contains('VideoFit.landscapeFrame'));
      expect(full.single, contains('VideoFit.fullBleed'));
    });
  });
}
