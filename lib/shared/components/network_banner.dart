import 'package:flutter/material.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/shared/services/connectivity_service.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:sizing/sizing.dart';

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OfflineBar(visible: !online, topInset: media.padding.top),
            Expanded(
              child: MediaQuery(
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
