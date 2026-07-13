import '../features/discovery/models/media_detail.dart';

class PlaybackInfoCache {
  static const _ttl = Duration(minutes: 5);
  final Map<String, _Entry> _cache = {};

  PlaybackInfo? get(String mediaId) {
    final e = _cache[mediaId];
    if (e == null) return null;
    if (DateTime.now().difference(e.at) > _ttl) {
      _cache.remove(mediaId);
      return null;
    }
    return e.info;
  }

  void put(String mediaId, PlaybackInfo info) {
    _cache[mediaId] = _Entry(info, DateTime.now());
    _evictExpired();
  }

  void _evictExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, e) => now.difference(e.at) > _ttl);
  }
}

class _Entry {
  final PlaybackInfo info;
  final DateTime at;
  _Entry(this.info, this.at);
}
