import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/features/library/repo/viewer_records_repo.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// Picking an order for one of the three "mine" lists.
///
/// `recent` and `oldest` mean **when the viewer acted** — when they RSVP'd,
/// asked or submitted. Only events offer a second axis, `start_soonest`,
/// because only an event has a date of its own worth sorting on; the picker
/// takes [withStartSoonest] rather than offering a value the other two lists
/// answer `400` to.
Future<RecordsSort?> showRecordsSortSheet(
  BuildContext context, {
  required RecordsSort current,
  bool withStartSoonest = false,
}) {
  final options = <RecordsSort>[
    RecordsSort.recent,
    RecordsSort.oldest,
    if (withStartSoonest) RecordsSort.startSoonest,
  ];

  return showModalBottomSheet<RecordsSort>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => LibraryActionSheet(
      actions: [
        for (final sort in options)
          LibraryAction(
            label: recordsSortLabel(sort),
            icon: sort == current
                ? HugeIcons.strokeRoundedCheckmarkCircle02
                : HugeIcons.strokeRoundedSorting05,
          ),
      ],
      onSelected: (picked) {
        for (final sort in options) {
          if (recordsSortLabel(sort) == picked) {
            Navigator.pop(sheetContext, sort);
            return;
          }
        }
        Navigator.pop(sheetContext);
      },
    ),
  );
}

String recordsSortLabel(RecordsSort sort) => switch (sort) {
  RecordsSort.recent => AppStrings.sortRecent,
  RecordsSort.oldest => AppStrings.sortOldest,
  RecordsSort.startSoonest => AppStrings.sortStartSoonest,
};
