import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real fonts. Without this the test font makes every glyph one em
/// wide, inflating text and inventing overflows. Required by layout tests.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const families = <String, List<String>>{
    'Satoshi': [
      'fonts/Satoshi-Light.otf',
      'fonts/Satoshi-Regular.otf',
      'fonts/Satoshi-Medium.otf',
      'fonts/Satoshi-Bold.otf',
      'fonts/Satoshi-Black.otf',
    ],
    'Inter': ['fonts/Inter_18pt-Medium.ttf', 'fonts/Inter_18pt-Bold.ttf'],
    'Red Hat Text': ['fonts/RedHatText-Medium.ttf'],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.view(file.readAsBytesSync().buffer)),
      );
    }
    await loader.load();
  }
}
