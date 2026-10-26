import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/library/repo/playlist_repo.dart';
import 'package:test_app/features/library/views/playlist_detail_screen.dart';
import 'package:test_app/features/library/views/playlist_form_screen.dart';
import 'package:test_app/models/library_models/playlist_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Every running order the reader has put together.
///
/// **Every playlist here is private.** Staging refuses `visibility` on both
/// create and update, so the design's "Anyone with the link" group has
/// nothing to hold and no playlist can be shared — see `docs/OPEN_ISSUES.md`.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key, this.repo});

  /// Defaults to the real thing; a test supplies its own.
  final PlaylistRepo? repo;

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  late final _repo = widget.repo ?? PlaylistRepo();
  final _controller = TextEditingController();

  List<Playlist> _playlists = const [];
  String _query = '';
  Timer? _debounce;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Searching is the route's own `title.contains` filter, not a sift of
  /// what has been loaded — a reader with fifty playlists would otherwise
  /// only find the page they are looking at.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await _repo.search(query: _query);
      if (!mounted) return;
      setState(() {
        _playlists = rows;
        _loading = false;
      });
    } catch (e) {
      logger.w('Playlists failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) unawaited(_load());
    });
  }

  List<Playlist> get _matches => _playlists;

  Future<void> _create() async {
    final draft = await Navigator.push<PlaylistDraft>(
      context,
      MaterialPageRoute(builder: (_) => const PlaylistFormScreen()),
    );
    if (draft == null || !mounted) return;
    try {
      await _repo.create(title: draft.name, isPrivate: draft.isPrivate);
      await _load();
    } catch (e) {
      logger.w('Playlist create failed', error: e);
      if (mounted) _report(AppStrings.playlistSaveFailed);
    }
  }

  /// Take it out at once, and put it back if the write fails.
  Future<void> _delete(Playlist playlist) async {
    final before = _playlists;
    setState(() {
      _playlists = _playlists
          .where((p) => p.id != playlist.id)
          .toList(growable: false);
    });
    try {
      await _repo.delete(playlist.id);
    } catch (e) {
      logger.w('Playlist delete failed', error: e);
      if (!mounted) return;
      setState(() => _playlists = before);
      _report(AppStrings.playlistSaveFailed);
    }
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
            case AppStrings.playlistUpdateCover:
              // Covers are edited on the playlist itself, where the result
              // is visible — there is nothing to show for one here.
              unawaited(_open(playlist));
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
    try {
      await _repo.update(
        playlist.id,
        title: draft.name,
        isPrivate: draft.isPrivate,
      );
      if (!mounted) return;
      setState(() {
        final i = _playlists.indexWhere((p) => p.id == playlist.id);
        if (i < 0) return;
        _playlists = [..._playlists]
          ..[i] = playlist.copyWith(
            name: draft.name,
            isPrivate: draft.isPrivate,
          );
      });
    } catch (e) {
      logger.w('Playlist rename failed', error: e);
      if (mounted) _report(AppStrings.playlistSaveFailed);
    }
  }

  void _confirmDelete(Playlist playlist) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PlaylistDeleteDialog(
        playlist: playlist,
        onConfirm: () {
          Navigator.pop(dialogContext);
          unawaited(_delete(playlist));
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
            // The design drops the field once there is nothing to search —
            // but not while a search is what emptied the list.
            controller: _playlists.isEmpty && _query.isEmpty
                ? null
                : _controller,
            onQueryChanged: _playlists.isEmpty && _query.isEmpty
                ? null
                : _onQueryChanged,
            searchHint: AppStrings.playlistsSearchHint,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  )
                : _failed
                ? ErrorStateView(onRetry: _load)
                : matches.isEmpty
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

/// One tile of the mosaic.
///
/// The covers are **URLs** — `meta.thumbnailUrl`, or a CDN key resolved
/// through `AssetUrlResolver` — not bundled asset paths. This drew them with
/// `Image.asset`, left over from when playlists ran on dummy artwork, so
/// every real playlist with a cover threw "Unable to load asset" and showed
/// a red plate where the still should be. A bundled path is still accepted
/// for the placeholders that use one.
class _CoverTile extends StatelessWidget {
  const _CoverTile(this.cover);

  final String cover;

  static const _plate = ColoredBox(color: AppColors.base2);

  @override
  Widget build(BuildContext context) {
    if (cover.isEmpty) return _plate;
    if (!cover.startsWith('http')) {
      return Image.asset(
        cover,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _plate,
      );
    }
    return Image.network(
      cover,
      fit: BoxFit.cover,
      // A thumbnail the gateway cannot serve — a `mux_auto` still for a
      // stream with no generated frame — must not take the card with it.
      errorBuilder: (_, _, _) => _plate,
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
                              Expanded(child: _CoverTile(cover)),
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
