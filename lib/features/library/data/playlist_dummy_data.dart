import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/models/library_models/playlist_models.dart';

/// Placeholder playlists, their contents, and the rail of things to add.
///
/// TEMPORARY. The staging spec has no playlist routes at all — nothing
/// creates, lists, renames, reorders or deletes one, and nothing returns the
/// "Recommended for you" rail the design puts under every playlist. The whole
/// section is UI ahead of its API.
///
/// To retire this: delete the file and fix the import errors in
/// `playlists_screen.dart`, `playlist_detail_screen.dart` and
/// `playlist_add_screen.dart`.
abstract final class PlaylistDummyData {
  static const _art = 'assets/images/explore_dummy';

  static const _covers = <String>[
    '$_art/live_thumb.png',
    '$_art/trending_thumb.png',
    '$_art/continue_thumb.png',
    '$_art/poster_thumb.png',
  ];

  static const _items = <HistoryEntry>[
    HistoryEntry(
      id: 'pi1',
      kind: HistoryKind.audio,
      title: 'Romans, chapter by chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      age: '6d',
      count: 10,
      duration: '00:25',
      thumbnailAsset: '$_art/live_thumb.png',
    ),
    HistoryEntry(
      id: 'pi2',
      kind: HistoryKind.video,
      title: 'Sunday Worship',
      creatorName: 'Grace Community',
      creatorVerified: true,
      age: '6d ago',
      count: 12000,
      duration: '00:25',
      thumbnailAsset: '$_art/trending_thumb.png',
    ),
    HistoryEntry(
      id: 'pi3',
      kind: HistoryKind.video,
      title: 'Romans, chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      age: '6d',
      count: 12000,
      duration: '00:25',
      progress: 0.35,
      thumbnailAsset: '$_art/continue_thumb.png',
    ),
    HistoryEntry(
      id: 'pi4',
      kind: HistoryKind.audio,
      title: 'Romans, chapter by chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      age: '6d',
      count: 10,
      duration: '00:25',
      thumbnailAsset: '$_art/poster_thumb.png',
    ),
  ];

  /// The rail under every playlist, empty or not.
  static const recommended = <HistoryEntry>[
    HistoryEntry(
      id: 'pr1',
      kind: HistoryKind.audio,
      title: 'Romans, chapter by chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      age: '6d',
      count: 10,
      duration: '00:25',
      thumbnailAsset: '$_art/live_thumb.png',
    ),
    HistoryEntry(
      id: 'pr2',
      kind: HistoryKind.video,
      title: 'Sunday Worship',
      creatorName: 'Grace Community',
      creatorVerified: true,
      age: '6d ago',
      count: 12000,
      duration: '00:25',
      thumbnailAsset: '$_art/trending_thumb.png',
    ),
    HistoryEntry(
      id: 'pr3',
      kind: HistoryKind.video,
      title: 'Romans, chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      age: '6d',
      count: 12000,
      duration: '00:25',
      progress: 0.2,
      thumbnailAsset: '$_art/continue_thumb.png',
    ),
    HistoryEntry(
      id: 'pr4',
      kind: HistoryKind.audio,
      title: 'Romans, chapter by chapter',
      creatorName: 'Grace Community',
      creatorVerified: true,
      age: '6d',
      count: 10,
      duration: '00:25',
      thumbnailAsset: '$_art/poster_thumb.png',
    ),
  ];

  /// Which of [recommended] are already in the playlist being added to. The
  /// design shows both states on the same screen.
  static const alreadyAdded = <String>{'pr1', 'pr3'};

  static const playlists = <Playlist>[
    Playlist(
      id: 'pl1',
      name: 'Sunday Worship',
      updatedAgo: '2h ago',
      covers: _covers,
      items: _items,
      runtime: '3h 24m',
      ownerName: 'CCI International',
      ownerVerified: true,
    ),
    Playlist(
      id: 'pl2',
      name: 'For Mum',
      updatedAgo: '2h ago',
      covers: _covers,
      items: _items,
      runtime: '2h 10m',
      ownerName: 'CCI International',
      ownerVerified: true,
    ),
    Playlist(
      id: 'pl3',
      name: 'Worship for the road',
      updatedAgo: '2h ago',
      covers: _covers,
      items: _items,
      runtime: '1h 48m',
      ownerName: 'CCI International',
      ownerVerified: true,
    ),
    // The design gives the empty playlist its own screen, so one is kept here
    // to reach it without editing the file.
    Playlist(
      id: 'pl4',
      name: 'Encouragement Messages',
      updatedAgo: 'just now',
      covers: [],
      items: [],
      ownerName: 'CCI International',
      ownerVerified: true,
    ),
  ];
}
