import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:test_app/core/logger.dart';

enum PlaybackKind { audio, video }

/// Turns a media id into a playable URL. Injected so the controller does not
/// have to know about repositories or caches.
typedef MediaUrlLookup = Future<String?> Function(String mediaId);

/// What is playing, and what analytics needs to know about it.
///
/// Surfaces supply this rather than a bare id so every beacon carries the
/// creator and the surface it was started from — the controller is the only
/// place that sees the whole playback session, so it is the only place that can
/// report it honestly.
@immutable
class PlaybackTarget {
  const PlaybackTarget({
    required this.mediaId,
    this.creatorId = '',
    this.mediaType,
    this.source = 'unknown',
    this.title,
    this.artist,
    this.artworkUrl,
  });

  final String mediaId;
  final String creatorId;

  /// `video`, `music` or `livestream` when the surface knows it.
  final String? mediaType;

  /// Where the play was started from — `home_feed`, `creator_channel`,
  /// `search`, `suggested_content`…
  final String source;

  /// What the system's notification and lock screen show. Only audio surfaces
  /// need to fill these in; a feed video is never published to a media session.
  final String? title;
  final String? artist;
  final String? artworkUrl;
}

/// Bookkeeping for the media now playing: what has already been reported, and
/// when the next heartbeat is due.
///
/// Beacons carry *deltas* that the server sums, so getting this wrong inflates
/// or loses watch time. Kept separate from the controller so the arithmetic can
/// be tested without a decoder.
class PlaybackSession {
  PlaybackSession({
    required this.target,
    Duration startAt = Duration.zero,
    this.progressEvery = const Duration(seconds: 5),
  }) : _reportedUpTo = startAt;

  final PlaybackTarget target;

  /// Minimum playback covered before another `progress` beacon goes out. The
  /// server rejects bursts below its own floor (~3s).
  final Duration progressEvery;

  Duration _reportedUpTo;

  /// True once `view_started` has gone out; a session that never started must
  /// not report an end.
  bool started = false;

  /// Set once the item completes — terminal, so a later stop stays quiet.
  bool finished = false;

  Duration get reportedUpTo => _reportedUpTo;

  /// Watch time accumulated since the last beacon.
  Duration pendingAt(Duration position) =>
      position > _reportedUpTo ? position - _reportedUpTo : Duration.zero;

  /// The delta to report at [position], or null if the heartbeat is not due.
  Duration? advance(Duration position) {
    // A seek backwards is not negative watch time — re-anchor and say nothing.
    if (position < _reportedUpTo) {
      _reportedUpTo = position;
      return null;
    }
    final delta = position - _reportedUpTo;
    if (delta < progressEvery) return null;
    _reportedUpTo = position;
    return delta;
  }

  /// Closes the books at [position] and returns the final delta.
  Duration settle(Duration position) {
    final delta = pendingAt(position);
    _reportedUpTo = position;
    return delta;
  }

  /// Moves the mark without reporting — used after a seek, so jumping ahead is
  /// never billed as watch time.
  void anchor(Duration position) => _reportedUpTo = position;
}

/// Receives the playback session as it happens, for analytics beacons.
///
/// Kept as an interface so the controller stays free of the analytics stack and
/// can be tested without one.
abstract class PlaybackReporter {
  void viewStarted(PlaybackTarget target, Duration at);
  void progress(PlaybackTarget target, Duration at, Duration delta);
  void played(PlaybackTarget target, Duration at);
  void paused(PlaybackTarget target, Duration at, Duration delta);
  void sought(PlaybackTarget target, Duration to);
  void completed(PlaybackTarget target, Duration at, Duration delta);
  void viewEnded(PlaybackTarget target, Duration at, Duration delta);
}

/// What is playing right now, for widgets to render against.
@immutable
class PlaybackState {
  const PlaybackState({
    this.mediaId,
    this.kind,
    this.target,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final String? mediaId;
  final PlaybackKind? kind;

  /// What is playing, for anything that needs more than its id — the media
  /// session's title and artwork, for one.
  final PlaybackTarget? target;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;

  bool isActive(String id) => mediaId == id;

  bool isPlaying(String id) => mediaId == id && playing;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  PlaybackState copyWith({
    String? mediaId,
    PlaybackKind? kind,
    PlaybackTarget? target,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
  }) => PlaybackState(
    mediaId: mediaId ?? this.mediaId,
    kind: kind ?? this.kind,
    target: target ?? this.target,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

/// What a surface needs from playback, minus the decoder.
///
/// Cards and detail heroes talk to this rather than to [PlaybackController]
/// directly, so their behaviour can be tested without a real media engine.
/// Widgets that actually render video still need the concrete controller for
/// its `videoController`.
abstract class PlaybackHandle {
  ValueListenable<PlaybackState> get state;

  /// Global mute, shared by every video surface.
  ValueListenable<bool> get muted;

  /// Whether the fullscreen surface currently owns the video.
  ///
  /// Only one `Video` widget may be attached to a controller at a time, so the
  /// inline hero stands down while this is set rather than both rendering.
  ValueListenable<bool> get fullscreen;

  void setFullscreen(bool value);

  bool isActive(String mediaId);
  bool isPlaying(String mediaId);

  /// Plays by id, looking the stream URL up on the way.
  ///
  /// Asking for the media already loaded **toggles** it, so this is for taps.
  /// Autoplay must use [ensurePlaying].
  Future<void> playMedia({
    required PlaybackTarget target,
    required PlaybackKind kind,
  });

  /// Starts [target], or resumes it if it is already the loaded media.
  ///
  /// Never pauses. Autoplay re-evaluates constantly while a card is on screen,
  /// and a toggle there would switch off the very video it just started.
  Future<void> ensurePlaying({
    required PlaybackTarget target,
    required PlaybackKind kind,
  });

  /// Plays a known URL, resuming in place if that media is already loaded.
  Future<void> play({
    required PlaybackTarget target,
    required String url,
    required PlaybackKind kind,
    Duration? startAt,
  });

  Future<void> pause();
  Future<void> resume();
  Future<void> togglePlayPause();
  Future<void> seek(Duration to);
  Future<void> setMuted(bool value);
  Future<void> toggleMuted();
  Future<void> stop();
  Future<void> stopIfActive(String mediaId);
  Future<void> pauseIfActive(String mediaId);

  /// How fast the current media plays. 1.0 is normal.
  ValueListenable<double> get rate;

  Future<void> setRate(double value);

  /// The video qualities this stream offers, "Auto" first.
  ///
  /// Empty until a stream is open and its renditions are known — a
  /// progressive file usually offers exactly one, so the control hides
  /// itself rather than showing a menu with nothing to choose.
  ValueListenable<List<String>> get qualities;

  ValueListenable<String> get quality;

  Future<void> setQuality(String label);
}

/// The app's single media pipeline.
///
/// Everything that plays — feed cards, detail heroes, the fullscreen view —
/// shares this one `Player`, which is what makes the guarantees hold: only one
/// stream is ever audible, audio survives scrolling and navigation, and opening
/// a detail continues from wherever the card had reached rather than starting
/// over.
///
/// Widgets must never build their own `Player`. Two players means two audio
/// sessions, and the second one silently steals focus from the first.
class PlaybackController implements PlaybackHandle {
  PlaybackController({
    Player? player,
    MediaUrlLookup? resolveUrl,
    PlaybackReporter? reporter,
  }) : _player = player ?? Player(configuration: const PlayerConfiguration()),
       _resolveUrl = resolveUrl,
       _reporter = reporter {
    _videoController = VideoController(_player);
    _listen();
  }

  final Player _player;
  final MediaUrlLookup? _resolveUrl;
  final PlaybackReporter? _reporter;

  /// The session being reported on. Null between media.
  PlaybackSession? _session;
  late final VideoController _videoController;

  /// The surface currently allowed to render video. Only one `Video` widget
  /// may be mounted against a controller at a time.
  VideoController get videoController => _videoController;

  @override
  final ValueNotifier<PlaybackState> state = ValueNotifier(
    const PlaybackState(),
  );

  /// Global, shared by every surface. Video starts muted like a feed should;
  /// audio is never muted, since the reader asked for it explicitly.
  @override
  final ValueNotifier<bool> muted = ValueNotifier(true);

  @override
  final ValueNotifier<bool> fullscreen = ValueNotifier(false);

  @override
  final ValueNotifier<double> rate = ValueNotifier(1.0);

  @override
  final ValueNotifier<List<String>> qualities = ValueNotifier(const []);

  @override
  final ValueNotifier<String> quality = ValueNotifier(_autoQuality);

  static const _autoQuality = 'Auto';

  /// The rates the design's menu offers.
  static const rateChoices = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  /// Label → the track behind it, for a stream media_kit enumerates.
  final Map<String, VideoTrack> _tracks = {};

  /// Whether the open stream is HLS, which media_kit does **not** enumerate
  /// as separate video tracks — its renditions are switched by setting
  /// `hls-bitrate` on the native player instead.
  bool _isHls = false;

  /// Mux serves HLS, and an `.m3u8` is the only thing that needs the
  /// `hls-bitrate` path rather than track selection.
  static bool _looksLikeHls(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.contains('.m3u8');
  }

  @override
  void setFullscreen(bool value) => fullscreen.value = value;

  final List<StreamSubscription<dynamic>> _subs = [];
  String? _openingId;

  /// Gives up on a stream that never opens at all.
  ///
  /// An unusable URL does not raise — the player just sits there — so without
  /// this the surface could show a dead frame forever.
  ///
  /// It must be slow and hard to trigger: a cold HLS start on a weak device can
  /// take well over 20s to produce its first position tick, and stopping such a
  /// stream restarts it in a loop that never reaches the first frame.
  Timer? _startWatchdog;
  static const _startTimeout = Duration(seconds: 45);

  void _listen() {
    _subs.addAll([
      _player.stream.playing.listen(
        (v) => state.value = state.value.copyWith(playing: v),
      ),
      _player.stream.buffering.listen((v) {
        logger.d(
          'PB buffering=$v pos=${state.value.position} dur=${state.value.duration}',
        );
        state.value = state.value.copyWith(buffering: v);
      }),
      _player.stream.position.listen((v) {
        state.value = state.value.copyWith(position: v);
        _onPosition(v);
      }),
      _player.stream.duration.listen(
        (v) => state.value = state.value.copyWith(duration: v),
      ),
      _player.stream.completed.listen((done) {
        if (done) _reportCompleted();
      }),
      _player.stream.error.listen((e) => logger.w('Playback error: $e')),
      _player.stream.tracks.listen(_onTracks),
      _player.stream.track.listen(_onTrack),
    ]);
  }

  /// What the open stream can offer.
  ///
  /// HLS renditions are not video tracks, so for an HLS stream this reports
  /// nothing and [setQuality] drives `hls-bitrate` instead. For everything
  /// else the tracks are the qualities.
  void _onTracks(Tracks tracks) {
    if (_isHls) return;
    _tracks
      ..clear()
      ..[_autoQuality] = VideoTrack.auto();
    final labels = <String>[_autoQuality];
    for (var i = 0; i < tracks.video.length; i++) {
      final track = tracks.video[i];
      final label = _trackLabel(track, i);
      if (label == _autoQuality || _tracks.containsKey(label)) continue;
      labels.add(label);
      _tracks[label] = track;
    }
    // One rendition is no choice at all; the control hides on an empty list.
    qualities.value = labels.length > 1 ? labels : const [];
    if (!labels.contains(quality.value)) quality.value = _autoQuality;
  }

  void _onTrack(Track track) {
    if (_isHls) return;
    for (final entry in _tracks.entries) {
      if (entry.value.id == track.video.id) {
        quality.value = entry.key;
        return;
      }
    }
  }

  static String _trackLabel(VideoTrack track, int index) {
    if (track.id == 'auto') return _autoQuality;
    final title = track.title;
    if (title != null && title.isNotEmpty) return title;
    if ((track.h ?? 0) > 0) return '${track.h}p';
    if ((track.w ?? 0) > 0) return '${track.w}p';
    return 'Track ${index + 1}';
  }

  @override
  Future<void> setRate(double value) async {
    final clamped = value.clamp(0.25, 4.0).toDouble();
    rate.value = clamped;
    try {
      await _player.setRate(clamped);
    } catch (e) {
      logger.w('Could not set playback rate', error: e);
    }
  }

  @override
  Future<void> setQuality(String label) async {
    if (!qualities.value.contains(label)) return;
    quality.value = label;
    try {
      if (_isHls) {
        // media_kit does not expose HLS renditions as tracks; the native
        // player picks one by bitrate ceiling, and "no" means let it choose.
        final ceiling = _hlsBitrates[label];
        final platform = _player.platform;
        if (platform is NativePlayer) {
          await platform.setProperty(
            'hls-bitrate',
            ceiling == null || ceiling == 0 ? 'no' : '$ceiling',
          );
        }
        return;
      }
      final track = _tracks[label];
      if (track != null) await _player.setVideoTrack(track);
    } catch (e) {
      logger.w('Could not set video quality', error: e);
    }
  }

  /// Label → bitrate ceiling, for an HLS stream whose manifest has been read.
  final Map<String, int> _hlsBitrates = {};

  /// The stream currently open, so an offer can be matched to it.
  String? _openUrl;

  final _offeredHls = HlsQualityOffers();

  /// Offers the renditions an HLS manifest advertises, for [forUrl].
  ///
  /// The controller does not fetch the manifest itself, because a slow or
  /// missing one must never sit between a reader and their video.
  void offerHlsQualities(Map<String, int> byLabel, {required String forUrl}) {
    final ready = _offeredHls.offer(
      forUrl,
      byLabel,
      openUrl: _isHls ? _openUrl : null,
    );
    if (ready != null) _applyHlsQualities(ready);
  }

  void _applyHlsQualities(Map<String, int> byLabel) {
    _hlsBitrates
      ..clear()
      ..[_autoQuality] = 0
      ..addAll(byLabel);
    final labels = [
      _autoQuality,
      ...byLabel.keys.where((k) => k != _autoQuality),
    ];
    qualities.value = labels.length > 1 ? labels : const [];
    if (!labels.contains(quality.value)) quality.value = _autoQuality;
  }

  void _armStartWatchdog(String mediaId) {
    _startWatchdog?.cancel();
    _startWatchdog = Timer(_startTimeout, () {
      _startWatchdog = null;
      final state = this.state.value;
      if (state.mediaId != mediaId) return;
      // A reported duration means the stream opened and parsed — it is alive,
      // just slow. Only something that produced neither position nor duration
      // is actually dead.
      if (state.position > Duration.zero || state.duration > Duration.zero) {
        return;
      }
      logger.w('$mediaId never opened in $_startTimeout — giving up');
      unawaited(stop());
    });
  }

  void _onPosition(Duration at) {
    // Playing at last: the watchdog has nothing to catch.
    if (at > Duration.zero && _startWatchdog != null) {
      _startWatchdog!.cancel();
      _startWatchdog = null;
    }
    final session = _session;
    if (session == null || !session.started || session.finished) return;
    final delta = session.advance(at);
    if (delta != null) _reporter?.progress(session.target, at, delta);
  }

  void _reportCompleted() {
    final session = _session;
    if (session == null || !session.started || session.finished) return;
    final at = state.value.position;
    _reporter?.completed(session.target, at, session.settle(at));
    // Terminal for this item: a later stop must not also report a view end.
    session.finished = true;
  }

  /// Closes the reporting session for whatever was playing.
  void _endSession() {
    final session = _session;
    if (session != null && session.started && !session.finished) {
      final at = state.value.position;
      _reporter?.viewEnded(session.target, at, session.settle(at));
    }
    _session = null;
  }

  @override
  bool isActive(String mediaId) => state.value.isActive(mediaId);

  @override
  bool isPlaying(String mediaId) => state.value.isPlaying(mediaId);

  /// Starts [mediaId], replacing whatever was playing.
  ///
  /// Re-requesting the media that is already loaded resumes it in place rather
  /// than reopening, which is what lets a detail screen pick up mid-stream.
  @override
  Future<void> play({
    required PlaybackTarget target,
    required String url,
    required PlaybackKind kind,
    Duration? startAt,
  }) async {
    final mediaId = target.mediaId;
    if (state.value.mediaId == mediaId) {
      await resume();
      return;
    }
    if (_openingId == mediaId) return;
    _openingId = mediaId;

    // Whatever was playing is over as far as analytics is concerned.
    _endSession();

    state.value = PlaybackState(
      mediaId: mediaId,
      kind: kind,
      target: target,
      buffering: true,
    );

    // A new stream brings its own renditions, and the rate is a per-media
    // choice — carrying 2x from the last video into the next one would be a
    // surprise.
    _isHls = _looksLikeHls(url);
    _openUrl = url;
    _tracks.clear();
    qualities.value = const [];
    quality.value = _autoQuality;
    if (rate.value != 1.0) unawaited(setRate(1.0));

    // The manifest is read off the network in parallel with opening the
    // stream, so the renditions can arrive either side of this point. An
    // offer that got here first is applied now rather than lost.
    if (_isHls) {
      final offered = _offeredHls.forUrl(url);
      if (offered != null) _applyHlsQualities(offered);
    }

    try {
      await _player.open(Media(url), play: false);
      await _applyVolume(kind);
      if (startAt != null && startAt > Duration.zero) {
        await _player.seek(startAt);
      }
      await _player.play();

      final session = PlaybackSession(
        target: target,
        startAt: startAt ?? Duration.zero,
      )..started = true;
      _session = session;
      _reporter?.viewStarted(target, session.reportedUpTo);
      _armStartWatchdog(mediaId);
    } catch (e) {
      logger.e('Could not start $mediaId', error: e);
      state.value = const PlaybackState();
      _session = null;
    } finally {
      if (_openingId == mediaId) _openingId = null;
    }
  }

  Future<void> _applyVolume(PlaybackKind kind) async {
    // Muting only ever applies to video; audio the reader started should be
    // audible whatever the feed's mute state happens to be.
    final silent = kind == PlaybackKind.video && muted.value;
    await _player.setVolume(silent ? 0 : 100);
  }

  @override
  Future<void> setMuted(bool value) async {
    muted.value = value;
    if (state.value.kind == PlaybackKind.video) {
      await _player.setVolume(value ? 0 : 100);
    }
  }

  @override
  Future<void> toggleMuted() => setMuted(!muted.value);

  @override
  Future<void> resume() async {
    if (state.value.mediaId == null) return;
    await _player.play();
    final session = _session;
    if (session != null) {
      _reporter?.played(session.target, state.value.position);
    }
  }

  @override
  Future<void> pause() async {
    if (state.value.mediaId == null) return;
    await _player.pause();
    final session = _session;
    if (session == null) return;
    final at = state.value.position;
    _reporter?.paused(session.target, at, session.settle(at));
  }

  @override
  Future<void> togglePlayPause() async {
    if (state.value.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  @override
  Future<void> seek(Duration to) async {
    await _player.seek(to);
    final session = _session;
    if (session == null) return;
    _reporter?.sought(session.target, to);
    // Everything up to the new point is accounted for; jumping must not be
    // billed as watch time.
    session.anchor(to);
  }

  /// Ends playback entirely and clears the active media.
  @override
  Future<void> stop() async {
    if (state.value.mediaId == null) return;
    _startWatchdog?.cancel();
    _startWatchdog = null;
    await _player.stop();
    _endSession();
    state.value = const PlaybackState();
  }

  /// Plays by id, resolving the stream URL on the way.
  ///
  /// Feed cards only know an id, so this is the entry point they use. Already
  /// playing that id? It just resumes, so a second tap never restarts a track.
  @override
  Future<void> playMedia({
    required PlaybackTarget target,
    required PlaybackKind kind,
  }) async {
    final mediaId = target.mediaId;
    if (state.value.mediaId == mediaId) {
      await togglePlayPause();
      return;
    }
    final resolve = _resolveUrl;
    if (resolve == null) {
      logger.w('No media resolver registered');
      return;
    }
    // Show the card as busy while the URL is fetched, or a tap feels dead.
    state.value = PlaybackState(
      mediaId: mediaId,
      kind: kind,
      target: target,
      buffering: true,
    );
    final url = await resolve(mediaId);
    if (url == null || url.isEmpty) {
      logger.w('No playable URL for $mediaId');
      if (state.value.mediaId == mediaId) {
        state.value = const PlaybackState();
      }
      return;
    }
    // A newer tap may have landed while we were resolving.
    if (state.value.mediaId != mediaId) return;
    state.value = const PlaybackState();
    await play(target: target, url: url, kind: kind);
  }

  @override
  Future<void> ensurePlaying({
    required PlaybackTarget target,
    required PlaybackKind kind,
  }) async {
    if (state.value.mediaId == target.mediaId) {
      if (!state.value.playing) await resume();
      return;
    }
    await playMedia(target: target, kind: kind);
  }

  /// Stops only if [mediaId] is the one playing — used when a card scrolls out
  /// of view, so it cannot cut off whatever replaced it.
  @override
  Future<void> stopIfActive(String mediaId) async {
    if (state.value.mediaId == mediaId) await stop();
  }

  /// Pauses only if [mediaId] is the one playing.
  @override
  Future<void> pauseIfActive(String mediaId) async {
    if (state.value.mediaId == mediaId) await pause();
  }

  Future<void> dispose() async {
    _startWatchdog?.cancel();
    _startWatchdog = null;
    _endSession();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    await _player.dispose();
    state.dispose();
    muted.dispose();
    fullscreen.dispose();
  }
}

/// Remembers which renditions belong to which stream.
///
/// The manifest is read over the network while the stream is opening, so the
/// two race in both directions: on a fast CDN the renditions can arrive
/// before the player has opened anything, and `play` clears the quality list
/// as it starts — so an offer that landed first used to be silently thrown
/// away and the quality menu simply never appeared.
///
/// Keyed by URL rather than applied blind, because applying one video's
/// renditions to another would offer qualities that do not exist on it.
class HlsQualityOffers {
  final Map<String, Map<String, int>> _byUrl = {};

  /// How many streams' offers to remember. A session can open a great many.
  static const maxRemembered = 8;

  /// Records an offer, and returns it when it belongs to the open stream —
  /// null when there is nothing to apply yet.
  Map<String, int>? offer(
    String url,
    Map<String, int> byLabel, {
    String? openUrl,
  }) {
    if (byLabel.isEmpty || url.isEmpty) return null;
    if (_byUrl.length >= maxRemembered) _byUrl.clear();
    _byUrl[url] = byLabel;
    return openUrl == url ? byLabel : null;
  }

  /// What was offered for [url], for a stream that has just opened.
  Map<String, int>? forUrl(String url) => _byUrl[url];
}
