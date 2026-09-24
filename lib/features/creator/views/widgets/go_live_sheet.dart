import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/moment_picker.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// "When should this go live" — publish now, or pick a moment.
///
/// Scheduling is a property of the media row itself: `POST /v1/media` takes
/// `scheduledAt` and the backend publishes at that time on its own. The
/// publish route refuses it. So this sheet decides which of the two calls
/// the screen makes, not an extra one.
class GoLiveSheet extends StatefulWidget {
  const GoLiveSheet({super.key, required this.onChoose, this.initialAt});

  final ValueChanged<PublishChoice> onChoose;

  /// The moment the schedule fields start on. Defaults to the next round
  /// hour; a test sets it to reach the states time would otherwise bring.
  final DateTime? initialAt;

  /// Returns the choice, or null if the sheet was dismissed.
  static Future<PublishChoice?> show(BuildContext context) =>
      showModalBottomSheet<PublishChoice>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => GoLiveSheet(
          onChoose: (choice) => Navigator.pop(sheetContext, choice),
        ),
      );

  @override
  State<GoLiveSheet> createState() => _GoLiveSheetState();
}

class _GoLiveSheetState extends State<GoLiveSheet> {
  bool _later = false;

  /// Defaults to the next round hour, so a creator who taps straight through
  /// never schedules something into the past.
  late DateTime _at = widget.initialAt ?? _nextHour();

  static DateTime _nextHour() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(const Duration(hours: 1));
  }

  /// `POST /v1/media` refuses a schedule that has already passed —
  /// *"scheduledAt must be in the future"* — and by then the whole file has
  /// been uploaded, so the refusal has to be caught here instead.
  bool get _valid => !_later || _at.isAfter(DateTime.now());

  void _submit() {
    if (!_valid) return;
    widget.onChoose(
      _later ? PublishChoice.scheduled(_at) : const PublishChoice.now(),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16.s,
      MediaQuery.paddingOf(context).top + 40.s,
      16.s,
      MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.base2,
                borderRadius: BorderRadius.circular(16.s),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18.s, 20.s, 18.s, 20.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(context),
                    SizedBox(height: 16.s),
                    Divider(color: AppColors.neutral800, height: 1.s),
                    SizedBox(height: 16.s),
                    Text(
                      AppStrings.goLiveSheetQuestion,
                      style: AppStyles.body(
                        13,
                        color: AppColors.neutral300,
                        lineHeight: 18 / 13,
                      ),
                    ),
                    SizedBox(height: 12.s),
                    _Option(
                      optionKey: const ValueKey('go-live-now'),
                      title: AppStrings.goLiveNow,
                      body: AppStrings.goLiveNowBody,
                      selected: !_later,
                      onTap: () => setState(() => _later = false),
                    ),
                    SizedBox(height: 10.s),
                    _Option(
                      optionKey: const ValueKey('go-live-later'),
                      title: AppStrings.goLiveLater,
                      body: AppStrings.goLiveLaterBody,
                      selected: _later,
                      onTap: () => setState(() => _later = true),
                      extra: Padding(
                        padding: EdgeInsets.only(top: 14.s),
                        child: Row(
                          children: [
                            Expanded(
                              child: _WhenField(
                                fieldKey: const ValueKey('go-live-date'),
                                label: AppStrings.goLiveDate,
                                value: formatSheetDate(_at),
                                onTap: () => _pick(context, dateOnly: true),
                              ),
                            ),
                            SizedBox(width: 12.s),
                            Expanded(
                              child: _WhenField(
                                fieldKey: const ValueKey('go-live-time'),
                                label: AppStrings.goLiveTime,
                                value: formatSheetTime(_at),
                                onTap: () => _pick(context, dateOnly: false),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_valid) ...[
                      SizedBox(height: 10.s),
                      Text(
                        AppStrings.goLivePastMoment,
                        style: AppStyles.label(
                          12,
                          color: AppColors.destructive,
                          lineHeight: 16 / 12,
                        ),
                      ),
                    ],
                    SizedBox(height: 22.s),
                    PrimaryButton(
                      key: const ValueKey('go-live-confirm'),
                      label: _later
                          ? AppStrings.goLiveSchedule
                          : AppStrings.goLiveNow,
                      height: 52.s,
                      enabled: _valid,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 14.s),
          GestureDetector(
            key: const ValueKey('go-live-cancel'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: EdgeInsets.only(bottom: 20.s),
              child: Text(
                AppStrings.goLiveCancel,
                textAlign: TextAlign.center,
                style: AppStyles.label(13, color: AppColors.neutral300),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pick(BuildContext context, {required bool dateOnly}) async {
    // A moment only makes sense in the future: the API publishes within
    // about twenty seconds of it, and refuses one already gone.
    final picked = await pickMoment(
      context,
      initial: _at,
      dateOnly: dateOnly,
      minimum: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _at = mergeMoment(_at, picked, dateOnly: dateOnly));
  }

  Widget _header(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.goLiveSheetTitle,
              style: AppStyles.heading(20, letterSpacing: -0.5),
            ),
            SizedBox(height: 6.s),
            Text(
              AppStrings.goLiveSheetSubtitle,
              style: AppStyles.body(
                13,
                color: AppColors.neutral400,
                lineHeight: 18 / 13,
              ),
            ),
          ],
        ),
      ),
      GestureDetector(
        key: const ValueKey('go-live-close'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: EdgeInsets.only(left: 12.s),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            color: AppColors.textPrimary,
            size: 20.s,
          ),
        ),
      ),
    ],
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.optionKey,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    this.extra,
  });

  final Key optionKey;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  /// The date and time fields, which only the second option carries.
  final Widget? extra;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: optionKey,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.s),
        border: Border.all(
          color: selected ? AppColors.brandPrimary : AppColors.neutral800,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppStyles.label(14, weight: AppStyles.bold),
                    ),
                    SizedBox(height: 4.s),
                    Text(
                      body,
                      style: AppStyles.body(
                        13,
                        color: AppColors.neutral400,
                        lineHeight: 17 / 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.s),
              _Radio(on: selected),
            ],
          ),
          ?extra,
        ],
      ),
    ),
  );
}

class _Radio extends StatelessWidget {
  const _Radio({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 20.s,
    height: 20.s,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.textPrimary, width: 1.6.s),
    ),
    child: on
        ? Container(
            width: 10.s,
            height: 10.s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textPrimary,
            ),
          )
        : null,
  );
}

class _WhenField extends StatelessWidget {
  const _WhenField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: AppStyles.label(12, weight: AppStyles.medium)),
      SizedBox(height: 6.s),
      GestureDetector(
        key: fieldKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44.s,
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: 12.s),
          decoration: BoxDecoration(
            color: AppColors.brandAltDark,
            borderRadius: BorderRadius.circular(8.s),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.body(13, color: AppColors.neutral300),
          ),
        ),
      ),
    ],
  );
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Sun, Jun 1, 2025" — the way the design writes the date.
String formatSheetDate(DateTime at) =>
    '${_weekdays[at.weekday - 1]}, ${_months[at.month - 1]} '
    '${at.day}, ${at.year}';

/// "6:00 AM".
String formatSheetTime(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${at.hour < 12 ? 'AM' : 'PM'}';
}
