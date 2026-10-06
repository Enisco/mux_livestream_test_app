import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/features/engagement/repo/engagement_repo.dart';
import 'package:test_app/features/library/repo/viewer_library_repo.dart';
import 'package:test_app/features/library/views/library_list_screen.dart';
import 'package:test_app/models/engagement_models/engagement_models.dart';
import 'package:test_app/models/history_models/history_models.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// Take a row back out of a library.
///
/// `POST /v1/engagement/interactions` is a toggle, so posting the same
/// interaction again is the removal. The row's own `targetType` is what goes
/// on the call — the guide is explicit that mapping it from the entity type
/// on the client is wrong.
Future<void> _untoggle(HistoryEntry entry, String interactionType) =>
    GetIt.instance<EngagementRepo>().toggleInteraction(
      targetType: entry.targetType,
      targetId: entry.id,
      interactionType: interactionType,
    );

/// Everything the reader has appreciated.
class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key, this.repo});

  /// Defaults to the real thing; a test supplies its own.
  final ViewerLibraryRepo? repo;

  @override
  Widget build(BuildContext context) {
    final library = repo ?? ViewerLibraryRepo();
    return LibraryListScreen(
      title: AppStrings.likedTitle,
      load: ({String? cursor}) => library.fetchLiked(cursor: cursor),
      onRemove: (entry) => _untoggle(entry, InteractionTypes.like),
      countLabel: AppStrings.likedCount,
      emptyIcon: HugeIcons.strokeRoundedFavourite,
      emptyTitle: AppStrings.likedEmptyTitle,
      emptyBody: AppStrings.likedEmptyBody,
      clearTitle: AppStrings.likedClearTitle,
      clearBody: AppStrings.likedClearBody,
      trailingIcon: HugeIcons.strokeRoundedThumbsUp,
    );
  }
}

/// Everything the reader has put by for later.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key, this.repo});

  final ViewerLibraryRepo? repo;

  @override
  Widget build(BuildContext context) {
    final library = repo ?? ViewerLibraryRepo();
    return LibraryListScreen(
      title: AppStrings.savedTitle,
      load: ({String? cursor}) => library.fetchSaved(cursor: cursor),
      onRemove: (entry) => _untoggle(entry, InteractionTypes.favorite),
      countLabel: AppStrings.savedCount,
      emptyIcon: HugeIcons.strokeRoundedFavourite,
      emptyTitle: AppStrings.savedEmptyTitle,
      emptyBody: AppStrings.savedEmptyBody,
      clearTitle: AppStrings.savedClearTitle,
      clearBody: AppStrings.savedClearBody,
      trailingIcon: HugeIcons.strokeRoundedBookmark02,
      // Saved holds every kind, so it offers a way to see one at a time.
      filters: const [
        AppStrings.libraryFilterAll,
        AppStrings.libraryFilterVideo,
        AppStrings.libraryFilterAudio,
        AppStrings.libraryFilterDevotionals,
        AppStrings.libraryFilterArticles,
      ],
    );
  }
}
