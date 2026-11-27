import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/library/repo/playlist_repo.dart';
import 'package:test_app/features/library/views/playlist_form_screen.dart';
import 'package:test_app/models/library_models/playlist_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What came of choosing a playlist.
@immutable
class AddToPlaylistResult {
  const AddToPlaylistResult({
    required this.playlistName,
    this.alreadyIn = false,
  });

  final String playlistName;

  /// The playlist already held it. A `CONFLICT`, per the media guide — not
  /// a failure, and not something to report as one.
  final bool alreadyIn;

  String get message => alreadyIn
      ? AppStrings.playlistPickAlreadyIn(playlistName)
      : AppStrings.playlistPickAdded(playlistName);
}

/// Pick which playlist a piece of media goes into.
///
/// "Add to playlist" used to push `PlaylistsScreen`, the browse screen,
/// which has no idea what is being added — so tapping a playlist opened it
/// and nothing was ever added. This is the destination picker that was
/// missing: it lists the reader's playlists, adds on tap, and can make a
/// new one and drop the item straight into it.
///
/// Returns null when the reader backed out or nothing could be added.
/// Playlists hold **media only**; the caller is responsible for not
/// offering this for a post, an event or a devotional.
Future<AddToPlaylistResult?> showAddToPlaylistSheet(
  BuildContext context, {
  required String mediaId,
  PlaylistRepo? repo,
}) {
  return showModalBottomSheet<AddToPlaylistResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AddToPlaylistSheet(mediaId: mediaId, repo: repo),
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  const _AddToPlaylistSheet({required this.mediaId, this.repo});

  final String mediaId;
  final PlaylistRepo? repo;

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  late final PlaylistRepo _repo = widget.repo ?? PlaylistRepo();

  List<Playlist> _playlists = const [];
  bool _loading = true;
  bool _failed = false;

  /// The playlist being written to, so its row can show it and the rest
  /// stay inert — two taps would post two adds.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await _repo.search();
      if (!mounted) return;
      setState(() {
        // A row with no id is not a destination — `POST .../items` would
        // go to a malformed path — and an empty id is also what marks the
        // New playlist row busy, so one would light up the other.
        _playlists = rows.where((p) => p.id.isNotEmpty).toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      logger.w('Playlists for the add sheet failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Adds, then closes with what to tell the reader.
  Future<void> _add(Playlist playlist) async {
    if (_busyId != null) return;
    setState(() => _busyId = playlist.id);
    try {
      await _repo.addItem(playlist.id, widget.mediaId);
      if (mounted) {
        Navigator.pop(
          context,
          AddToPlaylistResult(playlistName: playlist.name),
        );
      }
    } on DioException catch (e) {
      // A duplicate answers CONFLICT and is not a failure — the reader
      // wanted it in that playlist and it is in that playlist.
      if (e.response?.statusCode == 409) {
        if (mounted) {
          Navigator.pop(
            context,
            AddToPlaylistResult(playlistName: playlist.name, alreadyIn: true),
          );
        }
        return;
      }
      logger.w('Playlist add failed', error: e);
      if (mounted) {
        setState(() => _busyId = null);
        _say(AppStrings.playlistAddFailed);
      }
    } catch (e) {
      logger.w('Playlist add failed', error: e);
      if (mounted) {
        setState(() => _busyId = null);
        _say(AppStrings.playlistAddFailed);
      }
    }
  }

  /// A new playlist, then the item straight into it — there is no reason
  /// to make one from here and then have to find it again.
  Future<void> _createThenAdd() async {
    if (_busyId != null) return;
    final draft = await Navigator.push<PlaylistDraft>(
      context,
      MaterialPageRoute(builder: (_) => const PlaylistFormScreen()),
    );
    if (draft == null || !mounted) return;
    setState(() => _busyId = _newPlaylistId);
    try {
      final made = await _repo.create(
        title: draft.name,
        isPrivate: draft.isPrivate,
      );
      try {
        await _repo.addItem(made.id, widget.mediaId);
      } catch (e) {
        // The playlist exists; only the add failed. Saying "that did not
        // save" would be a lie, and the reader would make it twice.
        logger.w('Playlist add after create failed', error: e);
        if (!mounted) return;
        setState(() => _busyId = null);
        _say(AppStrings.playlistAddFailed);
        await _load();
        return;
      }
      if (mounted) {
        Navigator.pop(context, AddToPlaylistResult(playlistName: made.name));
      }
    } catch (e) {
      logger.w('Playlist create failed', error: e);
      if (!mounted) return;
      setState(() => _busyId = null);
      _say(AppStrings.playlistSaveFailed);
    }
  }

  /// The busy marker for the New playlist row, which has no id of its own.
  static const _newPlaylistId = '';

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12.s),
      padding: EdgeInsets.symmetric(vertical: 8.s),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      decoration: BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.circular(16.s),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36.s,
                height: 4.s,
                margin: EdgeInsets.only(bottom: 10.s),
                decoration: BoxDecoration(
                  color: AppColors.neutral700,
                  borderRadius: BorderRadius.circular(2.s),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 8.s),
              child: Text(
                AppStrings.playlistPickTitle,
                style: AppStyles.label(14, weight: AppStyles.bold),
              ),
            ),
            _PlaylistRow(
              rowKey: const ValueKey('add-to-new-playlist'),
              icon: HugeIcons.strokeRoundedAdd01,
              label: AppStrings.playlistPickNew,
              busy: _busyId == _newPlaylistId,
              enabled: _busyId == null,
              onTap: () => unawaited(_createThenAdd()),
            ),
            Flexible(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 28.s),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      );
    }
    if (_failed) {
      return _Note(
        text: AppStrings.playlistPickFailed,
        action: AppStrings.tryAgain,
        onAction: () => unawaited(_load()),
      );
    }
    if (_playlists.isEmpty) {
      return _Note(text: AppStrings.playlistPickEmpty);
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.only(bottom: 8.s),
      itemCount: _playlists.length,
      itemBuilder: (_, i) {
        final playlist = _playlists[i];
        // The guide asks for the ceiling here rather than a refusal on
        // submit. Still tappable, because a row that cannot be tapped
        // cannot explain itself — the note is what says why.
        final full = playlist.itemCount >= PlaylistRepo.maxItems;
        return _PlaylistRow(
          rowKey: ValueKey('add-to-${playlist.id}'),
          icon: HugeIcons.strokeRoundedPlayList,
          label: playlist.name,
          detail: full
              ? AppStrings.playlistPickFull
              : AppStrings.playlistPickCount(playlist.itemCount),
          dimmed: full,
          busy: _busyId == playlist.id,
          enabled: _busyId == null,
          onTap: () => full
              ? _say(AppStrings.playlistPickFullNote(PlaylistRepo.maxItems))
              : unawaited(_add(playlist)),
        );
      },
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
    this.detail,
    this.dimmed = false,
  });

  final Key rowKey;
  final List<List<dynamic>> icon;
  final String label;
  final String? detail;
  final bool busy;
  final bool enabled;

  /// Drawn as unavailable while still answering a tap, so it can say why.
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: !enabled && !busy
          ? 0.4
          : dimmed
          ? 0.5
          : 1,
      child: GestureDetector(
        key: rowKey,
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 12.s),
          child: Row(
            children: [
              SizedBox(
                width: 18.s,
                height: 18.s,
                child: busy
                    ? CircularProgressIndicator(
                        strokeWidth: 2.s,
                        color: AppColors.brandPrimary,
                      )
                    : HugeIcon(
                        icon: icon,
                        color: AppColors.textPrimary,
                        size: 18.s,
                      ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.label(13),
                ),
              ),
              if (detail case final count?) ...[
                SizedBox(width: 8.s),
                Text(
                  count,
                  style: AppStyles.caption(11, color: AppColors.neutral500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 12.s, 16.s, 20.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: AppStyles.caption(12, color: AppColors.neutral400)),
          if (action case final label?) ...[
            SizedBox(height: 10.s),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Text(
                label,
                style: AppStyles.label(
                  13,
                  weight: AppStyles.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
