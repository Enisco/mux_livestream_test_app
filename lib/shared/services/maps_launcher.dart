import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'package:test_app/core/logger.dart';

/// Opens an address in whichever map app the reader already has.
///
/// The design draws a map preview with a pin under an event's location, and
/// that is not buildable: an event stores only text — `label`, `addressLine`,
/// `city` — with **no coordinates**, and the app has no maps SDK, no
/// geocoding and no API key. Shipping a tile provider and a key for one
/// preview, or drawing a fake map, were both worse than the honest version.
///
/// Handing the address to the platform costs nothing and does more: the
/// reader lands in the app they actually use, with search, directions and
/// their own saved places already there.
abstract final class MapsLauncher {
  /// Apple Maps on iOS and the `geo:` intent on Android both take a plain
  /// query, which is exactly what the event has. The web URL is the fallback
  /// for anything without a handler — it opens whatever the browser or the
  /// installed Google Maps chooses.
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
