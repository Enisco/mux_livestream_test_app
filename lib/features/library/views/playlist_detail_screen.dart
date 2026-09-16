import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/data/playlist_dummy_data.dart';
import 'package:test_app/features/library/views/playlist_add_screen.dart';
import 'package:test_app/features/library/views/playlist_form_screen.dart';
import 'package:test_app/features/library/views/library_list_screen.dart'
    show glyphFor, metaFor;
import 'package:test_app/features/library/views/playlists_screen.dart'
    show PlaylistMosaic;
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/models/library_models/playlist_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What the detail screen hands back to the list it was opened from.
class PlaylistOutcome {
  const PlaylistOutcome({this.playlist, this.deleted = false});

  /// The playlist as it now stands. Null when it was deleted.
  final Playlist? playlist;

  final bool deleted;
}

/// One playlist: its cover, what is in it, and what to play next.
///
/// Empty and filled are the same screen in the design — an empty one simply
/// greys the play button, says so in the middle, and leans on the
/// recommendations underneath.
class PlaylistDetailScreen extends StatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist = widget.playlist;
  bool _changed = false;

  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Hands the list whatever came of this visit, then leaves.
  void _leave({bool deleted = false}) {
    Navigator.pop(
      context,
      deleted
          ? const PlaylistOutcome(deleted: true)
          : _changed
          ? PlaylistOutcome(playlist: _playlist)
          : null,
    );
  }

  void _openActions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LibraryActionSheet(
        actions: [
          LibraryAction(
            label: AppStrings.playlistPlayAll,
            icon: HugeIcons.strokeRoundedPlayCircle,
            enabled: !_playlist.isEmpty,
          ),
          LibraryAction(
            label: AppStrings.playlistUpdateCover,
            icon: HugeIcons.strokeRoundedImage02,
          ),
          LibraryAction(
            label: AppStrings.playlistEditDetail,
            icon: HugeIcons.strokeRoundedEdit02,
          ),
          LibraryAction(
            label: AppStrings.playlistDelete,
            icon: HugeIcons.strokeRoundedDelete02,
            destructive: true,
          ),
        ],
        onSelected: (label) {
          Navigator.pop(sheetContext);
          switch (label) {
            case AppStrings.playlistEditDetail:
              _edit();
            case AppStrings.playlistDelete:
              _confirmDelete();
            default:
              _report('$label is not built yet');
          }
        },
      ),
    );
  }

  Future<void> _edit() async {
    final draft = await Navigator.push<PlaylistDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistFormScreen(existing: _playlist),
      ),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _playlist = _playlist.copyWith(
        name: draft.name,
        isPrivate: draft.isPrivate,
      );
      _changed = true;
    });
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PlaylistDeleteDialog(
        playlist: _playlist,
        onConfirm: () {
          Navigator.pop(dialogContext);
          // Local only: there is no route to delete a playlist.
          _leave(deleted: true);
        },
      ),
    );
  }

  Future<void> _addContent() async {
    final picked = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistAddScreen(playlistName: _playlist.name),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    final added = PlaylistDummyData.recommended
        .where((e) => picked.contains(e.id))
        .toList(growable: false);
    setState(() {
      _playlist = Playlist(
        id: _playlist.id,
        name: _playlist.name,
        updatedAgo: AppStrings.justNow,
        covers: [..._playlist.covers, for (final e in added) ?e.thumbnailAsset],
        items: [..._playlist.items, ...added],
        isPrivate: _playlist.isPrivate,
        runtime: _playlist.runtime,
        ownerName: _playlist.ownerName,
        ownerVerified: _playlist.ownerVerified,
      );
      _changed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.base1,
        body: ListView(
          padding: EdgeInsets.only(bottom: 40.s),
          children: [
            _Hero(
              playlist: playlist,
              onBack: _leave,
              onPlay: playlist.isEmpty
                  ? null
                  : () => _report('Playing a playlist is not built yet'),
              onMore: _openActions,
              onEditCover: () => _report(
                '${AppStrings.playlistEditCover} '
                'is not built yet',
              ),
            ),
            if (playlist.isEmpty)
              LibraryEmptyState(
                icon: HugeIcons.strokeRoundedMusicNote01,
                title: AppStrings.playlistEmptyTitle,
                body: AppStrings.playlistEmptyBody,
              )
            else
              for (final item in playlist.items)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.s),
                  child: _itemRow(item, onMore: () => _openItemActions(item)),
                ),
            SizedBox(height: playlist.isEmpty ? 8.s : 18.s),
            Padding(
              padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 10.s),
              child: Text(
                AppStrings.playlistRecommended,
                style: AppStyles.label(
                  14,
                  weight: AppStyles.bold,
                  lineHeight: 20 / 14,
                ),
              ),
            ),
            for (final item in PlaylistDummyData.recommended.take(2))
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.s),
                child: _itemRow(
                  item,
                  onMore: () => _openRecommendedActions(item),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What a row already in the playlist offers. Taking one out is
  /// destructive, so it goes behind the sheet rather than on a bare tap of
  /// the overflow button.
  void _openItemActions(HistoryEntry item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LibraryActionSheet(
        actions: const [
          LibraryAction(
            label: AppStrings.playlistItemPlay,
            icon: HugeIcons.strokeRoundedPlayCircle,
          ),
          LibraryAction(
            label: AppStrings.playlistItemRemove,
            icon: HugeIcons.strokeRoundedDelete02,
            destructive: true,
          ),
        ],
        onSelected: (label) {
          Navigator.pop(sheetContext);
          if (label == AppStrings.playlistItemRemove) {
            _remove(item);
          } else {
            _report('$label is not built yet');
          }
        },
      ),
    );
  }

  /// What a row on the recommended rail offers.
  void _openRecommendedActions(HistoryEntry item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LibraryActionSheet(
        actions: const [
          LibraryAction(
            label: AppStrings.playlistItemPlay,
            icon: HugeIcons.strokeRoundedPlayCircle,
          ),
          LibraryAction(
            label: AppStrings.playlistItemAdd,
            icon: HugeIcons.strokeRoundedAddCircle,
          ),
        ],
        onSelected: (label) {
          Navigator.pop(sheetContext);
          if (label == AppStrings.playlistItemAdd) {
            _addContent();
          } else {
            _report('$label is not built yet');
          }
        },
      ),
    );
  }

  /// Takes one item out. Local only — nothing stores a playlist yet.
  void _remove(HistoryEntry item) {
    setState(() {
      _playlist = Playlist(
        id: _playlist.id,
        name: _playlist.name,
        updatedAgo: AppStrings.justNow,
        covers: _playlist.covers,
        items: _playlist.items.where((e) => e.id != item.id).toList(),
        isPrivate: _playlist.isPrivate,
        runtime: _playlist.runtime,
        ownerName: _playlist.ownerName,
        ownerVerified: _playlist.ownerVerified,
      );
      _changed = true;
    });
  }

  Widget _itemRow(HistoryEntry item, {required VoidCallback onMore}) {
    return ContentListRow(
      key: ValueKey('item-${item.id}'),
      moreKey: ValueKey('more-${item.id}'),
      compact: true,
      title: item.title,
      creatorName: item.creatorName,
      creatorVerified: item.creatorVerified,
      thumbnailAsset: item.thumbnailAsset,
      glyph: glyphFor(item.kind),
      badge: item.duration,
      progress: item.progress,
      meta: metaFor(item),
      onTap: () => _report(item.title),
      onMore: onMore,
    );
  }
}

/// The cover, the title and the two controls over it.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.playlist,
    required this.onBack,
    required this.onPlay,
    required this.onMore,
    required this.onEditCover,
  });

  final Playlist playlist;
  final VoidCallback onBack;

  /// Null when there is nothing to play, which greys the button.
  final VoidCallback? onPlay;

  final VoidCallback onMore;
  final VoidCallback onEditCover;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 250.s + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlaylistMosaic(
            covers: playlist.covers,
            width: double.infinity,
            height: 250.s + top,
            radius: 0,
          ),
          // Keeps the title and controls legible over any cover.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x00000000),
                  Color(0xD9000000),
                ],
                stops: [0, 0.35, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.s, top + 10.s, 20.s, 16.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GTubeBackButton(onTap: onBack, size: 24, box: 24),
                    _CoverButton(onTap: onEditCover),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    _OwnerChip(
                      name: playlist.ownerName,
                      verified: playlist.ownerVerified,
                    ),
                  ],
                ),
                SizedBox(height: 6.s),
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.heading(24, lineHeight: 30 / 24),
                ),
                SizedBox(height: 12.s),
                Row(
                  children: [
                    _PlayButton(onTap: onPlay),
                    SizedBox(width: 10.s),
                    _MoreButton(
                      key: const ValueKey('playlist-more'),
                      onTap: onMore,
                    ),
                    const Spacer(),
                    Text(
                      playlist.isEmpty
                          ? '0 ${AppStrings.playlistsItemsSuffix}'
                          : '${playlist.itemCount} '
                                '${AppStrings.playlistItemsLabel}'
                                '${playlist.runtime.isEmpty ? '' : ' · '
                                          '${playlist.runtime}'}',
                      style: AppStyles.label(
                        12,
                        weight: AppStyles.bold,
                        color: AppColors.neutral200,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 6.s),
        decoration: BoxDecoration(
          color: AppColors.base1.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999.s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCamera01,
              color: AppColors.textPrimary,
              size: 13.s,
            ),
            SizedBox(width: 6.s),
            Text(
              AppStrings.playlistEditCover,
              style: AppStyles.label(
                11,
                weight: AppStyles.bold,
                lineHeight: 14 / 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerChip extends StatelessWidget {
  const _OwnerChip({required this.name, required this.verified});

  final String name;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16.s,
          height: 16.s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.buttonSecondaryActive,
            border: Border.all(color: AppColors.purple400, width: 1),
          ),
          child: Icon(Icons.person, size: 10.s, color: AppColors.neutral400),
        ),
        SizedBox(width: 6.s),
        Text(
          name,
          style: AppStyles.label(
            12,
            color: AppColors.neutral100,
            lineHeight: 16 / 12,
          ),
        ),
        if (verified) ...[
          SizedBox(width: 4.s),
          DesignIcon(AppAssets.iconFeedVerified, width: 13.s, height: 13.s),
        ],
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final live = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44.s,
        height: 44.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: live ? AppColors.brandPrimary : AppColors.neutral700,
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedPlay,
          color: live ? AppColors.base1 : AppColors.neutral500,
          size: 20.s,
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44.s,
        height: 44.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.base1.withValues(alpha: 0.7),
          border: Border.all(color: AppColors.neutral700),
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedMoreVertical,
          color: AppColors.textPrimary,
          size: 20.s,
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.label, required this.onTap, this.tint});

  final String label;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colour = tint ?? AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.s),
          border: Border.all(color: tint ?? AppColors.neutral700),
        ),
        child: Text(label, style: AppStyles.button(13, color: colour)),
      ),
    );
  }
}

/// "Delete this playlist" — asked the same way wherever it is reached from.
class PlaylistDeleteDialog extends StatelessWidget {
  const PlaylistDeleteDialog({
    super.key,
    required this.playlist,
    required this.onConfirm,
  });

  final Playlist playlist;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.base2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
      titlePadding: EdgeInsets.fromLTRB(20.s, 20.s, 20.s, 0),
      contentPadding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 0),
      actionsPadding: EdgeInsets.all(20.s),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.s,
            height: 36.s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.destructive.withValues(alpha: 0.15),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedDelete02,
              color: AppColors.destructive,
              size: 18.s,
            ),
          ),
          SizedBox(height: 14.s),
          Text(AppStrings.playlistDeleteTitle, style: AppStyles.heading(16)),
        ],
      ),
      content: Text(
        AppStrings.playlistDeleteBody(playlist.name, playlist.itemCount),
        style: AppStyles.body(
          13,
          color: AppColors.neutral400,
          lineHeight: 18 / 13,
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: _DialogButton(
                label: AppStrings.cancel,
                onTap: () => Navigator.pop(context),
              ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: _DialogButton(
                label: AppStrings.playlistDeleteConfirm,
                tint: AppColors.destructive,
                onTap: onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
