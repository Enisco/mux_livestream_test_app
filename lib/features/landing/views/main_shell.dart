import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:sizing/sizing.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/explore/views/explore_screen.dart';
import 'package:test_app/features/home/views/home_feed_screen.dart';
import 'package:test_app/features/home/views/widgets/home_feed_header.dart';
import 'package:test_app/features/landing/views/widgets/gtube_nav_bar.dart';
import 'package:test_app/features/profile/views/profile_screen.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/shared/services/vertical_feed_preloader.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  /// Explore used to be pushed as a route rather than held as a tab, so the
  /// body index had to skip over it. It is a tab now and the two line up.
  int get _bodyIndex => _selectedIndex;

  @override
  void initState() {
    super.initState();
    unawaited(GetIt.instance<VerticalFeedPreloader>().warmUp());
  }

  void _onNavTap(int index) {
    if (index != _selectedIndex) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (_, state) {
        if (state is AuthSuccess) {
          GetIt.instance<VerticalFeedPreloader>().reset();
        }
        if (state is AuthLoggedOut) {
          GetIt.instance<VerticalFeedPreloader>().reset();
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: IndexedStack(
          index: _bodyIndex,
          children: const [
            _HomeTab(),
            _ExploreTab(),
            _FollowingTab(),
            _ProfileTab(),
          ],
        ),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10.s),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [GTubeNavBar(index: _selectedIndex, onChanged: _onNavTap)],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) => const HomeFeedScreen();
}

class _ExploreTab extends StatelessWidget {
  const _ExploreTab();

  @override
  Widget build(BuildContext context) => const ExploreScreen();
}

class _FollowingTab extends StatelessWidget {
  const _FollowingTab();

  @override
  Widget build(BuildContext context) =>
      const HomeFeedScreen(initialTab: HomeTab.following);
}
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final has = await GetIt.instance<TokenStorageService>().hasSession;
    if (mounted) setState(() => _isLoggedIn = has);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (_, state) {
        if (state is AuthSuccess) setState(() => _isLoggedIn = true);
        if (state is AuthLoggedOut) setState(() => _isLoggedIn = false);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: switch (_isLoggedIn) {
          null => _buildLoading(),
          true => const ProfileScreen(),
          false => _buildAuthWall(context),
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      key: ValueKey('loading'),
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildAuthWall(BuildContext context) {
    return Scaffold(
      key: const ValueKey('auth-wall'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Watch. Follow. Create.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sign in to follow your favourite creators,\nsave content, and broadcast live.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...[
                      (IconsaxPlusBold.heart, 'Follow creators you love'),
                      (IconsaxPlusBold.save_2, 'Save videos to your library'),
                      (
                        Icons.auto_awesome_rounded,
                        'Personalised recommendations',
                      ),
                      (
                        IconsaxPlusBold.video,
                        'Go live and stream your content',
                      ),
                    ].map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                f.$1,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              f.$2,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => context.push(AppRouter.signIn),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.push(AppRouter.welcome),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(
                          color: AppColors.surfaceVariant,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.1),
                radius: 0.75,
                colors: [const Color(0xFF3A1F00), AppColors.background],
              ),
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              IconsaxPlusBold.play_circle,
              color: AppColors.primary,
              size: 46,
            ),
          ),
          Positioned(
            bottom: 32,
            child: Column(
              children: [
                const Text(
                  'GTube',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Gospel Media Platform',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
