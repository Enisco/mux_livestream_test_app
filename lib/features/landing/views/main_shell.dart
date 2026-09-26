import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';
import 'package:test_app/features/auth/bloc/auth_bloc.dart';
import 'package:test_app/features/explore/views/explore_screen.dart';
import 'package:test_app/features/home/views/home_feed_screen.dart';
import 'package:test_app/features/home/views/widgets/home_feed_header.dart';
import 'package:test_app/features/landing/views/widgets/gtube_nav_bar.dart';
import 'package:test_app/features/landing/views/widgets/profile_auth_wall.dart';
import 'package:test_app/features/profile/views/profile_screen.dart';
import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/shared/services/token_storage_service.dart';
import 'package:test_app/shared/services/volume_key_unmuter.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  /// Feed video plays muted, so the volume keys used to move the system
  /// stream and leave it just as silent. Turning the volume up now unmutes
  /// whatever is playing.
  late final VolumeKeyUnmuter _volumeKeys = VolumeKeyUnmuter(
    playback: GetIt.instance<PlaybackController>(),
  )..start();

  @override
  void dispose() {
    unawaited(_volumeKeys.dispose());
    super.dispose();
  }

  /// Explore used to be pushed as a route rather than held as a tab, so the
  /// body index had to skip over it. It is a tab now and the two line up.
  int get _bodyIndex => _selectedIndex;

  void _onNavTap(int index) {
    if (index != _selectedIndex) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (_, state) {
        if (state is AuthLoggedOut) setState(() => _selectedIndex = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.base1,
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
          null => const ProfileTabLoading(),
          true => const ProfileScreen(),
          false => const ProfileAuthWall(),
        },
      ),
    );
  }
}
