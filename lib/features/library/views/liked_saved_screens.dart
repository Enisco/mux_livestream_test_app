import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/features/library/data/library_dummy_data.dart';
import 'package:test_app/features/library/views/library_list_screen.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// Everything the reader has appreciated.
class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  @override
  Widget build(BuildContext context) => LibraryListScreen(
    title: AppStrings.likedTitle,
    days: LibraryDummyData.liked,
    total: LibraryDummyData.likedTotal,
    countSuffix: AppStrings.likedCountSuffix,
    emptyIcon: HugeIcons.strokeRoundedFavourite,
    emptyTitle: AppStrings.likedEmptyTitle,
    emptyBody: AppStrings.likedEmptyBody,
    clearTitle: AppStrings.likedClearTitle,
    clearBody: AppStrings.likedClearBody,
    trailingIcon: HugeIcons.strokeRoundedThumbsUp,
  );
}

/// Everything the reader has put by for later.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) => LibraryListScreen(
    title: AppStrings.savedTitle,
    days: LibraryDummyData.saved,
    total: LibraryDummyData.savedTotal,
    countSuffix: AppStrings.savedCountSuffix,
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
