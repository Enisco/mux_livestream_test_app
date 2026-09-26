import 'package:test_app/utils/helpers/local_storage.dart';

/// Whether a channel belongs to the reader looking at it.
///
/// A creator opening their own channel from the You tab was being offered
/// **Follow**, **Give Now** and **Subscribe/follow** — actions that only make
/// sense pointed at somebody else. You cannot follow yourself, and the API
/// refuses it; the buttons were dead ends dressed as invitations.
///
/// The question comes up on every surface that lists channels — the profile
/// header, feed channel cards, search rows, explore cards, the vertical
/// feed's avatar — so it is answered in one place rather than re-derived at
/// each of them.
///
/// Two sources, in order of trust:
///
///  * `isOwnedByViewer`, which the discovery API puts on feed rows and
///    recommended creators. Authoritative, and it covers a channel this
///    reader belongs to without owning.
///  * the cached creator id, for routes that carry no such flag —
///    `GET /v1/creator/handle/{handle}` is one, and it is exactly the route
///    behind the screen that was wrong.
abstract final class ViewerIdentity {
  /// The signed-in reader's own channel, if they have one.
  ///
  /// `LocalStorage` holds its prefs in a `late` field and throws when it has
  /// not been initialised. This is asked while mapping every feed row, in
  /// plenty of places that never init it — and whose channel a row belongs
  /// to is never worth taking a screen down for, so an unavailable answer is
  /// "not mine".
  static String? get ownCreatorId {
    try {
      final id = LocalStorage.creatorId?.trim();
      return (id == null || id.isEmpty) ? null : id;
    } catch (_) {
      return null;
    }
  }

  /// Whether [creatorId] is this reader's own channel.
  ///
  /// [flaggedByApi] is `isOwnedByViewer` where the payload carries it; it
  /// wins, because a team member belongs to a channel whose id is not the one
  /// cached here.
  static bool owns(String? creatorId, {bool flaggedByApi = false}) {
    if (flaggedByApi) return true;
    final mine = ownCreatorId;
    if (mine == null) return false;
    final id = creatorId?.trim();
    return id != null && id.isNotEmpty && id == mine;
  }
}
