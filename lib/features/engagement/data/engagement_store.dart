import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';

/// What one surface knows about a viewer's relationship to one thing.
@immutable
class EngagementState {
  const EngagementState({
    this.liked = false,
    this.saved = false,
    this.likes = 0,
    this.saves = 0,
    this.comments = 0,
    this.ownsLike = false,
    this.ownsSave = false,
    this.ownsComments = false,
  });

  final bool liked;
  final bool saved;
  final int likes;
  final int saves;
  final int comments;

  final bool ownsLike;
  final bool ownsSave;
  final bool ownsComments;

  /// Counts are shown, never computed from, so a disagreement with the server
  /// must not surface as a negative number.
  static int _floor(int n) => n < 0 ? 0 : n;

  /// This state with the like turned [on], moving the count with it.
  EngagementState withLike(bool on) => EngagementState(
    liked: on,
    saved: saved,
    likes: on == liked ? likes : _floor(likes + (on ? 1 : -1)),
    saves: saves,
    comments: comments,
    ownsLike: true,
    ownsSave: ownsSave,
    ownsComments: ownsComments,
  );

  EngagementState withSave(bool on) => EngagementState(
    liked: liked,
    saved: on,
    likes: likes,
    saves: on == saved ? saves : _floor(saves + (on ? 1 : -1)),
    comments: comments,
    ownsLike: ownsLike,
    ownsSave: true,
    ownsComments: ownsComments,
  );

  EngagementState withComments(int delta) => EngagementState(
    liked: liked,
    saved: saved,
    likes: likes,
    saves: saves,
    comments: _floor(comments + delta),
    ownsLike: ownsLike,
    ownsSave: ownsSave,
    ownsComments: true,
  );
}

/// Posts an interaction, returning whether it ended up on or off.
typedef ToggleInteraction =
    Future<bool> Function({
      required String targetType,
      required String targetId,
      required String interactionType,
    });

typedef SetFollowing =
    Future<void> Function(String creatorId, {required bool follow});

/// The one place the app agrees on "does the viewer like this, and how many
/// others do".
class EngagementStore extends ChangeNotifier {
  /// The two calls it makes are injected rather than the whole repos, so the
  /// arithmetic below can be tested without a locator or a network.
  EngagementStore({ToggleInteraction? toggle, SetFollowing? setFollowing})
    : _postInteraction =
          toggle ?? GetIt.instance<EngagementRepo>().toggleInteraction,
      _setFollowing =
          setFollowing ?? GetIt.instance<DiscoveryRepo>().setFollowing;

  final ToggleInteraction _postInteraction;
  final SetFollowing _setFollowing;

  final Map<String, EngagementState> _entries = {};

  /// Follow state by creator id, and the ids the viewer has changed here.
  final Map<String, bool> _following = {};
  final Set<String> _followOwned = {};

  /// Guards a target against a second request while one is in flight, so a
  /// double tap cannot post two toggles that cancel out.
  final Set<String> _inFlight = {};

  static String keyFor(String targetType, String targetId) =>
      '$targetType:$targetId';

  /// What is known about this target, or null if nothing is.
  EngagementState? stateFor(String targetType, String targetId) =>
      _entries[keyFor(targetType, targetId)];

  /// What is known, falling back to the counts the caller already has.
  EngagementState resolve(
    String? targetType,
    String targetId,
    EngagementState fallback,
  ) {
    if (targetType == null) return fallback;
    return _entries[keyFor(targetType, targetId)] ?? fallback;
  }

  /// Whether the store has been told anything about this creator at all.
  bool knowsFollowing(String creatorId) => _following.containsKey(creatorId);

  bool isFollowing(String creatorId, {bool fallback = false}) =>
      _following[creatorId] ?? fallback;

  /// Records what a payload says, without discarding what the viewer just did.
  void seed({
    required String? targetType,
    required String targetId,
    int? likes,
    int? saves,
    int? comments,
    bool? liked,
    bool? saved,
  }) {
    if (targetType == null || targetId.isEmpty) return;
    if (_merge(
      keyFor(targetType, targetId),
      likes: likes,
      saves: saves,
      comments: comments,
      liked: liked,
      saved: saved,
    )) {
      notifyListeners();
    }
  }

  /// Applies the viewer's own like/save state for a page of rows, as returned
  /// by the interactions batch route: interaction types keyed by target id.
  void seedInteractions(String targetType, Map<String, Set<String>> byId) {
    var changed = false;
    for (final entry in byId.entries) {
      changed =
          _merge(
            keyFor(targetType, entry.key),
            liked: entry.value.contains(InteractionTypes.like),
            saved: entry.value.contains(InteractionTypes.favorite),
          ) ||
          changed;
    }
    if (changed) notifyListeners();
  }

  /// Record a follow this viewer has just changed on another surface.
  void adoptFollowing(String creatorId, bool following) {
    if (creatorId.isEmpty) return;
    _followOwned.add(creatorId);
    if (_following[creatorId] == following) return;
    _following[creatorId] = following;
    notifyListeners();
  }

  // ---- Hiding -----------------------------------------------------------
  // Three states the card sheet writes and every surface reads.

  final _notInterested = <String>{};
  final _muted = <String>{};
  final _blocked = <String>{};

  /// Rows this viewer has reported in this session. Local only: reporting
  /// posts no suppression, and the backend keeps serving the row until a
  /// moderator acts on it. Nobody wants to keep scrolling past the thing
  /// they just objected to, so it leaves the lists at once.
  final _reported = <String>{};

  final _hidden = _HiddenNotifier();

  /// Fires when a row or a creator is hidden or brought back, and at no
  /// other time.
  ///
  /// A feed list watches **this**, not the store itself. The store wakes
  /// its listeners on every like, save and comment count — a dozen times
  /// a scroll — and a list that rebuilt on all of those would discard and
  /// rebuild every card in it to answer a question whose answer had not
  /// changed. What a list needs to know is only ever "has the set of rows
  /// I may draw moved", and that is this.
  Listenable get hiddenChanges => _hidden;

  /// Whether this viewer has hidden a row. Read from
  /// `GET /v1/engagement/interactions/{type}/{id}`, whose `types` include
  /// `not_interested` — it is one viewer's own flag, never a tally.
  bool isNotInterested(String targetId) => _notInterested.contains(targetId);

  bool isMuted(String creatorId) => _muted.contains(creatorId);

  bool isBlocked(String creatorId) => _blocked.contains(creatorId);

  void setNotInterested(String targetId, bool hidden) =>
      _flag(_notInterested, targetId, hidden);

  bool isReported(String targetId) => _reported.contains(targetId);

  /// A report went through. Separate from [setNotInterested] on purpose:
  /// the two look the same on screen but only one of them is a stored
  /// preference, and the card sheet must not offer "Undo not interested"
  /// for something the reader reported and never hid.
  void setReported(String targetId) => _flag(_reported, targetId, true);

  /// Whether a row belongs out of a list the viewer is looking at **now**,
  /// without waiting for the next fetch.
  ///
  /// This is the client half of a two-sided arrangement. The backend stops
  /// returning a blocked creator's work and a suppressed row on the next
  /// page, which is the durable half; this is the page already on screen
  /// when the reader acted. Neither alone is enough — without this the row
  /// they just blocked sits there until a refresh, and without the backend
  /// it comes back on the next scroll.
  bool hidesRow({String? creatorId, String? targetId}) {
    if (targetId != null && targetId.isNotEmpty) {
      if (_notInterested.contains(targetId)) return true;
      if (_reported.contains(targetId)) return true;
    }
    if (creatorId != null && creatorId.isNotEmpty) {
      if (_blocked.contains(creatorId)) return true;
      if (_muted.contains(creatorId)) return true;
    }
    return false;
  }

  void setMuted(String creatorId, bool muted) =>
      _flag(_muted, creatorId, muted);

  /// Blocking also drops the follow, which the caller adopts separately from
  /// the route's own `unfollowed` — it is not assumed here.
  void setBlocked(String creatorId, bool blocked) =>
      _flag(_blocked, creatorId, blocked);

  /// Seed from `following-creators`, which carries `isMuted` now.
  void seedMuted(Iterable<String> creatorIds) => _seed(_muted, creatorIds);

  /// Seed from the blocked list, so every surface agrees after one read.
  void seedBlocked(Iterable<String> creatorIds) => _seed(_blocked, creatorIds);

  /// Add every id, then notify once.
  void _seed(Set<String> into, Iterable<String> ids) {
    var added = false;
    for (final id in ids) {
      if (id.isEmpty) continue;
      if (into.add(id)) added = true;
    }
    if (added) _announceHidden();
  }

  void _flag(Set<String> into, String id, bool on) {
    if (id.isEmpty) return;
    final changed = on ? into.add(id) : into.remove(id);
    if (changed) _announceHidden();
  }

  /// Both audiences: anything watching the store as a whole, and the
  /// lists watching only for rows coming and going.
  void _announceHidden() {
    notifyListeners();
    _hidden.notify();
  }

  @override
  void dispose() {
    _hidden.dispose();
    super.dispose();
  }

  void seedFollowing(String creatorId, bool following) {
    if (creatorId.isEmpty || _followOwned.contains(creatorId)) return;
    if (_following[creatorId] == following) return;
    _following[creatorId] = following;
    notifyListeners();
  }

  /// Returns whether anything actually moved, so a seed that says what is
  /// already held does not wake every listening card.
  bool _merge(
    String key, {
    int? likes,
    int? saves,
    int? comments,
    bool? liked,
    bool? saved,
  }) {
    final cur = _entries[key] ?? const EngagementState();
    final next = EngagementState(
      liked: cur.ownsLike ? cur.liked : (liked ?? cur.liked),
      likes: cur.ownsLike ? cur.likes : (likes ?? cur.likes),
      saved: cur.ownsSave ? cur.saved : (saved ?? cur.saved),
      saves: cur.ownsSave ? cur.saves : (saves ?? cur.saves),
      comments: cur.ownsComments ? cur.comments : (comments ?? cur.comments),
      ownsLike: cur.ownsLike,
      ownsSave: cur.ownsSave,
      ownsComments: cur.ownsComments,
    );
    if (_entries.containsKey(key) &&
        next.liked == cur.liked &&
        next.saved == cur.saved &&
        next.likes == cur.likes &&
        next.saves == cur.saves &&
        next.comments == cur.comments) {
      return false;
    }
    _entries[key] = next;
    return true;
  }

  Future<void> toggleLike({
    required String targetType,
    required String targetId,
    EngagementState? fallback,
  }) => _toggle(
    targetType: targetType,
    targetId: targetId,
    interactionType: InteractionTypes.like,
    fallback: fallback,
  );

  Future<void> toggleSave({
    required String targetType,
    required String targetId,
    EngagementState? fallback,
  }) => _toggle(
    targetType: targetType,
    targetId: targetId,
    interactionType: InteractionTypes.favorite,
    fallback: fallback,
  );

  /// Flips the interaction locally, then tells the server.
  Future<void> _toggle({
    required String targetType,
    required String targetId,
    required String interactionType,
    EngagementState? fallback,
  }) async {
    if (targetId.isEmpty) return;
    final key = keyFor(targetType, targetId);
    final guard = '$key/$interactionType';
    if (!_inFlight.add(guard)) return;

    final isLike = interactionType == InteractionTypes.like;
    final before = _entries[key] ?? fallback ?? const EngagementState();
    final on = isLike ? !before.liked : !before.saved;

    EngagementState applied(bool value) =>
        isLike ? before.withLike(value) : before.withSave(value);

    _entries[key] = applied(on);
    notifyListeners();

    try {
      final active = await _postInteraction(
        targetType: targetType,
        targetId: targetId,
        interactionType: interactionType,
      );
      // The server is the authority on which way it landed.
      if (active != on) {
        _entries[key] = applied(active);
        notifyListeners();
      }
    } catch (e) {
      logger.w('toggle $interactionType on $key failed', error: e);
      _entries[key] = before;
      notifyListeners();
    } finally {
      _inFlight.remove(guard);
    }
  }

  /// A comment was posted or removed on this target.
  void bumpComments({
    required String? targetType,
    required String targetId,
    int by = 1,
    int? fallbackCount,
  }) {
    if (targetType == null || targetId.isEmpty) return;
    final key = keyFor(targetType, targetId);
    final cur = _entries[key] ?? EngagementState(comments: fallbackCount ?? 0);
    _entries[key] = cur.withComments(by);
    notifyListeners();
  }

  Future<void> toggleFollow(String creatorId, {bool fallback = false}) async {
    if (creatorId.isEmpty) return;
    final guard = 'follow:$creatorId';
    if (!_inFlight.add(guard)) return;

    final was = _following[creatorId] ?? fallback;
    _following[creatorId] = !was;
    _followOwned.add(creatorId);
    notifyListeners();

    try {
      await _setFollowing(creatorId, follow: !was);
    } catch (e) {
      logger.w('follow $creatorId failed', error: e);
      _following[creatorId] = was;
      notifyListeners();
    } finally {
      _inFlight.remove(guard);
    }
  }
}

/// [EngagementStore.hiddenChanges]. A notifier of its own rather than a
/// flag on the store, so a list can subscribe to the one event it cares
/// about.
class _HiddenNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
