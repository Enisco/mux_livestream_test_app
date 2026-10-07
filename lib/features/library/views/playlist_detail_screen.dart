import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/discovery/views/content_detail_screen.dart';
import 'package:test_app/features/library/repo/playlist_repo.dart';
import 'package:test_app/features/library/views/playlist_add_screen.dart';
import 'package:test_app/features/library/views/playlist_form_screen.dart';
import 'package:test_app/features/library/views/library_list_screen.dart'
    show glyphFor, metaFor;
import 'package:test_app/features/library/views/playlists_screen.dart'
    show PlaylistMosaic;
import 'package:test_app/models/analytics_models/analytics_models.dart';
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
  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    this.repo,
    this.discovery,
  });

  /// What the list already knows: a title and a count, but no items. The
  /// full read happens here.
  final Playlist playlist;

  final PlaylistRepo? repo;
  final DiscoveryRepo? discovery;

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late final _repo = widget.repo ?? PlaylistRepo();
  late Playlist _playlist = widget.playlist;
  bool _changed = false;
  bool _loading = true;
  List<HistoryEntry> _recommended = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// The list read carries no items, so the first thing this screen does is
  /// fetch them. Failing leaves the title and the count that got us here
  /// rather than an error page over a playlist that plainly exists.
  Future<void> _load() async {
    try {
      final full = await _repo.fetch(widget.playlist.id);
      if (!mounted) return;
      setState(() {
        _playlist = full;
        _loading = false;
      });
      unawaited(_loadRecommended());
    } catch (e) {
      logger.w('Playlist failed', error: e);
      if (mounted) setState(() => _loading = false);
    }
  }

  /// "Recommended for you", anchored on the first item.
  ///
  /// An empty playlist has nothing to anchor on, so it gets no rail — a
  /// generic suggestion list under an empty playlist is just the feed again.
  Future<void> _loadRecommended() async {
    final first = _playlist.items.firstOrNull;
    if (first == null) return;
    try {
      final page = await (widget.discovery ?? getIt<DiscoveryRepo>())
          .fetchContentSuggestions(
            targetType: 'media',
            targetId: first.id,
            limit: 4,
          );
      if (!mounted) return;
      setState(() {
        _recommended = [
          for (final item in page.items)
            if (!_playlist.items.any((e) => e.id == item.entityId))
              HistoryEntry(
                id: item.entityId,
                kind: item.mediaType == 'music'
                    ? HistoryKind.audio
                    : HistoryKind.video,
                title: item.title,
                creatorName: item.creator?.displayName ?? '',
                creatorVerified: item.creator?.isVerified ?? false,
                age: '',
                thumbnailUrl: item.meta.thumbnailUrl,
                targetType: 'media',
              ),
        ];
      });
    } catch (e) {
      logger.w('Playlist suggestions failed', error: e);
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
    try {
      await _repo.update(_playlist.id, title: draft.name);
      if (!mounted) return;
      setState(() {
        _playlist = _playlist.copyWith(name: draft.name);
        _changed = true;
      });
    } catch (e) {
      logger.w('Playlist rename failed', error: e);
      if (mounted) _report(AppStrings.playlistSaveFailed);
    }
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => PlaylistDeleteDialog(
        playlist: _playlist,
        onConfirm: () async {
          Navigator.pop(dialogContext);
          try {
            await _repo.delete(_playlist.id);
            if (mounted) _leave(deleted: true);
          } catch (e) {
            logger.w('Playlist delete failed', error: e);
            if (mounted) _report(AppStrings.playlistSaveFailed);
          }
        },
      ),
    );
  }

  Future<void> _addContent() async {
    final picked = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistAddScreen(
          playlistName: _playlist.name,
          anchorMediaId: _playlist.items.firstOrNull?.id,
          alreadyIn: {for (final e in _playlist.items) e.id},
        ),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    await _add(picked);
  }

  /// Add media, one call each.
  ///
  /// A duplicate answers 409 rather than quietly doing nothing, and the
  /// ceiling is [PlaylistRepo.maxItems] — so a failure is reported instead of
  /// being folded into a silent partial add.
  Future<void> _add(Set<String> mediaIds) async {
    var added = 0;
    for (final id in mediaIds) {
      try {
        await _repo.addItem(_playlist.id, id);
        added++;
      } catch (e) {
        logger.w('Playlist add failed', error: e);
      }
    }
    if (!mounted) return;
    _changed = true;
    if (added < mediaIds.length) _report(AppStrings.playlistAddFailed);
    await _load();
  }

  Future<void> _remove(HistoryEntry item) async {
    final before = _playlist;
    setState(() {
      _playlist = _playlist.copyWith(
        items: _playlist.items.where((e) => e.id != item.id).toList(),
        declaredCount: (_playlist.itemCount - 1).clamp(0, 1 << 30),
      );
      _changed = true;
    });
    try {
      await _repo.removeItem(before.id, item.id);
    } catch (e) {
      logger.w('Playlist remove failed', error: e);
      if (!mounted) return;
      setState(() => _playlist = before);
      _report(AppStrings.playlistSaveFailed);
    }
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
              // There is no queue to hand a whole playlist to, so Play opens
              // the first item — which is what playing one starts with. It
              // stands down on a playlist whose items have not arrived.
              onPlay: playlist.items.isEmpty
                  ? null
                  : () => _open(playlist.items.first),
              onMore: _openActions,
              onEditCover: () => _report(
                '${AppStrings.playlistEditCover} '
                'is not built yet',
              ),
            ),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40.s),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                ),
              )
            else if (playlist.isEmpty)
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
            if (_recommended.isNotEmpty)
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
            for (final item in _recommended.take(2))
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

  /// Open what the row is a picture of.
  ///
  /// The library is not one of the surfaces the beacon's `source` enum knows,
  /// so these clicks are reported as `unknown` rather than invented.
  void _open(HistoryEntry item) {
    if (!openFeedItem(context, item.source, source: AnalyticsSource.unknown)) {
      _report(AppStrings.libraryRowGone);
    }
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
      thumbnailUrl: item.thumbnailUrl,
      glyph: glyphFor(item.kind),
      badge: item.duration,
      progress: item.progress,
      meta: metaFor(item),
      onTap: () => _open(item),
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
