import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/creator_models/event_draft_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The pieces the New event screen is made of.

/// In Person, Virtual or Hybrid — three cards, one chosen.
///
/// The API calls the first one `physical`; the design calls it "In Person".
/// The two are not interchangeable: `in_person` is refused outright.
class EventTypeCards extends StatelessWidget {
  const EventTypeCards({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final EventVenueType selected;
  final ValueChanged<EventVenueType> onSelected;

  static (String, String, List<List<dynamic>>) _face(EventVenueType type) =>
      switch (type) {
        EventVenueType.physical => (
          AppStrings.newEventPhysical,
          AppStrings.newEventPhysicalBody,
          HugeIcons.strokeRoundedLocation01,
        ),
        EventVenueType.virtual => (
          AppStrings.newEventVirtual,
          AppStrings.newEventVirtualBody,
          HugeIcons.strokeRoundedVideo01,
        ),
        EventVenueType.hybrid => (
          AppStrings.newEventHybrid,
          AppStrings.newEventHybridBody,
          HugeIcons.strokeRoundedShuffle,
        ),
      };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final type in EventVenueType.values) ...[
        if (type != EventVenueType.values.first) SizedBox(height: 10.s),
        _Card(
          type: type,
          selected: type == selected,
          onTap: () => onSelected(type),
        ),
      ],
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final EventVenueType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, body, icon) = EventTypeCards._face(type);
    return GestureDetector(
      key: ValueKey('event-type-${type.name}'),
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
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: selected ? AppColors.brandPrimary : AppColors.neutral300,
              size: 20.s,
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppStyles.label(14, weight: AppStyles.bold),
                  ),
                  SizedBox(height: 3.s),
                  Text(
                    body,
                    style: AppStyles.body(
                      12,
                      color: AppColors.neutral400,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A field that opens a wheel rather than a keyboard — a date, or a time.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.fieldKey,
    required this.value,
    required this.hint,
    required this.onTap,
    this.onClear,
  });

  final Key fieldKey;

  /// Empty shows [hint], which is how "no end date" reads.
  final String value;
  final String hint;

  final VoidCallback onTap;

  /// Only the end date can be given back once set.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: fieldKey,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 48.s,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 14.s),
      decoration: BoxDecoration(
        color: AppColors.brandAltDark,
        borderRadius: BorderRadius.circular(8.s),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value.isEmpty ? hint : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.body(
                13,
                color: value.isEmpty
                    ? AppColors.neutral400
                    : AppColors.neutral50,
              ),
            ),
          ),
          if (onClear case final clear? when value.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: clear,
              child: Padding(
                padding: EdgeInsets.only(left: 8.s),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: AppColors.neutral400,
                  size: 15.s,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// "ⓘ Leave blank if no end date" — the design's quiet asides.
class FieldNote extends StatelessWidget {
  const FieldNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 6.s),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1.s),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            color: AppColors.neutral500,
            size: 12.s,
          ),
        ),
        SizedBox(width: 5.s),
        Expanded(
          child: Text(
            text,
            style: AppStyles.label(
              11,
              color: AppColors.neutral500,
              lineHeight: 15 / 11,
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Allow RSVP" — a row with a switch, and a line saying what it does.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.rowKey,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final Key rowKey;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: rowKey,
    behavior: HitTestBehavior.opaque,
    onTap: () => onChanged(!value),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppStyles.label(14, weight: AppStyles.bold)),
              SizedBox(height: 3.s),
              Text(
                body,
                style: AppStyles.body(
                  12,
                  color: AppColors.neutral400,
                  lineHeight: 16 / 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.s),
        _Switch(on: value),
      ],
    ),
  );
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 44.s,
    height: 26.s,
    padding: EdgeInsets.all(3.s),
    alignment: on ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(
      color: on ? AppColors.brandPrimary : AppColors.neutral700,
      borderRadius: BorderRadius.circular(999.s),
    ),
    child: Container(
      width: 20.s,
      height: 20.s,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textPrimary,
      ),
      child: on
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              color: AppColors.brandPrimary,
              size: 13.s,
            )
          : null,
    ),
  );
}
