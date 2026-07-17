import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../core/app_colors.dart';
import '../core/router.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../services/token_storage_service.dart';
import '../services/vertical_feed_preloader.dart';
import '../utils/auth_sheet.dart';
import '../utils/local_storage.dart';
import 'discover_feed_screen.dart';
import 'home_screen.dart';
import 'join_livestream_screen.dart';
import 'start_livestream_screen.dart';
import 'vertical_feed_screen.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Nav indices: 0=Home, 1=Shorts (intercepted), 2=Live, 3=Me
  int _selectedIndex = 0;

  // Maps nav indices {0,2,3} → body slots {0,1,2}
  int get _bodyIndex => _selectedIndex == 0 ? 0 : _selectedIndex - 1;

  @override
  void initState() {
    super.initState();
    // Kick off feed pre-warm; no-op if already started from main().
    unawaited(GetIt.instance<VerticalFeedPreloader>().warmUp());
  }

  void _onNavTap(int index) {
    if (index == 1) {
      // Shorts launches full-screen — never becomes the "selected" tab.
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const VerticalFeedScreen(),
        ),
      );
      return;
    }
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
        body: IndexedStack(
          index: _bodyIndex,
          children: const [_HomeTab(), _LiveTab(), _ProfileTab()],
        ),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textTertiary,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            color: s.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textTertiary,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
        height: 64,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black87,
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: const Duration(milliseconds: 250),
        destinations: const [
          NavigationDestination(
            icon: Icon(IconsaxPlusLinear.home_2),
            selectedIcon: Icon(IconsaxPlusBold.home_2),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(IconsaxPlusLinear.play_circle),
            selectedIcon: Icon(IconsaxPlusBold.play_circle),
            label: 'Shorts',
          ),
          NavigationDestination(
            icon: Icon(IconsaxPlusLinear.video),
            selectedIcon: Icon(IconsaxPlusBold.video),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(IconsaxPlusLinear.profile_circle),
            selectedIcon: Icon(IconsaxPlusBold.profile_circle),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) => const DiscoverFeedScreen();
}

// ── Live Tab ──────────────────────────────────────────────────────────────────

class _LiveTab extends StatefulWidget {
  const _LiveTab();

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
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
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              pinned: true,
              title: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.55),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Live',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Text(
                    'Broadcast live or tune in to an active stream in real time.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _GoLiveCard(
                    isLoggedIn: _isLoggedIn ?? false,
                  ),
                  const SizedBox(height: 16),
                  const _JoinStreamCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoLiveCard extends StatelessWidget {
  final bool isLoggedIn;
  const _GoLiveCard({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!isLoggedIn) {
          showAuthSheet(context, 'go live');
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StartLivestreamScreen()),
        );
      },
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFAA00),
              Color(0xFFCC7700),
              Color(0xFF7A4000),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -28,
              top: -28,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              right: 28,
              bottom: -40,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        IconsaxPlusBold.video,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Go Live',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!isLoggedIn)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                IconsaxPlusLinear.lock,
                                color: Colors.white70,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Sign in',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Start broadcasting to your audience\nin real time via RTMP.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinStreamCard extends StatelessWidget {
  const _JoinStreamCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JoinLivestreamScreen()),
      ),
      child: Container(
        height: 148,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.surface,
          border: Border.all(color: AppColors.surfaceVariant, width: 1.5),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        IconsaxPlusLinear.screenmirroring,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Join a Stream',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Enter a creator ID to watch their live broadcast.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile / Me Tab ──────────────────────────────────────────────────────────

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
          true => _buildProfile(context),
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

  // ── Auth Wall ───────────────────────────────────────────────────────────────

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
                      (Icons.auto_awesome_rounded, 'Personalised recommendations'),
                      (IconsaxPlusBold.video, 'Go live and stream your content'),
                    ].map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(f.$1, color: AppColors.primary, size: 18),
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
                      onPressed: () => context.push(AppRoutes.signIn),
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
                      onPressed: () => context.push(AppRoutes.signUp),
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
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
          // Warm radial glow behind logo
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.1),
                radius: 0.75,
                colors: [
                  const Color(0xFF3A1F00),
                  AppColors.background,
                ],
              ),
            ),
          ),
          // Outer soft ring
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
          // Logo pill
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
          // App name + tagline
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

  // ── Authenticated Profile ───────────────────────────────────────────────────

  Widget _buildProfile(BuildContext ctx) {
    final name = LocalStorage.cachedFullName ?? LocalStorage.cachedFirstName ?? 'User';
    final handle = LocalStorage.cachedHandle;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      key: const ValueKey('profile'),
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Profile header with gradient background
          SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.surface, AppColors.background],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (handle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  handle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Menu sections
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MenuSection(
                  title: 'Content',
                  items: [
                    _MenuItem(
                      icon: IconsaxPlusLinear.gallery,
                      label: 'My Gallery',
                      subtitle: 'Videos stored on your device',
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      ),
                    ),
                    _MenuItem(
                      icon: IconsaxPlusLinear.video,
                      label: 'Go Live',
                      subtitle: 'Start broadcasting via RTMP',
                      accent: true,
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => const StartLivestreamScreen(),
                        ),
                      ),
                    ),
                    _MenuItem(
                      icon: IconsaxPlusLinear.screenmirroring,
                      label: 'Join a Stream',
                      subtitle: 'Watch a live creator',
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => const JoinLivestreamScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MenuSection(
                  title: 'Account',
                  items: [
                    _MenuItem(
                      icon: IconsaxPlusLinear.logout,
                      label: 'Sign Out',
                      isDestructive: true,
                      onTap: () =>
                          ctx.read<AuthBloc>().add(AuthLogoutRequested()),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu section / item ───────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.9,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  const Divider(
                    height: 1,
                    indent: 58,
                    color: AppColors.surfaceVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool accent;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.accent = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.error
        : accent
            ? AppColors.primary
            : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDestructive
                    ? AppColors.error.withValues(alpha: 0.1)
                    : accent
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (!isDestructive)
              const Icon(
                IconsaxPlusLinear.arrow_right_3,
                color: AppColors.textTertiary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

