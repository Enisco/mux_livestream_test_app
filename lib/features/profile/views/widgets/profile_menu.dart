import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The menu the You tab is mostly made of.
///
/// Three captioned blocks — studio, the reader's own things, the account —
/// each a stack of rows with an icon, a label and a chevron.

/// A captioned block of rows, ruled off from the next.
class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({
    super.key,
    required this.caption,
    required this.children,
    this.showDivider = true,
  });

  final String caption;
  final List<Widget> children;

  /// Every block in the design carries the rule, including the last.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 20.s),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.neutral800)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: AppStyles.label(
              10,
              weight: AppStyles.bold,
              color: AppColors.neutral400,
              lineHeight: 16 / 10,
            ),
          ),
          SizedBox(height: 10.s),
          // 2px between rows, per the design's menu blocks.
          for (final (i, child) in children.indexed) ...[
            if (i > 0) SizedBox(height: 2.s),
            child,
          ],
        ],
      ),
    );
  }
}

/// One tappable row.
class ProfileMenuItem extends StatelessWidget {
  const ProfileMenuItem({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.note,
    this.tag,
    this.pill,
    this.onTap,
  });

  final String label;

  /// The usual leading glyph. Omitted when [leading] supplies its own widget.
  final List<List<dynamic>>? icon;

  /// Used instead of [icon] where the design puts an avatar in its place.
  final Widget? leading;

  /// Trailing copy in brand colour, as on "Become a creator".
  final String? note;

  /// A quiet label beside the title, as on the studio channel row.
  final String? tag;

  /// A count pill pushed to the right, as on "My events".
  final String? pill;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.s),
        child: Row(
          children: [
            SizedBox(
              width: 20.s,
              height: 20.s,
              child:
                  leading ??
                  HugeIcon(
                    icon: icon!,
                    color: AppColors.textPrimary,
                    size: 20.s,
                  ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.label(13, weight: AppStyles.bold),
                    ),
                  ),
                  if (note != null) ...[
                    SizedBox(width: 8.s),
                    Flexible(
                      child: Text(
                        note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.label(
                          12,
                          color: AppColors.brandPrimary,
                          lineHeight: 16 / 12,
                        ),
                      ),
                    ),
                  ],
                  if (tag != null) ...[SizedBox(width: 8.s), _Tag(label: tag!)],
                ],
              ),
            ),
            if (pill != null) ...[SizedBox(width: 8.s), _Pill(label: pill!)],
            SizedBox(width: 8.s),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.s, vertical: 2.s),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4.s)),
      child: Text(
        label,
        style: AppStyles.label(
          12,
          color: AppColors.neutral400,
          lineHeight: 16 / 12,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 4.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(17.s),
        // The design lights the pill from inside with a wash of brand colour.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.brandPrimary.withValues(alpha: 0.10),
            AppColors.fieldBg,
          ],
        ),
      ),
      child: Text(
        label,
        style: AppStyles.label(
          12,
          weight: AppStyles.bold,
          color: AppColors.yellow600,
          lineHeight: 16 / 12,
        ),
      ),
    );
  }
}
