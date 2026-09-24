/// Putting a video (or a piece of audio) on the platform.
///
/// Three mechanisms carry bytes in this app and they are not interchangeable:
///
///  * **Images** — channel photo, banner, thumbnail — go to S3 as a presigned
///    **POST**. See [CreatorAssetRepo].
///  * **Video and audio** go straight to Mux as a **PUT**, against a
///    single-use URL minted by `POST /v1/media/request-upload`.
///  * **Livestreams** are not uploaded at all: they are provisioned and
///    broadcast over RTMP. `POST /v1/media` refuses them outright.
///
/// Everything here was read off staging; the upload routes publish no
/// response schema.
library;

/// What is being uploaded. The `slug` is the API's `mediaType`.
///
/// The ceilings are staging's own `constraints.maxSizeBytes`, held here so an
/// oversized file can be turned away before a ticket is requested. The
/// server's answer is re-read on every upload in case it tightens.
enum MediaUploadKind {
  video('video', 5 * 1024 * 1024 * 1024),
  music('music', 1024 * 1024 * 1024);

  const MediaUploadKind(this.slug, this.maxBytes);

  final String slug;
  final int maxBytes;

  bool get isAudio => this == MediaUploadKind.music;
}

/// `uploadTarget`, which the API restricts to exactly these three. It is not
/// cosmetic: iOS is offered a narrower MIME list than Android.
enum MediaUploadTarget { ios, android, web }

/// A file the creator picked, described the way `request-upload` wants it.
///
/// The bytes are deliberately *not* held: a sermon can run to gigabytes, so
/// the file is streamed from [path] rather than read into memory.
class PickedMediaFile {
  const PickedMediaFile({
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.size,
  });

  final String path;
  final String filename;

  /// One the platform's upload target accepts — see [videoMimeTypes].
  final String mimeType;

  /// Exact byte length. `request-upload` checks it against its ceiling.
  final int size;
}

/// The extensions the picker offers, mapped to the MIME type the API names.
///
/// Verified against `constraints.allowedMimeTypes`. Video is the one that
/// differs by platform: iOS answers
/// `[video/mp4, video/quicktime, video/x-m4v]` and Android adds
/// `video/webm`, so WebM is offered only where it will be accepted. Audio
/// answers the same five everywhere.
Map<String, String> uploadMimeTypes(
  MediaUploadKind kind,
  MediaUploadTarget target,
) => switch (kind) {
  MediaUploadKind.video => {
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    if (target == MediaUploadTarget.android) 'webm': 'video/webm',
  },
  MediaUploadKind.music => const {
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'wav': 'audio/wav',
    'webm': 'audio/webm',
  },
};

/// A single-use Mux upload URL.
class MediaUploadTicket {
  const MediaUploadTicket({
    required this.uploadId,
    required this.uploadUrl,
    this.method = 'PUT',
    this.headers = const {},
    this.expiresAt,
    this.maxSizeBytes,
    this.allowedMimeTypes = const [],
  });

  /// `POST /v1/media/request-upload` answers `{uploadId, uploadUrl, expiresAt,
  /// method, headers, chunkedUpload, resumable, maxChunkSizeBytes,
  /// recommendedPartSizeBytes, playbackPolicy, constraints}`.
  factory MediaUploadTicket.fromJson(Map<String, dynamic> json) {
    final constraints = json['constraints'] as Map<String, dynamic>?;
    return MediaUploadTicket(
      uploadId: json['uploadId'] as String? ?? '',
      uploadUrl: json['uploadUrl'] as String? ?? '',
      method: json['method'] as String? ?? 'PUT',
      headers: {
        for (final entry
            in (json['headers'] as Map<String, dynamic>? ?? const {}).entries)
          entry.key: '${entry.value}',
      },
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      maxSizeBytes: (constraints?['maxSizeBytes'] as num?)?.toInt(),
      allowedMimeTypes: [
        for (final mime
            in constraints?['allowedMimeTypes'] as List? ?? const [])
          if (mime is String) mime,
      ],
    );
  }

  /// What `POST /v1/media` takes as `sourceUploadId`.
  final String uploadId;

  final String uploadUrl;
  final String method;
  final Map<String, String> headers;

  /// One hour on staging. The bytes must be in before this.
  final DateTime? expiresAt;

  final int? maxSizeBytes;
  final List<String> allowedMimeTypes;

  bool get isUsable => uploadId.isNotEmpty && uploadUrl.isNotEmpty;
}

/// Who gets to see it. The API refuses anything else.
enum MediaVisibility {
  public,
  unlisted,
  private;

  String get slug => name;
}

/// What the creator chose in the "When should this go live" sheet.
enum PublishTiming {
  /// Publish as soon as processing finishes.
  now,

  /// Auto-publish at a chosen moment.
  schedule,

  /// Keep it private and unpublished.
  draft,
}

class PublishChoice {
  const PublishChoice.now() : timing = PublishTiming.now, at = null;
  const PublishChoice.draft() : timing = PublishTiming.draft, at = null;
  const PublishChoice.scheduled(DateTime this.at)
    : timing = PublishTiming.schedule;

  final PublishTiming timing;

  /// Local time; the repo sends it as UTC, which is all `scheduledAt` takes —
  /// media has no `scheduledTimezone`, unlike a livestream session.
  final DateTime? at;
}

/// Why an upload could not go through, in terms the screen can explain.
enum MediaUploadFailure {
  /// Bigger than the server's ceiling.
  tooLarge,

  /// A container the platform's upload target will not take.
  unsupportedFormat,

  /// "Monthly upload limit reached (N uploads on current plan)".
  quotaReached,

  /// The Mux ticket is single-use and lives an hour: "sourceUploadId is
  /// invalid or expired. Request upload again." A creator who lingers over
  /// the form long enough will meet this.
  ticketExpired,

  /// "scheduledAt must be in the future".
  scheduleInPast,

  /// The creator backed out mid-upload.
  cancelled,

  network,
  rejected,
}

class MediaUploadException implements Exception {
  const MediaUploadException(this.failure, [this.message]);

  final MediaUploadFailure failure;

  /// The server's own sentence when it had one worth repeating — the quota
  /// message names the plan's limit, which nothing else tells the client.
  final String? message;

  @override
  String toString() => 'MediaUploadException($failure, $message)';
}
