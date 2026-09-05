import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/data/preferences_dummy_data.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Whether to be reminded about events, and how long beforehand.
///
/// Nothing here saves. No route in the spec stores a lead time or a reminder
/// preference — see [PreferencesDummyData].
class EventRemindersScreen extends StatefulWidget {
  const EventRemindersScreen({super.key});

  @override
  State<EventRemindersScreen> createState() => _EventRemindersScreenState();
}

class _EventRemindersScreenState extends State<EventRemindersScreen> {
  bool _on = PreferencesDummyData.remindersOn;
  int _lead = PreferencesDummyData.selectedLeadMinutes;

  void _report() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.remindersNotWired,
          style: AppStyles.body(13),
        ),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              padding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 24.s),
              child: Row(
                children: [
                  const GTubeBackButton(size: 24, box: 24),
                  SizedBox(width: 12.s),
                  Flexible(
                    child: Text(
                      AppStrings.remindersTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.label(
                        18,
                        weight: AppStyles.bold,
                        lineHeight: 28 / 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16.s),
                children: [
                  _Plate(
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedNotification03,
                          color: AppColors.brandPrimary,
                          size: 20.s,
                        ),
                        SizedBox(width: 12.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.remindersToggle,
                                style: AppStyles.label(
                                  14,
                                  weight: AppStyles.bold,
                                ),
                              ),
                              SizedBox(height: 2.s),
                              Text(
                                AppStrings.remindersToggleSub,
                                style: AppStyles.label(
                                  12,
                                  color: AppColors.neutral500,
                                  lineHeight: 16 / 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _on,
                          activeThumbColor: AppColors.textPrimary,
                          activeTrackColor: AppColors.brandPrimary,
                          inactiveThumbColor: AppColors.neutral400,
                          inactiveTrackColor: AppColors.neutral800,
                          onChanged: (v) {
                            setState(() => _on = v);
                            _report();
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.s),
                  Padding(
                    padding: EdgeInsets.only(left: 4.s, bottom: 10.s),
                    child: Text(
                      AppStrings.remindersWhen,
                      style: AppStyles.label(
                        12,
                        weight: AppStyles.bold,
                        color: AppColors.neutral500,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ),
                  // The choices only mean something while reminders are on.
                  Opacity(
                    opacity: _on ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !_on,
                      child: Column(
                        children: [
                          for (final minutes
                              in PreferencesDummyData.leadTimes) ...[
                            _LeadRow(
                              label: leadTimeLabel(minutes),
                              isDefault: minutes ==
                                  PreferencesDummyData.defaultLeadMinutes,
                              selected: minutes == _lead,
                              onTap: () {
                                setState(() => _lead = minutes);
                                _report();
                              },
                            ),
                            SizedBox(height: 10.s),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 20.s),
              child: _Plate(
                child: Text(
                  AppStrings.remindersNote,
                  style: AppStyles.label(
                    13,
                    color: AppColors.neutral300,
                    lineHeight: 20 / 13,
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

class _LeadRow extends StatelessWidget {
  const _LeadRow({
    required this.label,
    required this.selected,
    required this.isDefault,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _Plate(
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(14, weight: AppStyles.bold),
              ),
            ),
            if (isDefault) ...[
              SizedBox(width: 10.s),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 2.s),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.s),
                ),
                child: Text(
                  AppStrings.remindersDefault,
                  style: AppStyles.label(
                    11,
                    weight: AppStyles.bold,
                    color: AppColors.brandPrimary,
                    lineHeight: 16 / 11,
                  ),
                ),
              ),
            ],
            const Spacer(),
            _Radio(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18.s,
      height: 18.s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.brandPrimary : AppColors.neutral500,
          width: selected ? 5.s : 1.5.s,
        ),
      ),
    );
  }
}

/// The rounded plate the reminder rows sit on.
class _Plate extends StatelessWidget {
  const _Plate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 14.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12.s),
      ),
      child: child,
    );
  }
}
