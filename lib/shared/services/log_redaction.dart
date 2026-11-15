/// Things that must never reach a log, however convenient they would be.
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
