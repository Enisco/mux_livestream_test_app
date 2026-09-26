/// Going live.
///
/// A livestream is neither an upload nor a post: nothing is sent over HTTP
/// but the session's own details, and the video goes to Mux over **RTMP**
/// from the device's camera. `POST /v1/media` refuses to create one at all.
///
/// The sequence, all of it verified against staging:
///
///  1. `POST /v1/media/live/creator/{id}/provision` — the RTMP URL and the
///     stream key. Ingest starts **disabled**.
///  2. `POST /v1/media/live/creator/{id}/sessions` — the session, with its
///     title, description, categories and replay policy.
///  3. `POST /v1/media/live/streams/{id}/ingest/arm` — opens a bounded
///     window (about fifteen minutes) in which Mux will accept the
///     encoder. Without it the push is refused, because a durable Mux
///     livestream bills for ingest whenever it accepts data.
///  4. The device pushes RTMP.
///  5. `POST /v1/media/live/streams/{id}/start` — `connecting` until the
///     provider sees the encoder, then `live`.
///  6. `POST /v1/media/live/streams/{id}/end` — `{idempotencyKey, reason}`.
library;

/// Where a session is in its life, from `livestreamRuntimeStatus`.
enum LiveRuntime {
  idle,

  /// Start has been asked for and the backend is waiting for the encoder.
  /// It waits about fifteen minutes before giving up.
  connecting,

  live,

  /// The encoder dropped and the backend is waiting for it to come back.
  reconnecting,

  ended,
  other;

  static LiveRuntime parse(String? raw) => switch (raw) {
    'idle' => LiveRuntime.idle,
    'connecting' => LiveRuntime.connecting,
    'live' => LiveRuntime.live,
    'reconnecting' => LiveRuntime.reconnecting,
    'ended' => LiveRuntime.ended,
    _ => LiveRuntime.other,
  };

  bool get isOnAir => this == LiveRuntime.live;

  /// Whether ending is the right word for stopping now.
  bool get isBroadcasting =>
      this == LiveRuntime.live ||
      this == LiveRuntime.connecting ||
      this == LiveRuntime.reconnecting;
}

/// What happens to the recording once the broadcast ends.
enum ReplayPolicy {
  /// The design's promise: "Your recording will be saved and published as
  /// a replay automatically."
  autoPublish('auto_publish'),
  savePrivate('save_private'),
  discard('discard');

  const ReplayPolicy(this.slug);

  final String slug;
}

/// What the creator filled in before going live.
class LiveSessionDraft {
  const LiveSessionDraft({
    required this.title,
    this.description = '',
    this.categorySlugs = const [],
    this.visibility = 'public',
    this.thumbnailFileId,
    this.replayPolicy = ReplayPolicy.autoPublish,
    this.notifyFollowers = true,
  });

  /// Required. Everything else the session will take is optional.
  final String title;

  final String description;
  final List<String> categorySlugs;
  final String visibility;

  /// The live cover art, from the media thumbnail ticket.
  final String? thumbnailFileId;

  final ReplayPolicy replayPolicy;

  /// "Go Live and notify subscribers" — the button's second half.
  final bool notifyFollowers;

  /// What `POST /v1/media/live/creator/{id}/sessions` takes.
  ///
  /// `publish` is left alone: a session is published by starting it, not by
  /// asking at creation.
  Map<String, dynamic> toJson() => {
    'title': title,
    if (description.isNotEmpty) 'description': description,
    if (categorySlugs.isNotEmpty) 'categorySlugs': categorySlugs,
    'visibility': visibility,
    'thumbnailFileId': ?thumbnailFileId,
    'replayPolicy': replayPolicy.slug,
    'notifyFollowers': notifyFollowers,
  };

  bool get isReady => title.trim().isNotEmpty;
}

/// One currency's worth of giving during a broadcast.
///
/// Money is grouped by the settlement currency each payment was quoted in.
/// Totals in different currencies are never added together.
class GivingTotal {
  const GivingTotal({required this.currency, required this.grossMinor});

  factory GivingTotal.fromJson(Map<String, dynamic> json) => GivingTotal(
    currency: json['currency'] as String? ?? '',
    grossMinor: (json['provisionalGrossMinor'] as num?)?.toInt() ?? 0,
  );

  final String currency;

  /// Provisional gross, in minor units — the creator-facing figure.
  final int grossMinor;
}

/// `GET /v1/media/live/streams/{id}/studio` — the authoritative snapshot.
///
/// It is what the broadcast screen's counters read. The contract also
/// carries these over a Socket.IO `/live` namespace; the app has no socket
/// client. `LiveSocketService` follows the studio room now, and this stays
/// the authority behind it — read on open and after every reconnect.
class LivestreamStudio {
  const LivestreamStudio({
    required this.runtime,
    this.isLiveNow = false,
    this.startedAt,
    this.viewerCount = 0,
    this.peakViewerCount = 0,
    this.likeCount = 0,
    this.prayerCount = 0,
    this.giving,
    this.ingestStatus = '',
    this.encoderStatus = '',
    this.armedUntil,
  });

  factory LivestreamStudio.fromJson(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>? ?? const {};
    final presence = json['presence'] as Map<String, dynamic>? ?? const {};
    final connection = json['connection'] as Map<String, dynamic>? ?? const {};
    final metrics = json['metrics'] as Map<String, dynamic>? ?? const {};
    final giving = metrics['giving'] as Map<String, dynamic>?;
    final prayers = metrics['prayers'] as Map<String, dynamic>? ?? const {};

    return LivestreamStudio(
      runtime: LiveRuntime.parse(session['livestreamRuntimeStatus'] as String?),
      isLiveNow: session['isLiveNow'] as bool? ?? false,
      startedAt: DateTime.tryParse(session['startedAt'] as String? ?? ''),
      viewerCount: (presence['viewerCount'] as num?)?.toInt() ?? 0,
      peakViewerCount: (presence['peakViewerCount'] as num?)?.toInt() ?? 0,
      likeCount: (session['engagementLikeCount'] as num?)?.toInt() ?? 0,
      prayerCount: (prayers['count'] as num?)?.toInt() ?? 0,
      // Null when the payment service is unreachable. It must not be shown
      // as a zero in a made-up currency, so it stays null here too.
      giving: giving == null
          ? null
          : [
              for (final row in giving['settlementTotals'] as List? ?? const [])
                if (row is Map<String, dynamic>) GivingTotal.fromJson(row),
            ],
      ingestStatus: connection['ingestStatus'] as String? ?? '',
      encoderStatus: connection['encoderStatus'] as String? ?? '',
      armedUntil: DateTime.tryParse(connection['armedUntil'] as String? ?? ''),
    );
  }

  final LiveRuntime runtime;
  final bool isLiveNow;
  final DateTime? startedAt;

  final int viewerCount;
  final int peakViewerCount;
  final int likeCount;

  /// Only ever a count: nothing lists the requests themselves
  /// (OPEN_ISSUES 22).
  final int prayerCount;

  /// Null when the payment service could not be reached.
  final List<GivingTotal>? giving;

  final String ingestStatus;
  final String encoderStatus;
  final DateTime? armedUntil;

  /// The first settlement currency, which is the one the pill shows. Others
  /// are never folded into it.
  GivingTotal? get headlineGiving =>
      (giving == null || giving!.isEmpty) ? null : giving!.first;

  static const empty = LivestreamStudio(runtime: LiveRuntime.idle);

  /// Folds a socket event into the last snapshot.
  ///
  /// Events carry a slice of the state, not all of it, so anything the event
  /// does not mention has to survive — a viewer-count tick must not blank the
  /// giving totals it knows nothing about.
  LivestreamStudio copyWith({
    LiveRuntime? runtime,
    bool? isLiveNow,
    DateTime? startedAt,
    int? viewerCount,
    int? peakViewerCount,
    int? likeCount,
    int? prayerCount,
    List<GivingTotal>? giving,
    String? ingestStatus,
    String? encoderStatus,
    DateTime? armedUntil,
  }) => LivestreamStudio(
    runtime: runtime ?? this.runtime,
    isLiveNow: isLiveNow ?? this.isLiveNow,
    startedAt: startedAt ?? this.startedAt,
    viewerCount: viewerCount ?? this.viewerCount,
    peakViewerCount: peakViewerCount ?? this.peakViewerCount,
    likeCount: likeCount ?? this.likeCount,
    prayerCount: prayerCount ?? this.prayerCount,
    giving: giving ?? this.giving,
    ingestStatus: ingestStatus ?? this.ingestStatus,
    encoderStatus: encoderStatus ?? this.encoderStatus,
    armedUntil: armedUntil ?? this.armedUntil,
  );
}

/// Why going live could not go ahead, in terms the screen can explain.
enum LiveFailure {
  /// Camera or microphone refused.
  noPermission,

  /// Another session already owns the encoder, or one is already running.
  conflict,

  /// The arm lease ran out before the encoder connected.
  notArmed,

  network,
  rejected,
}

class LiveException implements Exception {
  const LiveException(this.failure, [this.message]);

  final LiveFailure failure;
  final String? message;

  @override
  String toString() => 'LiveException($failure, $message)';
}
