import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';

/// What one surface knows about a viewer's relationship to one thing.
///
/// The `owns*` flags mark a field the viewer changed here. A feed payload
/// fetched afterwards can be older than that change — it was assembled before
/// the tap reached the server — so seeding must not undo it.
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
  ///
  /// Setting it to what it already is only claims ownership — re-applying a
  /// like the viewer already holds must not add a second one to the count.
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
///
/// Every surface used to keep its own copy. A like made on a detail screen left
/// the card it was opened from showing the old count, and the feed's own
/// buttons called an auth guard that returned true and did nothing else — so
/// for a signed-in viewer they were inert. Screens now read and write here, so
/// a change made anywhere is the change every surface shows, without a refetch.
///
/// Keyed by `targetType:targetId`, because ids are only unique within a type.
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
  ///
  /// Callers hold a payload of their own — a feed row, a detail aggregate — so
  /// an unvisited target reads from that rather than showing zeroes.
  EngagementState resolve(
    String? targetType,
    String targetId,
    EngagementState fallback,
  ) {
    if (targetType == null) return fallback;
    return _entries[keyFor(targetType, targetId)] ?? fallback;
  }

  bool isFollowing(String creatorId, {bool fallback = false}) =>
      _following[creatorId] ?? fallback;

  /// Records what a payload says, without discarding what the viewer just did.
  ///
  /// Called after a fetch. Fields the viewer has changed on this target keep
  /// their local value; everything else takes the server's.
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
  ///
  /// Optimistic because the count is decoration and the round trip is not
  /// instant; the local value is rolled back if the server refuses, and
  /// corrected if the server lands the other way from what was assumed.
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
