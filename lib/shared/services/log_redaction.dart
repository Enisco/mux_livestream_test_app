/// Things that must never reach a log, however convenient they would be.
///
/// The checkout guide is explicit about this, and the list is not arbitrary —
/// every entry is a credential that works on its own:
///
/// - a **launch ticket** opens the giver's own checkout session in a browser;
/// - a **hosted authorization URL** is the provider's payment page for a
///   specific charge;
/// - an **embedded credential** (`embedded.khaime.token` and its Stripe and
///   Paystack siblings) carries processor credentials outright.
///
/// Debug logs are not private. They go to logcat, which any app with the right
/// permission on a rooted device can read, and they are what gets pasted into
/// a bug report or a support screenshot. A ticket is short-lived and
/// single-use, which lowers the stakes without changing them.
///
/// This redacts the *value* and leaves the key, so a log still shows that a
/// ticket came back — which is the only thing reading it for is good for.
library;

/// The query parameters whose values are credentials wherever they appear.
const _secretParams = {'ticket', 'token', 'code', 'session_token'};

/// The JSON keys whose values are credentials, matched case-insensitively.
const _secretKeys = {
  'launchurl',
  'hostedauthorizationurl',
  'onboardingurl',
  'embedded',
  'ticket',
  'accesstoken',
  'refreshtoken',
  'granttoken',
};

const _mask = '<redacted>';

/// A copy of [body] safe to print.
///
/// Returns the same shape it was given — maps and lists are walked, anything
/// else is stringified — so a caller can drop this in front of an existing
/// log line without changing what the line looks like.
Object? redactSecrets(Object? body) {
  if (body is Map) {
    return {
      for (final entry in body.entries)
        entry.key: _secretKeys.contains(entry.key.toString().toLowerCase())
            ? _mask
            : redactSecrets(entry.value),
    };
  }
  if (body is List) return [for (final item in body) redactSecrets(item)];
  if (body is String) return redactUrl(body);
  return body;
}

/// Strips credential-bearing query parameters from a URL, leaving the rest
/// legible.
///
/// A bare string is the awkward case: a launch URL logged on its own is just
/// text, and dropping every string that looks like a URL would make the logs
/// useless. Only the parameters that are credentials are masked.
String redactUrl(String value) {
  if (!value.contains('://') || !value.contains('?')) return value;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.queryParameters.isEmpty) return value;
  final safe = {
    for (final entry in uri.queryParameters.entries)
      entry.key: _secretParams.contains(entry.key.toLowerCase())
          ? _mask
          : entry.value,
  };
  return uri.replace(queryParameters: safe).toString();
}
