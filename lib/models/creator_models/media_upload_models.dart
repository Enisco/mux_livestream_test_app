/// Putting a video (or a piece of audio) on the platform.
library;

import 'package:test_app/shared/services/asset_url_resolver.dart';

/// What is being uploaded. The `slug` is the API's `mediaType`.
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
Map<String, String> uploadMimeTypes(
  MediaUploadKind kind,
  MediaUploadTarget target,
) => switch (kind) {
  // What the two cameras record: `mov` is every iPhone, H.264 or HEVC,
  // and `mp4` is every Android.
  //
  // **This list mirrors the API, it does not guess.** Staging answers
  // `constraints.allowedMimeTypes` with exactly these — see the recorded
  // body in `new_media_test.dart` — so `mkv`, `3gp` and the rest are left
  // out on purpose. Android's picker will happily offer them, and letting
  // one through here would only swap a clear "format not supported" before
  // anything is sent for a failed upload after a ticket has been minted.
  // They belong here when the API takes them and not before.
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

  /// Mux's id for this upload.
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

/// Where a media row stands. The guide's own list, plus the three the
/// refusals name (`under_review`, `blocked`, `archived`) and a fallback,
/// so a status this client has not heard of costs the creator nothing.
enum MediaStatus {
  /// No source yet, or the source was removed.
  draft,

  /// Uploaded; Mux is preparing playback.
  processing,

  /// Playable, not published. Unpublishing returns here.
  ready,

  /// Will publish at `scheduledAt`.
  scheduled,

  /// Live on the channel, for its visibility.
  published,

  /// Mux could not process the file. The source has to go and another
  /// one be uploaded.
  failed,

  underReview('under_review'),
  blocked,
  archived,

  /// Something newer than this client.
  unknown;

  const MediaStatus([this._slug]);

  final String? _slug;

  String get slug => _slug ?? name;

  static MediaStatus of(String? raw) {
    for (final status in values) {
      if (status != unknown && status.slug == raw) return status;
    }
    return unknown;
  }
}

/// A media row as the creator's own routes answer it: `POST
/// /v1/media/drafts`, `GET /v1/media/{id}` and `PATCH /v1/media/{id}` all
/// return the same shape, and every one of them returns the whole row.
class FiledMedia {
  const FiledMedia({
    required this.id,
    this.updatedAt,
    this.status = MediaStatus.unknown,
    this.kind,
    this.title = '',
    this.description = '',
    this.categorySlugs = const [],
    this.visibility,
    this.thumbnailKey,
    this.scheduledAt,
    this.publishedAt,
  });

  factory FiledMedia.fromJson(Map<String, dynamic> json) => FiledMedia(
    id: json['id'] as String? ?? '',
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    status: MediaStatus.of(json['status'] as String?),
    kind: switch (json['type']) {
      'music' => MediaUploadKind.music,
      'video' => MediaUploadKind.video,
      // A livestream row comes back through the same route and is not an
      // upload kind at all. Null rather than a wrong guess.
      _ => null,
    },
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    categorySlugs: [
      for (final slug in json['categorySlugs'] as List? ?? const [])
        if (slug is String && slug.isNotEmpty) slug,
    ],
    visibility: MediaVisibility.values
        .where((v) => v.slug == json['visibility'])
        .firstOrNull,
    thumbnailKey: json['thumbnailKey'] as String?,
    scheduledAt: DateTime.tryParse(
      json['scheduledAt'] as String? ?? '',
    )?.toLocal(),
    publishedAt: DateTime.tryParse(
      json['publishedAt'] as String? ?? '',
    )?.toLocal(),
  );

  final String id;

  /// What `expectedMediaUpdatedAt` carries. The upload route refuses a
  /// ticket when the row has moved on since this was read.
  final DateTime? updatedAt;

  final MediaStatus status;

  /// Video or audio. Null for a livestream row, or a type this client has
  /// not heard of.
  final MediaUploadKind? kind;

  final String title;
  final String description;
  final List<String> categorySlugs;

  /// Who can see it — or **null when the row did not say**, which is not
  /// the same as private.
  final MediaVisibility? visibility;

  /// A thumbnail the creator uploaded, as a CDN key. A video left to Mux
  /// carries none — see [thumbnailUrl].
  final String? thumbnailKey;

  /// Local time. Set means the row publishes itself then.
  final DateTime? scheduledAt;

  /// Local time. Set, ever, closes scheduling for good — see
  /// [canBeScheduled].
  final DateTime? publishedAt;

  bool get isUsable => id.isNotEmpty;

  /// Whether this row may be opened in the editor at all.
  bool get isEditable => switch (status) {
    MediaStatus.archived ||
    MediaStatus.blocked ||
    MediaStatus.underReview => false,
    _ => true,
  };

  /// Whether `scheduledAt` can still be set.
  bool get canBeScheduled =>
      publishedAt == null && status != MediaStatus.published;

  /// What to show in the thumbnail well, or null when there is nothing.
  String? get thumbnailUrl =>
      AssetUrlResolver.resolve(thumbnailKey) ??
      (status == MediaStatus.published && visibility == MediaVisibility.public
          ? AssetUrlResolver.mediaThumbnail(id)
          : null);
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

  /// 409: the draft was saved after the client read it, so the
  /// `expectedMediaUpdatedAt` quoted back is stale. The repo reads the row
  /// again and retries once; this only reaches a screen if that fails too.
  draftChanged,

  /// 409: the draft already has a source. Replacing it means dropping that
  /// one first. The repo does so and retries once.
  sourceAlreadyUploaded,

  /// The creator backed out mid-upload.
  cancelled,

  /// The system picker would not open at all. Nothing to do with the API;
  /// see [CreatorMediaPicker].
  pickerFailed,

  /// The file was picked, and then could not be read. Nothing to do with
  /// the API either, and kept apart from [pickerFailed] because the two
  /// want different sentences: this one means the creator chose something
  /// and the system could not produce it, which is worth a word about
  /// cloud storage. See `CreatorMediaPicker.readFailure` for what used to
  /// cause nearly all of these.
  sourceUnreadable,

  /// 404. The row is gone — deleted from the web studio, or by another
  /// member of the channel, while this screen held it.
  notFound,

  /// 401 or 403. These routes check the member's role: an editor may do
  /// everything here, a viewer nothing. Also what an expired session
  /// looks like.
  notAllowed,

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
