import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/features/library/views/library_list_screen.dart'
    show glyphFor, metaFor;
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Picking what goes into a playlist.
///
/// Rows already in it say so and cannot be picked again; the rest carry an Add
/// button that stays lit once tapped. Returns the ids chosen, or null if the
/// reader backed out.
///
/// What is offered is [suggestions] — anchored on what the playlist already
/// holds — falling back to what is popular when it is empty and there is
/// nothing to anchor on. **Playlists hold media only**, so nothing else is
/// offered here.
class PlaylistAddScreen extends StatefulWidget {
  const PlaylistAddScreen({
    super.key,
    required this.playlistName,
    this.anchorMediaId,
    this.alreadyIn = const {},
    this.discovery,
  });

  final String playlistName;

  /// What to anchor suggestions on: the playlist's first item.
  final String? anchorMediaId;

  /// Ids already in the playlist, which cannot be picked again — a duplicate
  /// add answers 409 rather than doing nothing.
  final Set<String> alreadyIn;

  final DiscoveryRepo? discovery;

  @override
  State<PlaylistAddScreen> createState() => _PlaylistAddScreenState();
}

class _PlaylistAddScreenState extends State<PlaylistAddScreen> {
  final _picked = <String>{};
  late final _repo = widget.discovery ?? getIt<DiscoveryRepo>();

  List<HistoryEntry> _options = const [];
  bool _loading = true;
  bool _failed = false;

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
      final anchor = widget.anchorMediaId;
      final page = anchor == null
          // An empty playlist has nothing to suggest from, so this falls
          // back to what is popular rather than offering nothing at all.
          ? await _repo.searchPublic(
              entityTypes: const ['media'],
              sort: 'popular',
              size: 20,
            )
          : await _repo.fetchContentSuggestions(
              targetType: 'media',
              targetId: anchor,
              limit: 20,
            );
      if (!mounted) return;
      setState(() {
        _options = [
          for (final item in page.items)
            if (item.entityType == 'media')
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
        _loading = false;
      });
    } catch (e) {
      logger.w('Playlist options failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GTubeBackButton(size: 24, box: 24),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(context),
                        child: SizedBox(
                          width: 24.s,
                          height: 24.s,
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: AppColors.textPrimary,
                            size: 22.s,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.s),
                  Text(
                    AppStrings.playlistAddTitle,
                    style: AppStyles.label(
                      18,
                      weight: AppStyles.bold,
                      lineHeight: 28 / 18,
                    ),
                  ),
                  SizedBox(height: 4.s),
                  // The playlist's own name is the only thing that changes
                  // between visits, so the design puts it in colour.
                  Text.rich(
                    TextSpan(
                      style: AppStyles.label(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 16 / 12,
                      ),
                      children: [
                        const TextSpan(
                          text: '${AppStrings.playlistAddToPrefix} ',
                        ),
                        TextSpan(
                          text: '"${widget.playlistName}"',
                          style: AppStyles.label(
                            12,
                            color: AppColors.brandPrimary,
                            lineHeight: 16 / 12,
                          ),
                        ),
                        const TextSpan(
                          text: ' ${AppStrings.playlistAddToSuffix}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.s),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : _failed
                  ? ErrorStateView(onRetry: _load)
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 12.s),
                      itemCount: _options.length,
                      itemBuilder: (context, i) {
                        final item = _options[i];
                        final already = widget.alreadyIn.contains(item.id);
                        final picked = _picked.contains(item.id);

                        return ContentListRow(
                          key: ValueKey('add-${item.id}'),
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
                          trailing: _AddControl(
                            added: already || picked,
                            onTap: already
                                ? null
                                : () => setState(() {
                                    picked
                                        ? _picked.remove(item.id)
                                        : _picked.add(item.id);
                                  }),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 20.s),
              child: Opacity(
                opacity: _picked.isEmpty ? 0.5 : 1,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _picked.isEmpty
                      ? null
                      : () => Navigator.pop(context, {..._picked}),
                  child: Container(
                    height: 52.s,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.fieldBg,
                      borderRadius: BorderRadius.circular(8.s),
                      border: Border.all(color: AppColors.neutral800),
                    ),
                    child: Text(
                      AppStrings.playlistAddSelection,
                      style: AppStyles.button(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Either the amber Add pill or the disc that says it is already in.
class _AddControl extends StatelessWidget {
  const _AddControl({required this.added, required this.onTap});

  final bool added;

  /// Null for rows that are already in the playlist — there is nothing left
  /// to do to them.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (added) {
      return Container(
        key: const ValueKey('added'),
        width: 24.s,
        height: 24.s,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.neutral800,
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedTick02,
          color: AppColors.textPrimary,
          size: 14.s,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 5.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999.s),
          border: Border.all(color: AppColors.brandPrimary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAddCircle,
              color: AppColors.brandPrimary,
              size: 12.s,
            ),
            SizedBox(width: 4.s),
            Text(
              AppStrings.playlistAdd,
              style: AppStyles.label(
                11,
                weight: AppStyles.bold,
                color: AppColors.brandPrimary,
                lineHeight: 14 / 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
