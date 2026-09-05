import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/settings/data/preferences_dummy_data.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The three account surfaces the design draws as overlays rather than
/// screens: choosing topics, and the two irreversible things.
///
/// Neither destructive action is wired, deliberately. `GET /v1/auth/sessions`
/// with `DELETE /v1/auth/sessions/{id}` would end every session, and
/// `DELETE /v1/user/account` would deactivate — both real, both impossible to
/// rehearse safely from here, and both far too costly to get wrong on a
/// guess. They stay behind their confirmations until someone can test them
/// against an account they are willing to lose.

/// Lets the reader pick which topics feed them, and in what order.
class TopicsSheet extends StatefulWidget {
  const TopicsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const TopicsSheet(),
  );

  @override
  State<TopicsSheet> createState() => _TopicsSheetState();
}

class _TopicsSheetState extends State<TopicsSheet> {
  late final List<(String, bool)> _topics = [...PreferencesDummyData.topics];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      decoration: BoxDecoration(
        color: AppColors.base1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.s)),
      ),
      // Its own Material, so the sheet renders correctly wherever it is put
      // rather than only inside showModalBottomSheet.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 10.s),
            Center(
              child: Container(
                width: 36.s,
                height: 4.s,
                decoration: BoxDecoration(
                  color: AppColors.neutral700,
                  borderRadius: BorderRadius.circular(2.s),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.s, 20.s, 20.s, 6.s),
              child: Text(
                AppStrings.topicsTitle,
                style: AppStyles.heading(20, lineHeight: 28 / 20),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.s),
              child: Text(
                AppStrings.topicsSubtitle,
                style: AppStyles.label(13, color: AppColors.neutral400),
              ),
            ),
            SizedBox(height: 20.s),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.s),
              child: Text(
                AppStrings.topicsCaption,
                style: AppStyles.label(13, weight: AppStyles.bold),
              ),
            ),
            SizedBox(height: 8.s),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20.s),
                buildDefaultDragHandles: false,
                itemCount: _topics.length,
                // onReorderItem, not onReorder: it hands back a target index
                // already adjusted for the row having left its old place.
                onReorderItem: (from, to) =>
                    setState(() => _topics.insert(to, _topics.removeAt(from))),
                itemBuilder: (context, i) {
                  final (label, on) = _topics[i];
                  return ReorderableDragStartListener(
                    key: ValueKey(label),
                    index: i,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.s),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyles.label(
                                14,
                                weight: AppStyles.bold,
                              ),
                            ),
                          ),
                          _TopicSwitch(
                            on: on,
                            onChanged: (v) =>
                                setState(() => _topics[i] = (label, v)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: AppColors.neutral800, height: 1),
            Padding(
              padding: EdgeInsets.all(20.s),
              child: _OutlinedAction(
                label: AppStrings.topicsDone,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppStrings.topicsNotWired,
                        style: AppStyles.body(13),
                      ),
                      backgroundColor: AppColors.neutral800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's pill: a tick when the topic is followed, a cross when not.
class _TopicSwitch extends StatelessWidget {
  const _TopicSwitch({required this.on, required this.onChanged});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52.s,
        height: 30.s,
        padding: EdgeInsets.all(3.s),
        decoration: BoxDecoration(
          color: on ? AppColors.brandPrimary : AppColors.neutral700,
          borderRadius: BorderRadius.circular(999.s),
        ),
        child: Row(
          mainAxisAlignment: on
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              width: 24.s,
              height: 24.s,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textPrimary,
              ),
              child: Icon(
                on ? Icons.check_rounded : Icons.close_rounded,
                size: 16.s,
                color: on ? AppColors.brandPrimary : AppColors.neutral500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Log out of all devices?" — signs out everywhere, this device included.
class LogOutAllDialog extends StatelessWidget {
  const LogOutAllDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const LogOutAllDialog(),
  );

  @override
  Widget build(BuildContext context) {
    return _ConfirmDialog(
      icon: HugeIcons.strokeRoundedComputerPhoneSync,
      tint: AppColors.brandPrimary,
      title: AppStrings.logOutAllTitle,
      body: AppStrings.logOutAllBody,
      confirmLabel: AppStrings.logOutAllConfirm,
      notWired: AppStrings.logOutAllNotWired,
      extra: _NotePlate(text: AppStrings.logOutAllNote),
    );
  }
}

/// "Deactivate your account?" — hides the profile and signs the reader out.
class DeactivateAccountDialog extends StatelessWidget {
  const DeactivateAccountDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const DeactivateAccountDialog(),
  );

  @override
  Widget build(BuildContext context) {
    return _ConfirmDialog(
      icon: HugeIcons.strokeRoundedUserRemove01,
      tint: AppColors.destructive,
      title: AppStrings.deactivateTitle,
      body: AppStrings.deactivateBody,
      confirmLabel: AppStrings.deactivateConfirm,
      notWired: AppStrings.deactivateNotWired,
      extra: Column(
        children: [
          _Reassurance(
            icon: Icons.check_rounded,
            tint: AppColors.green500,
            text: AppStrings.deactivateKeeps,
          ),
          _Reassurance(
            hugeIcon: HugeIcons.strokeRoundedRefresh,
            text: AppStrings.deactivateReturn,
          ),
          _Reassurance(
            hugeIcon: HugeIcons.strokeRoundedViewOffSlash,
            text: AppStrings.deactivateHidden,
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.notWired,
    required this.extra,
  });

  final List<List<dynamic>> icon;
  final Color tint;
  final String title;
  final String body;
  final String confirmLabel;
  final String notWired;
  final Widget extra;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.base2,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.s),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.s)),
      child: Padding(
        padding: EdgeInsets.all(20.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48.s,
              height: 48.s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.15),
              ),
              child: Center(
                child: HugeIcon(icon: icon, color: tint, size: 22.s),
              ),
            ),
            SizedBox(height: 16.s),
            Text(title, style: AppStyles.heading(18, lineHeight: 26 / 18)),
            SizedBox(height: 8.s),
            Text(
              body,
              style: AppStyles.label(
                13,
                color: AppColors.neutral300,
                lineHeight: 20 / 13,
              ),
            ),
            SizedBox(height: 16.s),
            extra,
            SizedBox(height: 20.s),
            Row(
              children: [
                Expanded(
                  child: _OutlinedAction(
                    label: AppStrings.commonCancel,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 12.s),
                Expanded(
                  child: _OutlinedAction(
                    label: confirmLabel,
                    destructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(notWired, style: AppStyles.body(13)),
                          backgroundColor: AppColors.neutral800,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet plate carrying the "why you might want this" note.
class _NotePlate extends StatelessWidget {
  const _NotePlate({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12.s),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            color: AppColors.neutral500,
            size: 18.s,
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Text(
              text,
              style: AppStyles.label(
                13,
                color: AppColors.neutral500,
                lineHeight: 20 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the things deactivating does *not* cost you.
class _Reassurance extends StatelessWidget {
  const _Reassurance({required this.text, this.icon, this.hugeIcon, this.tint});

  final String text;
  final IconData? icon;
  final List<List<dynamic>>? hugeIcon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22.s,
            height: 22.s,
            child: icon != null
                ? Icon(icon, size: 20.s, color: tint ?? AppColors.neutral500)
                : HugeIcon(
                    icon: hugeIcon!,
                    color: tint ?? AppColors.neutral500,
                    size: 18.s,
                  ),
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Text(
              text,
              style: AppStyles.label(
                13,
                color: AppColors.neutral400,
                lineHeight: 20 / 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design's bordered button, in neutral or in red.
class _OutlinedAction extends StatelessWidget {
  const _OutlinedAction({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? AppColors.destructive : AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.s),
          border: Border.all(
            color: destructive ? AppColors.destructive : AppColors.neutral700,
          ),
        ),
        child: Text(label, style: AppStyles.button(14, color: tint)),
      ),
    );
  }
}
