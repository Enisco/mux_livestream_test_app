import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/profile/data/profile_dummy_data.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Who the reader is, and the way in to their notifications.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.name,
    this.handle,
    this.avatarUrl,
    this.hasNotifications = false,
    this.onTap,
    this.onNotifications,
  });

  final String name;

  /// Already carries its leading `@`.
  final String? handle;

  final String? avatarUrl;
  final bool hasNotifications;
  final VoidCallback? onTap;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.s),
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(20.s),
          border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.03)),
        ),
        child: Row(
          children: [
            DetailAvatar(
              name: name,
              avatarUrl: avatarUrl,
              size: 40,
              ringColor: AppColors.brandPrimary,
            ),
            SizedBox(width: 16.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(
                      16,
                      weight: AppStyles.bold,
                      lineHeight: 24 / 16,
                    ),
                  ),
                  SizedBox(height: 1.s),
                  // The handle and the way into account settings share a line;
                  // only the second half is a brand-coloured affordance.
                  Text.rich(
                    TextSpan(
                      children: [
                        if (handle case final h? when h.isNotEmpty)
                          TextSpan(text: '$h · '),
                        const TextSpan(
                          text: AppStrings.profileAccountInfo,
                          style: TextStyle(color: AppColors.brandPrimary),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(
                      12,
                      weight: AppStyles.bold,
                      color: AppColors.neutral400,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.s),
            _BellButton(
              alert: hasNotifications,
              onTap: onNotifications,
            ),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.alert, this.onTap});

  final bool alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40.s,
        height: 40.s,
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20.s),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedNotification03,
              color: AppColors.textPrimary,
              size: 20.s,
            ),
            if (alert)
              Positioned(
                right: 11.s,
                top: 11.s,
                child: Container(
                  width: 8.s,
                  height: 8.s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What the reader left unfinished, with how much of it is left.
class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({super.key, required this.progress, this.onTap});

  final ProfileWatchProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10.s),
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(16.s),
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.02),
          ),
        ),
        child: Row(
          children: [
            _Still(progress: progress),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progress.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.label(13, weight: AppStyles.bold),
                  ),
                  SizedBox(height: 4.s),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DetailAvatar(name: progress.creatorName, size: 14),
                      SizedBox(width: 5.s),
                      Flexible(
                        child: Text(
                          progress.creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyles.body(
                            12,
                            weight: AppStyles.regular,
                            color: AppColors.neutral200,
                            lineHeight: 16 / 12,
                          ),
                        ),
                      ),
                      if (progress.creatorVerified) ...[
                        SizedBox(width: 5.s),
                        DesignIcon(
                          AppAssets.iconFeedVerified,
                          width: 14.s,
                          height: 14.s,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.s),
                  Text(
                    '${progress.remainingLabel} '
                    '${AppStrings.profileRemainingSuffix}',
                    style: AppStyles.body(
                      11,
                      weight: AppStyles.regular,
                      color: AppColors.neutral400,
                    ),
                  ),
                ],
              ),
            ),
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

class _Still extends StatelessWidget {
  const _Still({required this.progress});

  final ProfileWatchProgress progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.s),
      child: SizedBox(
        width: 110.s,
        height: 66.s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (progress.thumbnailAsset case final asset?)
              Image.asset(asset, fit: BoxFit.cover)
            else if (progress.thumbnailUrl case final url?)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.base2),
              )
            else
              const ColoredBox(color: AppColors.base2),
            // Darkened so the play glyph reads over any still.
            const ColoredBox(color: Color(0x45000000)),
            Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPlayCircle,
                color: AppColors.textPrimary,
                size: 20.s,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 2.s,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: AppColors.textPrimary.withValues(alpha: 0.2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.fraction.clamp(0, 1),
                      child: const ColoredBox(color: AppColors.brandPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
