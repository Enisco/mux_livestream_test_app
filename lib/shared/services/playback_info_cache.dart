import 'dart:convert';

import 'package:test_app/models/discovery_models/media_detail.dart';

/// Holds resolved playback URLs for as long as they are actually valid.
///
/// These are signed links: the Mux URL carries a JWT whose `exp` is the real
/// deadline. Serving one past that point does not fail loudly — the player
/// simply never produces a frame and the card sits at 0:00 — so the token's own
/// expiry is what governs here, not a flat guess.
class PlaybackInfoCache {
  /// Used when a URL carries no readable expiry.
  static const _fallbackTtl = Duration(minutes: 5);

  /// Dropped this long before the token actually expires, so a stream cannot
  /// die part-way through starting.
  static const _margin = Duration(seconds: 30);

  final Map<String, _Entry> _cache = {};

  PlaybackInfo? get(String mediaId) {
    final entry = _cache[mediaId];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(mediaId);
      return null;
    }
    return entry.info;
  }

  void put(String mediaId, PlaybackInfo info) {
    _cache[mediaId] = _Entry(info, _expiryFor(info.playbackUrl));
    _evictExpired();
  }

  void clear() => _cache.clear();

  /// The signed URL's own deadline, or [_fallbackTtl] from now.
  static DateTime _expiryFor(String url) {
    final fallback = DateTime.now().add(_fallbackTtl);
    final token = Uri.tryParse(url)?.queryParameters['token'];
    final exp = token == null ? null : _jwtExpiry(token);
    if (exp == null) return fallback;

    final safe = exp.subtract(_margin);
    // Never hold something longer than the plain TTL, and never cache a URL
    // that is already past saving.
    if (safe.isBefore(DateTime.now())) return DateTime.now();
    return safe.isBefore(fallback) ? safe : fallback;
  }

  static DateTime? _jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final decoded = jsonDecode(utf8.decode(base64.decode(payload)));
      if (decoded is! Map<String, dynamic>) return null;
      final exp = decoded['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    } catch (_) {
      // An unreadable token is not a reason to refuse to play; fall back.
      return null;
    }
  }

  void _evictExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, e) => now.isAfter(e.expiresAt));
  }
}

class _Entry {
  const _Entry(this.info, this.expiresAt);

  final PlaybackInfo info;
  final DateTime expiresAt;
}
