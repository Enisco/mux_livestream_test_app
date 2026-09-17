import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The pieces the Studio tab is assembled from.

/// The studio the reader is currently in, and the way to switch.
class StudioPill extends StatelessWidget {
  const StudioPill({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(6.s, 6.s, 12.s, 6.s),
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(999.s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioAvatar(size: 26.s),
            SizedBox(width: 8.s),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 150.s),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(14, weight: AppStyles.bold),
              ),
            ),
            SizedBox(width: 4.s),
            Icon(AppIcons.chevronDown, size: 14.s, color: AppColors.neutral300),
          ],
        ),
      ),
    );
  }
}

/// A placeholder ring; creator avatars are not resolved from `avatarKey`
/// anywhere in the app yet.
class StudioAvatar extends StatelessWidget {
  const StudioAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.buttonSecondaryActive,
      border: Border.all(color: AppColors.purple400, width: size / 20),
    ),
    child: Icon(Icons.person, size: size * 0.6, color: AppColors.neutral400),
  );
}

/// One of the three figures on the TODAY card.
class StudioStatCard extends StatelessWidget {
  const StudioStatCard({
    super.key,
    required this.label,
    required this.value,
    this.change,
    this.changeIsPositive = true,
  });

  final String label;

  /// Already formatted, or [AppStrings.studioNoFigure] when there is nothing
  /// to show — a new studio shows a dash rather than a zero.
  final String value;

  /// "+18%", "+9", "4 Gifts".
  final String? change;
  final bool changeIsPositive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(10.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.label(
              12,
              color: AppColors.neutral400,
              lineHeight: 16 / 12,
            ),
          ),
          SizedBox(height: 8.s),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.heading(20, letterSpacing: -0.6),
          ),
          SizedBox(height: 4.s),
          Text(
            change ?? ' ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.label(
              11,
              color: change == null
                  ? Colors.transparent
                  : changeIsPositive
                  ? AppColors.statusDone
                  : AppColors.neutral500,
              lineHeight: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// The numbered "here's how to start" card, shown until the studio has found
/// its feet.
class GettingStartedCard extends StatelessWidget {
  const GettingStartedCard({
    super.key,
    required this.steps,
    required this.onStep,
  });

  final List<GettingStartedStep> steps;
  final ValueChanged<GettingStartedStep> onStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12.s),
      ),
      child: Column(
        children: [
          for (final (i, step) in steps.indexed)
            _StepRow(
              step: step,
              ordinal: i + 1,
              last: i == steps.length - 1,
              onTap: () => onStep(step),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.ordinal,
    required this.last,
    required this.onTap,
  });

  final GettingStartedStep step;
  final int ordinal;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = AppStrings.studioStepTitles[step.key] ?? step.key;
    final body = AppStrings.studioStepBodies[step.key];

    return GestureDetector(
      key: ValueKey('step-${step.key}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.s),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.neutral900)),
        ),
        child: Row(
          children: [
            _Bullet(complete: step.complete, ordinal: ordinal),
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
                  if (body != null) ...[
                    SizedBox(height: 3.s),
                    Text(
                      body,
                      style: AppStyles.label(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 10.s),
            Icon(
              AppIcons.chevronRight,
              size: 16.s,
              color: AppColors.brandPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tick once done, the step's number until then.
class _Bullet extends StatelessWidget {
  const _Bullet({required this.complete, required this.ordinal});

  final bool complete;
  final int ordinal;

  @override
  Widget build(BuildContext context) => Container(
    width: 24.s,
    height: 24.s,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: complete ? AppColors.brandPrimary : AppColors.neutral800,
    ),
    child: complete
        ? Icon(Icons.check, size: 14.s, color: AppColors.base1)
        : Text(
            '$ordinal',
            style: AppStyles.label(
              12,
              weight: AppStyles.bold,
              color: AppColors.neutral300,
              lineHeight: 16 / 12,
            ),
          ),
  );
}

/// One row of NEEDS YOU: what is waiting, and how much of it.
class AttentionRow extends StatelessWidget {
  const AttentionRow({
    super.key,
    required this.item,
    required this.last,
    required this.onTap,
  });

  final AttentionItem item;
  final bool last;
  final VoidCallback onTap;

  /// Prayer requests read as "12 New"; anything being reviewed reads as
  /// "2 waiting".
  bool get _isNew => item.key.contains('prayer');

  @override
  Widget build(BuildContext context) {
    final title = item.label.isNotEmpty
        ? item.label
        : AppStrings.studioAttentionTitles[item.key] ?? item.key;

    return GestureDetector(
      key: ValueKey('attention-${item.key}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.s),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.neutral900)),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: _isNew
                  ? HugeIcons.strokeRoundedHandPrayer
                  : HugeIcons.strokeRoundedFavourite,
              color: AppColors.textPrimary,
              size: 18.s,
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(14, weight: AppStyles.bold),
              ),
            ),
            SizedBox(width: 10.s),
            if (_isNew)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 4.s),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999.s),
                ),
                child: Text(
                  AppStrings.studioAttentionNew(item.count),
                  style: AppStyles.label(
                    11,
                    weight: AppStyles.bold,
                    color: AppColors.brandPrimary,
                    lineHeight: 14 / 11,
                  ),
                ),
              )
            else
              Text(
                AppStrings.studioAttentionWaiting(item.count),
                style: AppStyles.label(
                  12,
                  color: AppColors.neutral400,
                  lineHeight: 16 / 12,
                ),
              ),
            SizedBox(width: 6.s),
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

/// The caption over a block of the dashboard.
class StudioSectionLabel extends StatelessWidget {
  const StudioSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 10.s),
    child: Text(
      text,
      style: AppStyles.label(
        12,
        weight: AppStyles.bold,
        color: AppColors.neutral500,
        letterSpacing: 0.6,
        lineHeight: 16 / 12,
      ),
    ),
  );
}

/// The standing note that some of the studio lives on the web.
class WebStudioNote extends StatelessWidget {
  const WebStudioNote({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(14.s),
    decoration: BoxDecoration(
      color: AppColors.fieldBg,
      borderRadius: BorderRadius.circular(10.s),
    ),
    child: Text(
      AppStrings.studioWebNote,
      style: AppStyles.body(
        12,
        color: AppColors.neutral400,
        lineHeight: 18 / 12,
      ),
    ),
  );
}
