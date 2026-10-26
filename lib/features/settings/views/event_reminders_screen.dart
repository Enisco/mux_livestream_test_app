import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'dart:async';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/features/notifications/repo/notification_repo.dart';
import 'package:test_app/models/notification_models/notification_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Whether to be reminded about events, and how long beforehand.
///
/// Runs on `GET`/`PATCH /v1/notification/preferences`, which gained the two
/// reminder fields on 2026-10-26.
///
/// Three things the contract insists on, all of them visible here:
///
/// - **Five offsets, not four.** `120` is in the set because RSVP rows
///   already held it; dropping it would have orphaned reminders viewers had
///   set. See [reminderOffsets].
/// - **"Off" and "the organiser's schedule" are different states.**
///   `eventRemindersEnabled: false` is off; `eventReminderMinutes: null` means
///   follow whatever the organiser set. So there are two controls, and the
///   picker has no Off row.
/// - **It applies to RSVPs made from now on.** It does not move reminders on
///   events already RSVP'd to, which is why the note says "from now on"
///   rather than "your events".
class EventRemindersScreen extends StatefulWidget {
  const EventRemindersScreen({super.key, this.repo});

  /// Defaults to the real thing; a test supplies its own.
  final NotificationRepo? repo;

  @override
  State<EventRemindersScreen> createState() => _EventRemindersScreenState();
}

class _EventRemindersScreenState extends State<EventRemindersScreen> {
  late final _repo = widget.repo ?? getIt<NotificationRepo>();

  bool _on = true;

  /// Null means "use the organiser's schedule", which is its own row.
  int? _lead;

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
      final prefs = await _repo.fetchPreferences();
      if (!mounted) return;
      setState(() {
        _on = prefs.eventReminders;
        _lead = prefs.eventReminderMinutes;
        _loading = false;
      });
    } catch (e) {
      logger.w('Reminder preferences failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Optimistic, and put back if the write is refused — a switch that springs
  /// back is clearer than one that lies.
  Future<void> _save({bool? on, int? lead, bool organiser = false}) async {
    final beforeOn = _on;
    final beforeLead = _lead;
    setState(() {
      if (on != null) _on = on;
      if (organiser) {
        _lead = null;
      } else if (lead != null) {
        _lead = lead;
      }
    });
    try {
      await _repo.updatePreferences(
        eventReminders: on,
        eventReminderMinutes: organiser ? null : lead,
        clearReminderMinutes: organiser,
      );
    } catch (e) {
      logger.w('Reminder preferences save failed', error: e);
      if (!mounted) return;
      setState(() {
        _on = beforeOn;
        _lead = beforeLead;
      });
      _report();
    }
  }

  void _report() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.settingsSaveFailed, style: AppStyles.body(13)),
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
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandPrimary,
                  ),
                ),
              )
            else if (_failed)
              Expanded(child: ErrorStateView(onRetry: _load))
            else
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
                            onChanged: (v) => unawaited(_save(on: v)),
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
                            // Its own row, not an entry in the picker: it is a
                            // different state from "off", and from any offset.
                            _LeadRow(
                              key: const ValueKey('reminder-organiser'),
                              label: AppStrings.remindersOrganiser,
                              isDefault: true,
                              selected: _lead == null,
                              onTap: () => unawaited(_save(organiser: true)),
                            ),
                            SizedBox(height: 10.s),
                            for (final minutes in reminderOffsets) ...[
                              _LeadRow(
                                key: ValueKey('reminder-$minutes'),
                                label: reminderOffsetLabel(minutes),
                                isDefault: false,
                                selected: minutes == _lead,
                                onTap: () => unawaited(_save(lead: minutes)),
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
    super.key,
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
