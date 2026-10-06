import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/creator_models/impact_models.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The sheets behind the Impact screen's filter row, and the report flow.

/// One radio row, as every one of these sheets draws it.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final T value;
  final bool selected;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('choice-$label'),
    behavior: HitTestBehavior.opaque,
    onTap: () => onTap(value),
    child: Container(
      margin: EdgeInsets.only(bottom: 10.s),
      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 15.s),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(10.s),
        border: Border.all(
          color: selected ? AppColors.brandPrimary : Colors.transparent,
          width: 1.4.s,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppStyles.label(14))),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20.s,
            color: selected ? AppColors.brandPrimary : AppColors.neutral500,
          ),
        ],
      ),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children, this.onBack});

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.s)),
      ),
      padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 20.s),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (onBack case final back?) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: back,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 20.s,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 12.s),
                ],
                Expanded(child: Text(title, style: AppStyles.heading(17))),
                GestureDetector(
                  key: const ValueKey('sheet-close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20.s,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.s),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// Open prayers, the ones already prayed for, or the ones closed out.
Future<PrayerFilter?> showPrayerStateSheet(
  BuildContext context, {
  required PrayerFilter selected,
}) => showModalBottomSheet<PrayerFilter>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (sheet) => _SheetFrame(
    title: AppStrings.prayerStateTitle,
    children: [
      for (final (value, label) in const [
        (PrayerFilter.open, AppStrings.prayerStateOpen),
        (PrayerFilter.prayedFor, AppStrings.prayerStatePrayed),
        (PrayerFilter.closed, AppStrings.prayerStateResolved),
      ])
        _Choice<PrayerFilter>(
          label: label,
          value: value,
          selected: value == selected,
          onTap: (v) => Navigator.pop(sheet, v),
        ),
    ],
  ),
);

/// The "…" on a prayer card.
///
/// Which rows appear depends on where the prayer already is: an open one
/// cannot be re-opened, a resolved one cannot be resolved again, and a
/// resolved one shows Assign greyed rather than hiding it, as the design
/// draws it.
Future<PrayerAction?> showPrayerActionsSheet(
  BuildContext context, {
  required PrayerRequest prayer,
}) {
  final rows = <(PrayerAction, String, IconData, bool)>[
    (
      PrayerAction.assign,
      AppStrings.prayerMenuAssign,
      Icons.person_add_alt_1_outlined,
      !prayer.isClosed,
    ),
    if (prayer.isPrayedFor || prayer.isClosed)
      (
        PrayerAction.reopen,
        AppStrings.prayerMenuReopen,
        Icons.arrow_forward_rounded,
        true,
      ),
    if (!prayer.isClosed)
      (
        PrayerAction.resolve,
        AppStrings.prayerMenuResolve,
        Icons.check_circle_outline_rounded,
        true,
      ),
  ];

  return showModalBottomSheet<PrayerAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheet) => SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.base2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.s)),
        ),
        padding: EdgeInsets.fromLTRB(20.s, 10.s, 20.s, 10.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36.s,
                height: 4.s,
                margin: EdgeInsets.only(bottom: 14.s),
                decoration: BoxDecoration(
                  color: AppColors.neutral700,
                  borderRadius: BorderRadius.circular(999.s),
                ),
              ),
            ),
            for (final (action, label, icon, enabled) in rows)
              GestureDetector(
                key: ValueKey('prayer-action-$label'),
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? () => Navigator.pop(sheet, action) : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.s),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 19.s,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.neutral700,
                      ),
                      SizedBox(width: 14.s),
                      Text(
                        label,
                        style: AppStyles.label(
                          14,
                          color: enabled
                              ? AppColors.textPrimary
                              : AppColors.neutral700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// "Assign prayer to:" — who on the team is carrying this one.
///
/// [members] is `GET …/prayers/assignees`, which is **not** the general
/// member list: only owners, admins and editors can be assigned, so asking
/// the team route instead would offer people the write would refuse.
///
/// Returning an [ImpactPerson] whose `userId` is null means "unassign", which
/// the caller must send as an explicit `null` rather than omitting the field.
Future<ImpactPerson?> showAssignPrayerSheet(
  BuildContext context, {
  required List<ImpactPerson> members,
  String? selectedId,
}) => showModalBottomSheet<ImpactPerson>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (sheet) => _SheetFrame(
    title: AppStrings.prayerAssignTitle,
    children: [
      for (final member in members)
        _AssignRow(
          member: member,
          selected: member.userId != null && member.userId == selectedId,
          onTap: () => Navigator.pop(sheet, member),
        ),
      if (members.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10.s),
          child: Text(
            AppStrings.prayerAssignNoTeamBody,
            style: AppStyles.body(
              13,
              color: AppColors.neutral400,
              lineHeight: 19 / 13,
            ),
          ),
        ),
      if (selectedId != null) ...[
        SizedBox(height: 6.s),
        GestureDetector(
          key: const ValueKey('assign-clear'),
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              Navigator.pop(sheet, const ImpactPerson(displayName: '')),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.s),
            child: Text(
              AppStrings.prayerUnassign,
              style: AppStyles.label(
                13,
                weight: AppStyles.semiBold,
                color: AppColors.destructive,
              ),
            ),
          ),
        ),
      ],
    ],
  ),
);

class _AssignRow extends StatelessWidget {
  const _AssignRow({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final ImpactPerson member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = AssetUrlResolver.resolve(member.avatarKey);
    final name = member.displayName.trim().isEmpty
        ? AppStrings.impactSomeone
        : member.displayName;
    return GestureDetector(
      key: ValueKey('assign-${member.userId}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 11.s),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19.s,
              backgroundColor: AppColors.neutral800,
              backgroundImage: avatarUrl == null
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl != null
                  ? null
                  : Text(
                      name.characters.first.toUpperCase(),
                      style: AppStyles.label(
                        14,
                        weight: AppStyles.bold,
                        color: AppColors.neutral400,
                      ),
                    ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(14, weight: AppStyles.semiBold),
                  ),
                  SizedBox(height: 2.s),
                  Text(
                    member.role ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.body(12, color: AppColors.neutral500),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.s),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20.s,
              color: selected ? AppColors.brandPrimary : AppColors.neutral500,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pending, approved or turned down.
///
/// These three are the whole state machine: there is no separate "unpublish",
/// so taking an approved story off the wall moves it to rejected, and
/// restoring puts it back in the pending queue rather than straight back on
/// the wall.
Future<TestimonyFilter?> showTestimonyStateSheet(
  BuildContext context, {
  required TestimonyFilter selected,
}) => showModalBottomSheet<TestimonyFilter>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (sheet) => _SheetFrame(
    title: AppStrings.testimonyStateTitle,
    children: [
      for (final (value, label) in const [
        (TestimonyFilter.pending, AppStrings.testimonyStatePending),
        (TestimonyFilter.approved, AppStrings.testimonyStateApproved),
        (TestimonyFilter.rejected, AppStrings.testimonyStateRejected),
      ])
        _Choice<TestimonyFilter>(
          label: label,
          value: value,
          selected: value == selected,
          onTap: (v) => Navigator.pop(sheet, v),
        ),
    ],
  ),
);

/// Which part of the moderation queue to show.
///
/// "All" means both moderation states, not every comment — the queue has no
/// `visible` rows to offer and the gateway rejects a request for them.
Future<CommentFilter?> showCommentStateSheet(
  BuildContext context, {
  required CommentFilter selected,
}) => showModalBottomSheet<CommentFilter>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (sheet) => _SheetFrame(
    title: AppStrings.commentStateTitle,
    children: [
      for (final (value, label) in const [
        (CommentFilter.both, AppStrings.commentStateAll),
        (CommentFilter.flagged, AppStrings.commentStateFlagged),
        (CommentFilter.hidden, AppStrings.commentStateHidden),
      ])
        _Choice<CommentFilter>(
          label: label,
          value: value,
          selected: value == selected,
          onTap: (v) => Navigator.pop(sheet, v),
        ),
    ],
  ),
);

/// What a creator is reporting, and anything they want to add.
///
/// The eight rows are the design's. Seven map onto a value
/// `POST /v1/engagement/reports` accepts; **"Copyright or impersonation" does
/// not** — the API has no such reason, so it travels as `other` and whoever
/// reviews it loses the distinction. Worth raising rather than quietly
/// dropping the row.
const reportChoices = <(ReportReason, String)>[
  (ReportReason.spam, AppStrings.reportSpam),
  (ReportReason.hate, AppStrings.reportHate),
  (ReportReason.harassment, AppStrings.reportHarassment),
  (ReportReason.sexualContent, AppStrings.reportSexual),
  (ReportReason.violence, AppStrings.reportViolence),
  (ReportReason.misinformation, AppStrings.reportMisinformation),
  (ReportReason.other, AppStrings.reportImpersonation),
  (ReportReason.other, AppStrings.reportOther),
];

/// What the reader chose, and whatever they typed.
class ReportOutcome {
  const ReportOutcome({required this.reason, required this.detail});

  final ReportReason reason;
  final String detail;
}

Future<ReportOutcome?> showReportSheet(BuildContext context) =>
    showModalBottomSheet<ReportOutcome>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ReportSheet(),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  int? _picked;
  bool _detailing = false;
  final _detail = TextEditingController();

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_detailing && _picked != null) {
      final (reason, label) = reportChoices[_picked!];
      return _SheetFrame(
        title: label,
        onBack: () => setState(() => _detailing = false),
        children: [
          Row(
            children: [
              Text(
                AppStrings.reportTellMore,
                style: AppStyles.label(13, weight: AppStyles.semiBold),
              ),
              SizedBox(width: 6.s),
              Text(
                AppStrings.reportOptional,
                style: AppStyles.body(13, color: AppColors.neutral500),
              ),
            ],
          ),
          SizedBox(height: 10.s),
          CreatorTextField(
            key: const ValueKey('report-detail'),
            controller: _detail,
            hint: AppStrings.reportHint,
            maxLines: 5,
          ),
          SizedBox(height: 12.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15.s,
                color: AppColors.neutral500,
              ),
              SizedBox(width: 8.s),
              Expanded(
                child: Text(
                  AppStrings.reportPrivacy,
                  style: AppStyles.body(
                    11,
                    color: AppColors.neutral500,
                    lineHeight: 16 / 11,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.s),
          PrimaryButton(
            label: AppStrings.reportSubmit,
            height: 50.s,
            onPressed: () => Navigator.pop(
              context,
              ReportOutcome(reason: reason, detail: _detail.text.trim()),
            ),
          ),
        ],
      );
    }

    return _SheetFrame(
      title: AppStrings.reportTitle,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16.s),
          child: Text(
            AppStrings.reportSubtitle,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
        ),
        for (final (i, (_, label)) in reportChoices.indexed)
          _Choice<int>(
            label: label,
            value: i,
            selected: _picked == i,
            onTap: (v) => setState(() => _picked = v),
          ),
        SizedBox(height: 10.s),
        PrimaryButton(
          label: AppStrings.reportNext,
          height: 50.s,
          enabled: _picked != null,
          onPressed: () => setState(() => _detailing = true),
        ),
      ],
    );
  }
}
