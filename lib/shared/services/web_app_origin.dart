import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Where the GospelTube web app lives, worked out from the API host.
///
/// Nothing in `.env` names it: the file carries the API and the CDN and
/// nothing else. The two hosts differ by a single label —
/// `api.staging.gospeltube.tv` against `app.staging.gospeltube.tv`, which is
/// also what the app-link entries in `AndroidManifest.xml` and
/// `Runner.entitlements` verify — so it is derived rather than added as a
/// second setting that could drift out of step with the first.
///
/// This is only ever used for URLs a *browser* is sent to. Nothing
/// authenticated goes through it.
String? webAppOrigin({String? apiBase}) {
  final raw = (apiBase ?? _envBase).trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority) return null;
  // Only the leading label is rewritten. A host that is not `api.<rest>` is
  // left alone rather than guessed at: a wrong origin is worse than the
  // one we were given.
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
