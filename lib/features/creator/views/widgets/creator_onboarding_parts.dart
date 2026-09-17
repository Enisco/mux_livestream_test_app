import 'package:flutter/material.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The parts the creator onboarding screens are made of.
///
/// Every screen in the section is the same skeleton: a back arrow with the
/// title beside it, one grey line of explanation under it, then the screen's
/// own content over a footer. The older onboarding centred a logo and carried
/// a progress bar and a Skip; this flow does neither, so these live here
/// rather than reusing the onboarding widgets.

/// Back arrow, title, and the line that says what the screen is for.
class CreatorFlowHeader extends StatelessWidget {
  const CreatorFlowHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? subtitle;

  /// The logo mark sits here on the two setup forms.
  final Widget? trailing;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GTubeBackButton(onTap: onBack, size: 20, box: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(
                  18,
                  weight: AppStyles.bold,
                  lineHeight: 24 / 18,
                ),
              ),
            ),
            if (trailing case final widget?) ...[
              const SizedBox(width: 12),
              widget,
            ],
          ],
        ),
        if (subtitle case final line?) ...[
          const SizedBox(height: 6),
          Text(
            line,
            style: AppStyles.body(
              12,
              color: AppColors.neutral400,
              lineHeight: 16 / 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// One of the two answers to "Who is this channel for?".
class CreatorChoiceCard extends StatelessWidget {
  const CreatorChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neutral800),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.fieldBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DesignIcon(icon, width: 18, height: 18),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppStyles.label(
                14,
                weight: AppStyles.bold,
                lineHeight: 20 / 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: AppStyles.body(
                13,
                color: AppColors.neutral300,
                lineHeight: 20 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How far through the four profile-polish steps the reader is.
///
/// The steps can all be skipped, so this is the only thing telling them the
/// flow is finite.
class CreatorStepDots extends StatelessWidget {
  const CreatorStepDots({super.key, required this.index, this.count = 4});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: i == index ? AppColors.brandPrimary : AppColors.neutral700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}

/// The "I'll do this later" line over every polish step's button.
class CreatorSkipLine extends StatelessWidget {
  const CreatorSkipLine({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppStyles.body(
            13,
            color: AppColors.neutral300,
            lineHeight: 18 / 13,
          ),
        ),
      ),
    );
  }
}
