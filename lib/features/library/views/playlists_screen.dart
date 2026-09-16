import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/data/playlist_dummy_data.dart';
import 'package:test_app/features/library/views/playlist_detail_screen.dart';
import 'package:test_app/features/library/views/playlist_form_screen.dart';
import 'package:test_app/models/library_models/playlist_models.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Every running order the reader has put together.
///
/// Nothing here is stored — see [PlaylistDummyData]. Creating, renaming and
/// deleting all happen in memory so the flows can be walked end to end.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final _controller = TextEditingController();
  late List<Playlist> _playlists = [...PlaylistDummyData.playlists];
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Playlist> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _playlists;
    return _playlists
        .where((p) => p.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> _create() async {
    final draft = await Navigator.push<PlaylistDraft>(
      context,
      MaterialPageRoute(builder: (_) => const PlaylistFormScreen()),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _playlists = [
        Playlist(
          id: 'new-${DateTime.now().microsecondsSinceEpoch}',
          name: draft.name,
          updatedAgo: AppStrings.justNow,
          covers: const [],
          items: const [],
          isPrivate: draft.isPrivate,
        ),
        ..._playlists,
      ];
    });
  }

  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// The same sheet the detail screen opens, so a playlist can be renamed or
  /// deleted without going into it first.
  void _openActions(Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LibraryActionSheet(
        actions: [
          LibraryAction(
            label: AppStrings.playlistPlayAll,
            icon: HugeIcons.strokeRoundedPlayCircle,
            enabled: !playlist.isEmpty,
          ),
          const LibraryAction(
            label: AppStrings.playlistUpdateCover,
            icon: HugeIcons.strokeRoundedImage02,
          ),
          const LibraryAction(
            label: AppStrings.playlistEditDetail,
            icon: HugeIcons.strokeRoundedEdit02,
          ),
          const LibraryAction(
            label: AppStrings.playlistDelete,
            icon: HugeIcons.strokeRoundedDelete02,
            destructive: true,
          ),
        ],
        onSelected: (label) {
          Navigator.pop(sheetContext);
          switch (label) {
            case AppStrings.playlistEditDetail:
              _rename(playlist);
            case AppStrings.playlistDelete:
              _confirmDelete(playlist);
            default:
              _report('$label is not built yet');
          }
        },
      ),
    );
  }

  Future<void> _rename(Playlist playlist) async {
    final draft = await Navigator.push<PlaylistDraft>(
      context,
      MaterialPageRoute(builder: (_) => PlaylistFormScreen(existing: playlist)),
    );
    if (draft == null || !mounted) return;
    setState(() {
      final i = _playlists.indexWhere((p) => p.id == playlist.id);
      if (i < 0) return;
      _playlists = [..._playlists]
        ..[i] = playlist.copyWith(name: draft.name, isPrivate: draft.isPrivate);
    });
  }

  void _confirmDelete(Playlist playlist) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PlaylistDeleteDialog(
        playlist: playlist,
        onConfirm: () {
          Navigator.pop(dialogContext);
          // Local only: there is no route to delete a playlist.
          setState(() {
            _playlists = _playlists
                .where((p) => p.id != playlist.id)
                .toList(growable: false);
          });
        },
      ),
    );
  }

  Future<void> _open(Playlist playlist) async {
    final outcome = await Navigator.push<PlaylistOutcome>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
    if (outcome == null || !mounted) return;

    setState(() {
      final i = _playlists.indexWhere((p) => p.id == playlist.id);
      if (i < 0) return;
      if (outcome.deleted) {
        _playlists = [..._playlists]..removeAt(i);
      } else if (outcome.playlist case final updated?) {
        _playlists = [..._playlists]..[i] = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final searching = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryHeader(
            title: AppStrings.playlistsTitle,
            actionLabel: AppStrings.playlistsNew,
            actionIcon: HugeIcons.strokeRoundedAddCircle,
            actionTint: AppColors.brandPrimary,
            onAction: _create,
            // The design drops the field once there is nothing to search.
            controller: _playlists.isEmpty ? null : _controller,
            onQueryChanged: _playlists.isEmpty
                ? null
                : (v) => setState(() => _query = v),
            searchHint: AppStrings.playlistsSearchHint,
          ),
          Expanded(
            child: matches.isEmpty
                ? SingleChildScrollView(
                    child: LibraryEmptyState(
                      icon: HugeIcons.strokeRoundedMusicNote01,
                      title: searching
                          ? AppStrings.libraryNoMatchTitle
                          : AppStrings.playlistsEmptyTitle,
                      body: searching
                          ? AppStrings.libraryNoMatchBody
                          : AppStrings.playlistsEmptyBody,
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 40.s),
                    itemCount: matches.length,
                    itemBuilder: (context, i) => PlaylistRow(
                      playlist: matches[i],
                      onTap: () => _open(matches[i]),
                      onMore: () => _openActions(matches[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One playlist in the list: a mosaic of its stills, its name, and how much is
/// in it.
class PlaylistRow extends StatelessWidget {
  const PlaylistRow({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onMore,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.s),
        child: Row(
          children: [
            PlaylistMosaic(
              covers: playlist.covers,
              width: 104.s,
              height: 58.s,
              overlay: true,
              countLabel: playlist.isEmpty
                  ? null
                  : '${playlist.itemCount} '
                        '${AppStrings.playlistsVideosSuffix}',
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(14, weight: AppStyles.bold),
                  ),
                  SizedBox(height: 4.s),
                  Text(
                    '${playlist.itemCount} ${AppStrings.playlistsItemsSuffix} '
                    '· ${AppStrings.playlistsUpdatedPrefix} '
                    '${playlist.updatedAgo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(
                      12,
                      color: AppColors.neutral500,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.s),
            GestureDetector(
              key: ValueKey('row-more-${playlist.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onMore,
              child: SizedBox(
                width: 24.s,
                height: 24.s,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreVertical,
                  color: AppColors.neutral400,
                  size: 20.s,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A playlist's covers tiled into one block.
///
/// Four stills make a 2×2; fewer fill what they can; none leaves the plain
/// panel an empty playlist gets.
class PlaylistMosaic extends StatelessWidget {
  const PlaylistMosaic({
    super.key,
    required this.covers,
    required this.width,
    required this.height,
    this.overlay = false,
    this.countLabel,
    this.radius,
  });

  final List<String> covers;
  final double width;
  final double height;

  /// Dims the tiles and puts a play disc in the middle — the list rows do
  /// this, the detail hero does not.
  final bool overlay;

  /// "5 Videos", bottom-left.
  final String? countLabel;

  final double? radius;

  @override
  Widget build(BuildContext context) {
    final tiles = covers.take(4).toList(growable: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? 8.s),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tiles.isEmpty)
              const ColoredBox(color: AppColors.base2)
            else
              Column(
                children: [
                  for (final row in [
                    tiles.take(2).toList(growable: false),
                    tiles.skip(2).toList(growable: false),
                  ])
                    if (row.isNotEmpty)
                      Expanded(
                        child: Row(
                          children: [
                            for (final cover in row)
                              Expanded(
                                child: Image.asset(cover, fit: BoxFit.cover),
                              ),
                          ],
                        ),
                      ),
                ],
              ),
            if (overlay) ...[
              const ColoredBox(color: Color(0x66000000)),
              Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPlayCircle,
                  color: AppColors.textPrimary,
                  size: 24.s,
                ),
              ),
            ],
            if (countLabel case final label?)
              Positioned(
                left: 6.s,
                bottom: 5.s,
                child: Text(
                  label,
                  style: AppStyles.label(
                    10,
                    weight: AppStyles.bold,
                    color: AppColors.neutral100,
                    lineHeight: 14 / 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
