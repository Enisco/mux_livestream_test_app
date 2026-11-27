import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/shared/components/gtube_text_field.dart';
import 'package:test_app/utils/helpers/text_capitalization.dart';

/// Every call to [name] in [source], brackets balanced, so an argument
/// list that runs over several lines comes back whole.
List<String> _callsTo(String name, String source) {
  final calls = <String>[];
  final word = RegExp(r'[A-Za-z0-9_]');
  final needle = '$name(';
  var i = source.indexOf(needle);
  while (i >= 0) {
    if (i == 0 || !word.hasMatch(source[i - 1])) {
      var depth = 0;
      var j = i + name.length;
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
    i = source.indexOf(needle, i + 1);
  }
  return calls;
}

/// The text inputs under `lib/` that are built straight rather than
/// through one of the three wrappers, and that are meant to stay
/// unshifted. Everything not on this list has to say what its shift key
/// does, which is the whole point of the guard below.
const _unshifted = <String, String>{
  'lib/features/auth/views/widgets/auth_widgets.dart':
      'AuthField is unreferenced — no screen builds one',
  'lib/features/creator/views/creator_polish_screens.dart':
      'the social-link row, which is a URL',
  'lib/features/creator/views/widgets/creator_setup_fields.dart':
      'CreatorHandleField — a handle, lower case by rule',
  'lib/features/creator/views/widgets/new_article_parts.dart':
      'the link dialog, which is a URL',
  'lib/features/livestream/views/join_livestream_screen.dart':
      'a stream id, and the screen is unroutable besides',
  'lib/features/settings/views/two_factor_screens.dart': 'a password',
  'lib/shared/components/gtube_phone_field.dart': 'a phone number',
  'lib/shared/components/otp_code_field.dart': 'digits only',
};

void main() {
  group('the shift key follows the keyboard the field asked for', () {
    test('prose keyboards come up shifted', () {
      for (final kind in <TextInputType?>[
        null,
        TextInputType.text,
        TextInputType.multiline,
        TextInputType.name,
        TextInputType.streetAddress,
      ]) {
        expect(
          sentenceCaseUnlessMachineText(kind),
          TextCapitalization.sentences,
          reason: '$kind is prose',
        );
      }
    });

    test('and machine text does not', () {
      for (final kind in <TextInputType>[
        TextInputType.emailAddress,
        TextInputType.url,
        TextInputType.phone,
        TextInputType.number,
        TextInputType.numberWithOptions(decimal: true),
        TextInputType.visiblePassword,
        TextInputType.datetime,
      ]) {
        expect(
          sentenceCaseUnlessMachineText(kind),
          TextCapitalization.none,
          reason: '$kind is not prose',
        );
      }
    });

    test('nor does anything hidden', () {
      expect(
        sentenceCaseUnlessMachineText(null, obscured: true),
        TextCapitalization.none,
      );
    });
  });

  group('the fields themselves', () {
    Future<TextCapitalization> capitalizationOf(
      WidgetTester tester,
      Widget field,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Material(child: field)),
        ),
      );
      final found = tester.widgetList<EditableText>(find.byType(EditableText));
      expect(found, hasLength(1));
      return found.single.textCapitalization;
    }

    testWidgets('GTubeTextField shifts prose', (tester) async {
      expect(
        await capitalizationOf(
          tester,
          GTubeTextField(controller: TextEditingController(), hint: 'About'),
        ),
        TextCapitalization.sentences,
      );
    });

    testWidgets('and leaves an address alone', (tester) async {
      expect(
        await capitalizationOf(
          tester,
          GTubeTextField(
            controller: TextEditingController(),
            hint: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        TextCapitalization.none,
      );
    });

    testWidgets('and still defers to a field that knows better', (
      tester,
    ) async {
      expect(
        await capitalizationOf(
          tester,
          GTubeTextField(
            controller: TextEditingController(),
            hint: 'First name',
            textCapitalization: TextCapitalization.words,
          ),
        ),
        TextCapitalization.words,
      );
    });

    testWidgets('CreatorTextField shifts a title', (tester) async {
      expect(
        await capitalizationOf(
          tester,
          CreatorTextField(controller: TextEditingController(), hint: 'Title'),
        ),
        TextCapitalization.sentences,
      );
    });

    testWidgets('and leaves an amount alone', (tester) async {
      expect(
        await capitalizationOf(
          tester,
          CreatorTextField(
            controller: TextEditingController(),
            hint: 'Amount',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        TextCapitalization.none,
      );
    });
  });

  group('and no field is left to chance', () {
    /// A password with a Show toggle reads `obscureText: false` the moment
    /// it is revealed, so a field that let the wrapper infer its shift key
    /// from that flag would start capitalising the password mid-entry.
    /// Two answers are allowed: pin `TextCapitalization.none`, or resolve
    /// it here from a flag that does not move — `SettingsFormField` passes
    /// `obscured: widget.obscure`, the kind of field it is rather than
    /// whether it happens to be hidden right now.
    test('a revealable password does not read its own Show toggle', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final call in _callsTo('GTubeTextField', source)) {
          final revealable =
              call.contains('obscureText: _obscure') ||
              call.contains('obscureText: _hidden');
          if (!revealable) continue;
          final pinned = call.contains('TextCapitalization.none');
          final resolvedFromAStableFlag = call.contains('obscured:');
          if (!pinned && !resolvedFromAStableFlag) {
            offenders.add(
              '${entity.path}: a password that can be revealed does not '
              'pin its capitalization',
            );
          }
        }
      }
      expect(offenders, isEmpty);
    });

    /// The three wrappers resolve their own default. A screen that builds
    /// a `TextField` straight past them has to say what the shift key
    /// does — otherwise Flutter's own default, `none`, quietly wins and a
    /// comment box comes up lower case again.
    test('every hand-built input states its capitalization', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        final source = entity.readAsStringSync();
        final raw = [
          ..._callsTo('TextField', source),
          ..._callsTo('TextFormField', source),
          ..._callsTo('CupertinoTextField', source),
        ].where((c) => c.contains('controller:'));
        for (final call in raw) {
          if (call.contains('textCapitalization:')) continue;
          if (_unshifted.containsKey(path)) continue;
          offenders.add('$path builds a text field that says nothing');
        }
      }
      expect(offenders, isEmpty);
    });

    test('and the unshifted list has no stale entries', () {
      for (final path in _unshifted.keys) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path is on the unshifted list but is gone',
        );
      }
    });
  });
}
