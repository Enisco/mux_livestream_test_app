import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// One wheel for the day, another for the clock.
///
/// The two are deliberately separate: every screen that asks for a moment
/// shows a Date field and a Time field side by side, and moving one should
/// never quietly move the other.
Future<DateTime?> pickMoment(
  BuildContext context, {
  required DateTime initial,
  required bool dateOnly,
  DateTime? minimum,
}) {
  var draft = minimum != null && initial.isBefore(minimum) ? minimum : initial;

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.base2,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SizedBox(
        height: 280.s,
        child: Column(
          children: [
            SizedBox(
              height: 216.s,
              child: CupertinoTheme(
                data: const CupertinoThemeData(brightness: Brightness.dark),
                child: CupertinoDatePicker(
                  key: ValueKey(dateOnly ? 'wheel-date' : 'wheel-time'),
                  mode: dateOnly
                      ? CupertinoDatePickerMode.date
                      : CupertinoDatePickerMode.time,
                  initialDateTime: draft,
                  minimumDate: dateOnly ? minimum : null,
                  onDateTimeChanged: (value) => draft = value,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.s),
              child: PrimaryButton(
                label: AppStrings.newMediaDone,
                height: 46.s,
                onPressed: () => Navigator.pop(sheetContext, draft),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Keeps the day from [on] and the clock from [from], or the other way
/// round — whichever wheel was turned.
DateTime mergeMoment(DateTime on, DateTime from, {required bool dateOnly}) =>
    dateOnly
    ? DateTime(from.year, from.month, from.day, on.hour, on.minute)
    : DateTime(on.year, on.month, on.day, from.hour, from.minute);
