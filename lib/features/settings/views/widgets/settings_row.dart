import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// A captioned block of settings rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.caption,
    required this.children,
  });

  final String caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: AppStyles.label(
            12,
            weight: AppStyles.bold,
            color: AppColors.neutral500,
            lineHeight: 16 / 12,
          ),
        ),
        for (final child in children) ...[SizedBox(height: 32.s), child],
      ],
    );
  }
}

/// One setting: what it is, what it is currently, and the way to change it.
///
/// The trailing control says how the row behaves — amber words for something
/// edited in place, a chevron for somewhere else to go.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.action,
    this.showChevron = false,
    this.subtitleVerified = false,
    this.destructive = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// The usual 24pt leading glyph.
  final List<List<dynamic>>? icon;

  /// Used instead of [icon] where the design puts the reader's avatar.
  final Widget? leading;

  /// "Edit", "Change" — amber, and the whole row taps to it.
  final String? action;

  final bool showChevron;

  /// A green tick after the subtitle, as on a confirmed email.
  final bool subtitleVerified;

  /// Deactivate account: the title turns red and carries no subtitle.
  final bool destructive;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? AppColors.destructive : AppColors.neutral300;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(bottom: 25.s),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutral800)),
        ),
        child: Row(
          children: [
            if (leading != null)
              leading!
            else if (icon case final glyph?)
              HugeIcon(
                icon: glyph,
                color: destructive
                    ? AppColors.destructive
                    : AppColors.neutral300,
                size: 24.s,
              ),
            SizedBox(width: 10.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(
                      13,
                      weight: AppStyles.bold,
                      color: tint,
                    ),
                  ),
                  if (subtitle case final sub? when sub.isNotEmpty) ...[
                    SizedBox(height: 5.s),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.label(
                              12,
                              weight: AppStyles.bold,
                              color: AppColors.neutral500,
                              lineHeight: 16 / 12,
                            ),
                          ),
                        ),
                        if (subtitleVerified) ...[
                          SizedBox(width: 3.s),
                          DesignIcon(
                            AppAssets.iconFeedVerified,
                            width: 14.s,
                            height: 14.s,
                            color: AppColors.green500,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.s),
            if (action case final label?)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 4.s),
                child: Text(
                  label,
                  style: AppStyles.label(
                    12,
                    weight: AppStyles.bold,
                    color: AppColors.yellow600,
                    lineHeight: 16 / 12,
                  ),
                ),
              )
            else if (showChevron)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.s),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20.s,
                  color: destructive
                      ? AppColors.destructive
                      : AppColors.neutral500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The reader's initials in a softly lit disc — the design's stand-in for a
/// photo, and what shows when there is no photo to draw.
class SettingsAvatar extends StatelessWidget {
  const SettingsAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p[0].toUpperCase()).join();

    return Container(
      width: size.s,
      height: size.s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.fieldBg,
        border: Border.all(color: AppColors.fieldBg, width: 1.5.s),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.34),
            blurRadius: 27.2.s,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: AppStyles.label(
            18,
            family: AppStyles.featureFont,
            weight: AppStyles.semiBold,
            color: AppColors.brandPrimary,
            lineHeight: 1.45,
          ),
        ),
      ),
    );
  }
}
