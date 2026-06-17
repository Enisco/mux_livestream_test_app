import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../core/app_styles.dart';

class PermissionRequestView extends StatelessWidget {
  final bool isPermanentlyDenied;
  final VoidCallback onPrimaryAction;

  const PermissionRequestView({
    super.key,
    required this.isPermanentlyDenied,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBox(
              icon: isPermanentlyDenied
                  ? Icons.lock_rounded
                  : Icons.photo_library_rounded,
            ),
            const SizedBox(height: 24.0),
            Text(
              AppStrings.permissionTitle,
              style: AppStyles.emptyTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              isPermanentlyDenied
                  ? AppStrings.permissionDeniedBody
                  : AppStrings.permissionBody,
              style: AppStyles.emptySubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),
            FilledButton.icon(
              onPressed: onPrimaryAction,
              icon: Icon(
                isPermanentlyDenied
                    ? Icons.settings_rounded
                    : Icons.lock_open_rounded,
              ),
              label: Text(
                isPermanentlyDenied
                    ? AppStrings.openSettings
                    : AppStrings.grantAccess,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100.0,
      height: 100.0,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Icon(icon, size: 48.0, color: AppColors.primary),
    );
  }
}
