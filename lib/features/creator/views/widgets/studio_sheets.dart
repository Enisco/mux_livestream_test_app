import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// The two sheets the Studio tab opens.

/// What a studio can be made of. The Create sheet offers only the kinds the
/// reader's role allows, which is what `capabilities` on the dashboard
/// context is for.
enum CreateKind {
  livestream(
    AppStrings.createLivestream,
    AppStrings.createLivestreamBody,
    'canCreateLivestream',
  ),
  video(AppStrings.createVideo, AppStrings.createVideoBody, 'canCreateMedia'),
  audio(AppStrings.createAudio, AppStrings.createAudioBody, 'canCreateMedia'),
  event(AppStrings.createEvent, AppStrings.createEventBody, 'canCreateMedia'),
  blog(AppStrings.createBlog, AppStrings.createBlogBody, 'canCreateMedia');

  const CreateKind(this.title, this.body, this.capability);

  final String title;
  final String body;

  /// The capability that has to be true for this row to appear.
  final String capability;
}

/// "What are you sharing" — the + Create sheet.
class CreateSheet extends StatelessWidget {
  const CreateSheet({
    super.key,
    required this.kinds,
    required this.onPick,
    this.usage,
  });

  final List<CreateKind> kinds;
  final ValueChanged<CreateKind> onPick;

  /// What is left of the plan's upload allowance.
  ///
  /// `POST /v1/media` refuses over the limit — *"Monthly upload limit reached
  /// (5 uploads on current plan)"* — but only after a file has been picked
  /// and uploaded. Saying it here costs one read and saves that.
  final PlanUsage? usage;

  static Future<CreateKind?> show(
    BuildContext context, {
    required List<CreateKind> kinds,
    PlanUsage? usage,
  }) => showModalBottomSheet<CreateKind>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => CreateSheet(
      kinds: kinds,
      usage: usage,
      onPick: (kind) => Navigator.pop(sheetContext, kind),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final quota = usage;
    return _SheetFrame(
      title: AppStrings.createSheetTitle,
      children: [
        if (quota != null && quota.hasUploadLimit) ...[
          Padding(
            padding: EdgeInsets.only(bottom: 12.s),
            child: Text(
              quota.uploadsExhausted
                  ? AppStrings.uploadsExhaustedBody(quota.windowDays)
                  : AppStrings.uploadsUsed(
                      quota.uploadsUsed,
                      quota.uploadLimit!,
                      quota.windowDays,
                    ),
              style: AppStyles.label(
                12,
                color: quota.uploadsExhausted
                    ? AppColors.statusClosed
                    : AppColors.neutral500,
                lineHeight: 17 / 12,
              ),
            ),
          ),
        ],
        for (final kind in kinds)
          Padding(
            padding: EdgeInsets.only(bottom: 10.s),
            child: GestureDetector(
              key: ValueKey('create-${kind.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(kind),
              child: Container(
                padding: EdgeInsets.all(14.s),
                decoration: BoxDecoration(
                  color: AppColors.fieldBg,
                  borderRadius: BorderRadius.circular(10.s),
                ),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: switch (kind) {
                        CreateKind.livestream => HugeIcons.strokeRoundedRadio,
                        CreateKind.video => HugeIcons.strokeRoundedPlayCircle,
                        CreateKind.audio => HugeIcons.strokeRoundedHeadphones,
                        CreateKind.event => HugeIcons.strokeRoundedCalendar03,
                        CreateKind.blog => HugeIcons.strokeRoundedBookOpen01,
                      },
                      color: AppColors.textPrimary,
                      size: 20.s,
                    ),
                    SizedBox(width: 12.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                kind.title,
                                style: AppStyles.label(
                                  14,
                                  weight: AppStyles.bold,
                                ),
                              ),
                              // Live is the only one that happens now rather
                              // than being filed for later.
                              if (kind == CreateKind.livestream) ...[
                                SizedBox(width: 6.s),
                                Container(
                                  width: 5.s,
                                  height: 5.s,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.destructive,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 3.s),
                          Text(
                            kind.body,
                            style: AppStyles.label(
                              12,
                              color: AppColors.neutral400,
                              lineHeight: 16 / 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.s),
                    Icon(
                      AppIcons.chevronRight,
                      size: 16.s,
                      color: AppColors.neutral400,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Which studio the switcher should show as the open one.
///
/// The dashboard context is the answer when there is one. There is not
/// always: `dashboard/context` refuses a `streamer` with **403**, and that
/// reader still belongs to the studio and still needs the way out of it. So
/// the membership row stands in rather than the pill going dead.
DashboardContext? openStudio(
  DashboardContext? context,
  List<StudioMembership> studios, {
  String? creatorId,
}) {
  if (context != null) return context;
  final id = creatorId ?? LocalStorage.creatorId;
  if (id == null) return null;
  for (final studio in studios) {
    if (studio.creatorId == id) return DashboardContext.fromMembership(studio);
  }
  return null;
}

/// What came of the studios sheet: a studio to switch to, or one of the two
/// other rows.
class StudiosOutcome {
  const StudiosOutcome.settings() : switchTo = null, leave = false;
  const StudiosOutcome.backToWatching() : switchTo = null, leave = true;
  const StudiosOutcome.switchTo(String this.switchTo) : leave = false;

  /// The creator id to open instead.
  final String? switchTo;
  final bool leave;
}

/// "Your studios" — which studio the reader is in, and the way back out.
///
/// Every studio the reader can work in is listed for real since 2026-10-26:
/// `GET /v1/creator/me/memberships` answers both the one they own and the
/// organisations they were added to. Before that there was no route at all
/// and the sheet carried a single "Switch studio" row that reported it was
/// not implemented.
///
/// Owned studios come first, so the sheet opens on the one the reader most
/// likely means; the current studio is ticked rather than tappable.
class StudiosSheet extends StatelessWidget {
  const StudiosSheet({
    super.key,
    required this.current,
    required this.onPick,
    this.studios = const [],
  });

  final DashboardContext current;
  final List<StudioMembership> studios;
  final ValueChanged<StudiosOutcome> onPick;

  static Future<StudiosOutcome?> show(
    BuildContext context, {
    required DashboardContext current,
    List<StudioMembership> studios = const [],
  }) => showModalBottomSheet<StudiosOutcome>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => StudiosSheet(
      current: current,
      studios: studios,
      onPick: (choice) => Navigator.pop(sheetContext, choice),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final studio in studios)
        if (studio.creatorId != current.creatorId) studio,
    ];

    return _SheetFrame(
      title: AppStrings.studiosSheetTitle,
      children: [
        _StudioRow(
          name: current.displayName,
          handle: current.handle,
          role: current.role,
          selected: true,
          onTap: null,
        ),
        for (final studio in others) ...[
          SizedBox(height: 10.s),
          _StudioRow(
            rowKey: ValueKey('studio-${studio.creatorId}'),
            name: studio.displayName,
            handle: studio.handle,
            role: studio.role,
            selected: false,
            onTap: () => onPick(StudiosOutcome.switchTo(studio.creatorId)),
          ),
        ],
        SizedBox(height: 18.s),
        _SheetRow(
          rowKey: const ValueKey('studio-settings'),
          icon: HugeIcons.strokeRoundedSettings02,
          title: AppStrings.studiosSettings,
          note: AppStrings.studiosSettingsNote,
          onTap: () => onPick(const StudiosOutcome.settings()),
        ),
        SizedBox(height: 18.s),
        GestureDetector(
          key: const ValueKey('back-to-watching'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(const StudiosOutcome.backToWatching()),
          child: Container(
            padding: EdgeInsets.all(14.s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.s),
              border: Border.all(color: AppColors.brandPrimary),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back,
                  size: 18.s,
                  color: AppColors.textPrimary,
                ),
                SizedBox(width: 12.s),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.studiosBackToWatching,
                      style: AppStyles.label(14, weight: AppStyles.bold),
                    ),
                    SizedBox(height: 3.s),
                    Text(
                      AppStrings.studiosBackToWatchingNote,
                      style: AppStyles.label(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// One studio in the switcher: the current one ticked, the rest tappable.
class _StudioRow extends StatelessWidget {
  const _StudioRow({
    required this.name,
    required this.handle,
    required this.role,
    required this.selected,
    required this.onTap,
    this.rowKey,
  });

  final String name;
  final String handle;
  final String role;
  final bool selected;
  final VoidCallback? onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    // "Personal" belongs to the studio the reader owns. A ministry they were
    // added to is identified by its handle, because calling someone else's
    // organisation personal is simply wrong.
    final subtitle = [
      if (role == 'owner')
        AppStrings.studiosPersonal
      else if (handle.isNotEmpty)
        '@${handle.replaceFirst('@', '')}',
      if (role.isNotEmpty) _titleCase(role),
    ].join(' · ');

    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.s),
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(10.s),
        ),
        child: Row(
          children: [
            StudioAvatar(size: 34.s),
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
                    style: AppStyles.label(14, weight: AppStyles.bold),
                  ),
                  SizedBox(height: 3.s),
                  Text(
                    subtitle,
                    style: AppStyles.label(
                      12,
                      color: AppColors.neutral400,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 20.s,
                height: 20.s,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandPrimary,
                ),
                child: Icon(Icons.check, size: 12.s, color: AppColors.base1),
              )
            else
              Icon(
                AppIcons.chevronRight,
                size: 16.s,
                color: AppColors.neutral400,
              ),
          ],
        ),
      ),
    );
  }
}

/// An icon, a title and a line under it — the shape the sheet's actions take.
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.note,
    required this.onTap,
  });

  final Key rowKey;
  final List<List<dynamic>> icon;
  final String title;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.s),
        child: Row(
          children: [
            HugeIcon(icon: icon, color: AppColors.textPrimary, size: 18.s),
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
                    note,
                    style: AppStyles.label(
                      12,
                      color: AppColors.neutral400,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              size: 16.s,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}

/// The grabber, caption and close button both sheets share.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 60),
      decoration: BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.s)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36.s,
                  height: 4.s,
                  margin: EdgeInsets.only(top: 10.s, bottom: 14.s),
                  decoration: BoxDecoration(
                    color: AppColors.neutral700,
                    borderRadius: BorderRadius.circular(2.s),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 14.s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppStyles.label(
                        13,
                        weight: AppStyles.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(context),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: AppColors.textPrimary,
                        size: 20.s,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 20.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
