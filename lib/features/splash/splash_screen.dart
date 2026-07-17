import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/app_strings.dart';
import '../../core/locator.dart';
import '../../core/router.dart';
import '../../features/auth/repo/auth_repo.dart';
import '../../features/creator/repo/creator_repo.dart';
import '../../services/token_storage_service.dart';
import '../../utils/local_storage.dart';

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
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final tokenStorage = getIt<TokenStorageService>();
    if (await tokenStorage.hasSession) {
      // Refresh tokens — updates stored tokens and user cache.
      final authRepo = getIt<AuthRepo>();
      final refreshed = await authRepo.tryRefreshSession();
      if (!mounted) return;

      // Re-provision livestream credentials on every app launch (idempotent).
      if (refreshed) {
        final creatorId = LocalStorage.creatorId;
        if (creatorId != null) {
          try {
            await getIt<CreatorRepo>().provisionLivestream(creatorId);
          } catch (_) {
            // Non-fatal.
          }
        }
      }
    }

    // Always land on the public shell — auth state is handled inside each tab.
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              AppStrings.appTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
