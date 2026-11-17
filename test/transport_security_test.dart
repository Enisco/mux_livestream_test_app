import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// That the app insists on a secure connection, on both platforms.
///
/// `NSAllowsArbitraryLoads` turns App Transport Security off for the whole
/// binary: every plaintext HTTP connection to any host is permitted, so a
/// hostile network can read and rewrite anything the app sends — tokens,
/// prayer and testimony bodies, giving details. It was set, and nothing in
/// the app needed it: every HTTP URL the app loads is already HTTPS, Apple's
/// own `nscurl --ats-diagnostics` passes each host with an empty ATS
/// dictionary, and Android has been running with cleartext blocked by
/// default all along.
void main() {
  late final String plist = File('ios/Runner/Info.plist').readAsStringSync();
  late final String manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  group('iOS', () {
    test('App Transport Security is not turned off', () {
      expect(
        plist,
        isNot(contains('NSAllowsArbitraryLoads')),
        reason:
            'this permits plaintext HTTP to every host in the app, and Apple '
            'asks for a written justification for it at review',
      );
    });

    test('nor turned off for media, which is the quieter way to do it', () {
      // `NSAllowsArbitraryLoadsForMedia` and the WebView twin each open the
      // same hole for the traffic that carries the most of a reader's
      // attention.
      expect(plist, isNot(contains('NSAllowsArbitraryLoadsForMedia')));
      expect(plist, isNot(contains('NSAllowsArbitraryLoadsInWebContent')));
      expect(plist, isNot(contains('NSAllowsLocalNetworking')));
    });

    test('and no host has been let out of it one at a time', () {
      // A per-host exception is the legitimate form of this, so it is not
      // forbidden — but every host the app talks to passes ATS as it
      // stands, so one appearing here means something changed.
      expect(
        plist,
        isNot(contains('NSExceptionAllowsInsecureHTTPLoads')),
        reason:
            'if a host genuinely needs this, say which and why here rather '
            'than deleting the test',
      );
    });
  });

  group('Android', () {
    test('cleartext traffic is not switched on', () {
      // Blocked by default from API 28. Saying so explicitly would be fine;
      // saying the opposite would not.
      expect(
        manifest,
        isNot(contains('android:usesCleartextTraffic="true"')),
        reason: 'this permits plaintext HTTP to every host in the app',
      );
    });

    test('and no network security config quietly permits it', () {
      final config = File(
        'android/app/src/main/res/xml/network_security_config.xml',
      );
      if (!config.existsSync()) return;
      expect(
        config.readAsStringSync(),
        isNot(contains('cleartextTrafficPermitted="true"')),
      );
    });
  });

  group('and nothing in the app asks for a plaintext connection', () {
    /// Every `http://`, `ws://` or `rtmp://` URL written into the app.
    List<String> cleartext() {
      final found = <String>[];
      final pattern = RegExp(
        r'\b(?:http|ws|rtmp)://[^\s"'
        r"'"
        r'`)\]]+',
      );
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        for (final line in file.readAsLinesSync()) {
          // `startsWith('http://')` and friends are checks on what came
          // back from the API, not addresses the app dials.
          if (line.contains("startsWith('http://')")) continue;
          for (final match in pattern.allMatches(line)) {
            found.add('${file.path}: ${match.group(0)}');
          }
        }
      }
      return found;
    }

    test('except the RTMP ingest, which is not an HTTP connection at all', () {
      // ATS governs NSURLSession and CFNetwork. The broadcast's RTMP socket
      // is neither — it is a raw TCP stream the api.video SDK owns — so
      // turning ATS back on does not touch it, and it is the one address
      // here that is not https.
      expect(
        cleartext(),
        everyElement(contains('rtmp://global-live.mux.com')),
        reason: 'a plaintext address was written into the app',
      );
    });

    test('and the environment it is configured with is all https', () {
      for (final name in ['.env', '.env.example']) {
        final env = File(name);
        if (!env.existsSync()) continue;
        final urls = RegExp(
          r'\b[a-z]+://[^\s]+',
        ).allMatches(env.readAsStringSync()).map((m) => m.group(0)!);
        for (final url in urls) {
          expect(
            url,
            startsWith('https://'),
            reason: '$name points the app at a plaintext address',
          );
        }
      }
    });
  });
}
