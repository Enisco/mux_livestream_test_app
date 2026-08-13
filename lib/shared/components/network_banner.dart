import 'package:flutter/material.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/shared/services/connectivity_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:sizing/sizing.dart';

/// Pushes the app down by an offline bar instead of overlaying it.
///
/// The tree shape is constant — always `Column > [bar, Expanded(child)]` with
/// the bar animating between zero and full height. Conditionally wrapping
/// `child` instead would remount the Navigator and lose all app state.
class GTubeNetworkBanner extends StatelessWidget {
  const GTubeNetworkBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: getIt<ConnectivityService>().isOnline,
      builder: (context, online, _) {
        final media = MediaQuery.of(context);
        return Column(
          // Without stretch the app loses its tight width constraint.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OfflineBar(visible: !online, topInset: media.padding.top),
            Expanded(
              child: MediaQuery(
                // The bar owns the status-bar strip now; don't inset twice.
                data: online
                    ? media
                    : media.copyWith(padding: media.padding.copyWith(top: 0)),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar({required this.visible, required this.topInset});

  final bool visible;

  /// In the bar's own padding, not a SafeArea, which would reserve the strip
  /// even while hidden.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: visible
          ? Container(
              width: double.infinity,
              color: AppColors.neutral800,
              padding: EdgeInsets.only(
                top: topInset + 6.s,
                bottom: 8.s,
                left: 16.s,
                right: 16.s,
              ),
              child: Text(
                AppStrings.offline,
                textAlign: TextAlign.center,
                style: AppStyles.label(
                  12,
                  color: AppColors.neutral200,
                  weight: AppStyles.medium,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
