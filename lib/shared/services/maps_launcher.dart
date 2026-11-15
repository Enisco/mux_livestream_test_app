import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'package:test_app/core/logger.dart';

/// Opens an address in whichever map app the reader already has.
abstract final class MapsLauncher {
  /// Apple Maps on iOS and the `geo:` intent on Android both take a plain
  /// query, which is exactly what the event has.
  static List<Uri> urisFor(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final encoded = Uri.encodeComponent(trimmed);
    return [
      if (Platform.isIOS) Uri.parse('https://maps.apple.com/?q=$encoded'),
      if (Platform.isAndroid) Uri.parse('geo:0,0?q=$encoded'),
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'),
    ];
  }

  /// Tries each candidate in turn. Returns false when nothing could open it,
  /// so the caller can say so rather than leaving a dead tap.
  static Future<bool> open(String query) async {
    for (final uri in urisFor(query)) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (e) {
        logger.w('Could not open $uri', error: e);
      }
    }
    return false;
  }
}
