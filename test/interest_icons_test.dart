import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The chip glyphs are hand-authored rather than exported from Figma, so this
/// guards the thing that would otherwise fail silently: flutter_svg refusing a
/// path and drawing nothing.
void main() {
  final files = Directory(
    'assets/icons',
  ).listSync().whereType<File>().where((f) => f.path.contains('cat_')).toList();

  test('the chip glyph set is present', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    testWidgets('$name parses and paints', (tester) async {
      final source = file.readAsStringSync();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SvgPicture.string(source, width: 12, height: 12),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name failed to parse');
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  }
}
