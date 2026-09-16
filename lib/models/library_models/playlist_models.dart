import 'package:test_app/models/history_models/history_models.dart';

/// A running order the reader put together.
///
/// The items are [HistoryEntry] because a playlist row and a history row are
/// the same thing in the design — a still, a title, a creator, a meta line —
/// and the whole library already speaks that shape. When the playlist routes
/// land, the payload maps onto it rather than onto a second content model.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.updatedAgo,
    required this.covers,
    required this.items,
    this.isPrivate = true,
    this.runtime = '',
    this.ownerName = '',
    this.ownerVerified = false,
  });

  final String id;
  final String name;

  /// "2h ago" — already formatted.
  final String updatedAgo;

  /// The stills behind the title, newest first. The list screen shows the
  /// first few as a mosaic; an empty playlist has none.
  final List<String> covers;

  final List<HistoryEntry> items;

  /// Private playlists are the default; public ones appear on the owner's
  /// channel.
  final bool isPrivate;

  /// "3h 24m" — the whole playlist end to end.
  final String runtime;

  /// Whose playlist it is. Shown over the cover on the detail screen.
  final String ownerName;
  final bool ownerVerified;

  int get itemCount => items.length;

  bool get isEmpty => items.isEmpty;

  Playlist copyWith({String? name, bool? isPrivate}) => Playlist(
    id: id,
    name: name ?? this.name,
    updatedAgo: updatedAgo,
    covers: covers,
    items: items,
    isPrivate: isPrivate ?? this.isPrivate,
    runtime: runtime,
    ownerName: ownerName,
    ownerVerified: ownerVerified,
  );
}
