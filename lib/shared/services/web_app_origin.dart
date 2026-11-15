import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Where the GospelTube web app lives, worked out from the API host.
String? webAppOrigin({String? apiBase}) {
  final raw = (apiBase ?? _envBase).trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority) return null;
  // Only the leading label is rewritten.
  final host = uri.host.startsWith('api.')
      ? 'app.${uri.host.substring(4)}'
      : uri.host;
  return Uri(
    scheme: uri.scheme,
    host: host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}

String get _envBase {
  try {
    return dotenv.env['BASE_URL'] ?? '';
  } catch (_) {
    // Read before `dotenv.load`, which is the case in a widget test.
    return '';
  }
}
