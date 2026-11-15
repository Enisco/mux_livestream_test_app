import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Turns a storage key from the discovery feed into something an
/// `Image.network` can load.
abstract final class AssetUrlResolver {
  /// Rows say which target holds their asset. `origin` means the API serves
  /// it and a full URL came with the row; `cloudfront` means the key is a
  /// path on the CDN.
  static const cdnTargetOrigin = 'origin';

  /// Reading this before `dotenv.load` throws rather than returning empty,
  /// and artwork is never worth taking a screen down for — so an unloaded
  /// environment simply means "no CDN configured".
  static String get base {
    try {
      return (dotenv.env['CDN_BASE_URL'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  /// Whether this build can resolve keys at all.
  static bool get isConfigured => base.isNotEmpty;

  /// The URL for [key], or null when there is nothing to show.
  static String? resolve(String? key) {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (!isConfigured) return null;

    final host = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return '$host/$path';
  }

  /// The artwork for a row, preferring a URL the API already resolved.
  static String? imageFor({String? url, String? key}) {
    final direct = url?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return resolve(key);
  }

  /// The whole ladder for a media row's still, in the order `client-media-
  /// integration.md` gives it: a URL the API already resolved, then a
  /// storage key with the CDN host in front, then the public asset proxy.
  static String? mediaImage({
    String? url,
    String? key,
    String? mediaId,
    String? source,
  }) {
    final direct = imageFor(url: url, key: key);
    if (direct != null) return direct;
    if (source != null && source != muxAutoThumbnail) return null;
    return mediaThumbnail(mediaId);
  }

  /// What `thumbnailSource` says when the still is Mux's own first frame
  /// rather than something a creator uploaded.
  static const muxAutoThumbnail = 'mux_auto';

  /// A media's own still, served by the API rather than the CDN.
  static String? mediaThumbnail(String? mediaId) {
    final id = mediaId?.trim();
    if (id == null || id.isEmpty) return null;
    final base = _apiBase;
    if (base.isEmpty) return null;
    return '$base/v1/public/media/$id/assets/thumbnail';
  }

  static String get _apiBase {
    try {
      final raw = (dotenv.env['BASE_URL'] ?? '').trim();
      return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    } catch (_) {
      return '';
    }
  }
}
