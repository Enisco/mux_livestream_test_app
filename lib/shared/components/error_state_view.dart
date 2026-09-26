import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/connectivity_service.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// A load failure, in the same shape the app uses for empty states — tinted
/// disc, headline, a line of explanation, then the action.
///
/// It distinguishes "you're offline" from "our side broke", because the two
/// need different things from the reader: one is theirs to fix, the other is
/// only worth retrying.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.onRetry,
    this.title,
    this.body,
    this.retryLabel,
    this.onBack,
    this.showBack,
  });

  final VoidCallback onRetry;

  /// Overrides for screens that can say something more specific.
  final String? title;
  final String? body;
  final String? retryLabel;

  /// What leaving means here. Defaults to popping the route.
  final VoidCallback? onBack;

  /// Whether to offer a way out at all.
  ///
  /// Left null this answers itself: a pushed route can be left, a tab body
  /// cannot (and has the nav bar anyway). Screens that replace their whole
  /// body with this — a creator's page, a content detail — used to keep their
  /// back arrow only in the success branch, so a page whose data failed to
  /// load left the reader with a Retry button and nothing else. Retry does
  /// not help when the content is simply gone, and force-quitting the app was
  /// the only way out.
  ///
  /// Deciding it here rather than per screen means a screen added later
  /// cannot reintroduce the trap by forgetting.
  final bool? showBack;

  bool get _offline {
    if (!GetIt.instance.isRegistered<ConnectivityService>()) return false;
    return GetIt.instance<ConnectivityService>().isOffline;
  }

  @override
  Widget build(BuildContext context) {
    final offline = _offline;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32.s, vertical: 32.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56.s,
              height: 56.s,
              decoration: const BoxDecoration(
                color: Color(0x33FFA500),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: DesignIcon(
                  offline ? AppAssets.iconEmptyLiveOff : AppAssets.iconAlert,
                  width: 24.s,
                  height: 24.s,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            SizedBox(height: 16.s),
            Text(
              title ??
                  (offline
                      ? AppStrings.offlineTitle
                      : AppStrings.feedErrorTitle),
              textAlign: TextAlign.center,
              style: AppStyles.heading(18, lineHeight: 24 / 18),
            ),
            SizedBox(height: 8.s),
            Text(
              body ??
                  (offline ? AppStrings.offlineBody : AppStrings.feedErrorBody),
              textAlign: TextAlign.center,
              style: AppStyles.body(
                13,
                color: AppColors.neutral400,
                lineHeight: 20 / 13,
              ),
            ),
            SizedBox(height: 24.s),
            SizedBox(
              width: 200.s,
              child: PrimaryButton(
                label: retryLabel ?? AppStrings.feedRetry,
                height: 48,
                onPressed: onRetry,
              ),
            ),
            if (showBack ?? Navigator.of(context).canPop()) ...[
              SizedBox(height: 12.s),
              SizedBox(
                width: 200.s,
                child: TextButton(
                  key: const ValueKey('error-go-back'),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    minimumSize: Size(200.s, 48.s),
                    foregroundColor: AppColors.textPrimary,
                  ),
                  child: Text(
                    AppStrings.goBack,
                    style: AppStyles.button(
                      15,
                      color: AppColors.textPrimary,
                      weight: AppStyles.semiBold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
