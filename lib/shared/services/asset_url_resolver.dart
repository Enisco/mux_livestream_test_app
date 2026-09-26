import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Turns a storage key from the discovery feed into something an
/// `Image.network` can load.
///
/// Only **media** rows arrive with a ready `thumbnailUrl`
/// (`/v1/public/media/{id}/assets/thumbnail`). Everything else — posts,
/// events, devotional series, media series and creator avatars — carries a
/// bare storage key instead:
///
/// ```
/// public/thumbnail/{creatorId}/{uuid}-cropped.jpg
/// ```
///
/// Those keys are the path of an object on the public CloudFront
/// distribution, which is how the content service's own `bodyEmbeds`
/// resolver hands them back (`{cdn}/public/attachment/...`). So the key is
/// already the URL path and nothing has to be signed or looked up — it just
/// needs the host in front of it.
///
/// The host is environment-specific, so it comes from `CDN_BASE_URL` rather
/// than being compiled in; a build that forgets to set it degrades to no
/// artwork rather than pointing production at staging's bucket.
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
  ///
  /// A key that is already absolute is passed through: the feed is free to
  /// start sending resolved URLs, and that should not break here.
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

  /// A media's own still, served by the API rather than the CDN.
  ///
  /// `GET /v1/public/media/{id}/assets/thumbnail` is public and answers a
  /// 302 to a signed Mux image — which for a video with no uploaded cover is
  /// the generated first frame. It is the only way to show a still for
  /// anything whose `thumbnailSource` is `mux_auto`, because those rows carry
  /// no `thumbnailKey` at all.
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
