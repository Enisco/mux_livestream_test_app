import 'dart:convert';
import 'dart:io';

import 'package:test_app/core/logger.dart';

/// The renditions an HLS master playlist advertises.
abstract final class HlsManifest {
  /// Label → bitrate ceiling, e.g. `{'1080p': 5_000_000, '720p': 2_800_000}`.
  static Map<String, int> parse(String content) {
    final byLabel = <String, int>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#EXT-X-STREAM-INF:')) continue;

      final bandwidth = RegExp(r'BANDWIDTH=(\d+)').firstMatch(trimmed);
      if (bandwidth == null) continue;
      final bps = int.tryParse(bandwidth.group(1)!);
      if (bps == null || bps <= 0) continue;

      final resolution = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(trimmed);
      final height = resolution == null
          ? null
          : int.tryParse(resolution.group(1)!);
      final label = height != null ? '${height}p' : '${(bps / 1000).round()}k';

      // Several audio/codec variants can share a resolution; the highest
      // bitrate is the one worth pinning to.
      final existing = byLabel[label];
      if (existing == null || bps > existing) byLabel[label] = bps;
    }

    if (byLabel.length < 2) return const {};

    // Tallest first, which is how a quality menu reads.
    final sorted = byLabel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  static Future<Map<String, int>> fetch(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        logger.w('HLS manifest returned ${response.statusCode}');
        return const {};
      }
      return parse(await response.transform(utf8.decoder).join());
    } catch (e) {
      logger.w('HLS manifest could not be read', error: e);
      return const {};
    } finally {
      client.close(force: true);
    }
  }
}
