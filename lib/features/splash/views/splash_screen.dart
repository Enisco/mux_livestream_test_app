import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sizing/sizing.dart';
import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final tokenStorage = getIt<TokenStorageService>();
    if (!await tokenStorage.hasSession) {
      if (mounted) context.go(AppRouter.welcome);
      return;
    }

    final refreshed = await getIt<AuthRepo>().tryRefreshSession();
    if (!mounted) return;

    if (!refreshed) {
      if (mounted) context.go(AppRouter.welcome);
      return;
    }

    final creatorId = LocalStorage.creatorId;
    if (creatorId != null) {
      try {
        await getIt<CreatorRepo>().provisionLivestream(creatorId);
      } catch (_) {}
    }

    if (mounted) context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppStyles.splashBackground),
          child: SafeArea(
            // Full width, or the Column shrink-wraps and the gradient paints
            // only a strip.
            child: SizedBox(
              width: 1.w,
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GTubeLogoMark(),
                      const SizedBox(height: 13),
                      Text(
                        AppStrings.brandName,
                        style: AppStyles.heading(
                          20,
                          lineHeight: 32 / 20,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppStrings.splashTagline,
                        textAlign: TextAlign.center,
                        style: AppStyles.body(13, lineHeight: 16 / 13),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
