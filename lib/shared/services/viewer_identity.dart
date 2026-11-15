import 'package:test_app/utils/helpers/local_storage.dart';

/// Whether a channel belongs to the reader looking at it.
abstract final class ViewerIdentity {
  /// The signed-in reader's own channel, if they have one.
  static String? get ownCreatorId {
    try {
      final id = LocalStorage.creatorId?.trim();
      return (id == null || id.isEmpty) ? null : id;
    } catch (_) {
      return null;
    }
  }

  /// Whether [creatorId] is this reader's own channel.
  static bool owns(String? creatorId, {bool flaggedByApi = false}) {
    if (flaggedByApi) return true;
    final mine = ownCreatorId;
    if (mine == null) return false;
    final id = creatorId?.trim();
    return id != null && id.isNotEmpty && id == mine;
  }
}
