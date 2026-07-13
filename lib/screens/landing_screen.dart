import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../core/app_colors.dart';
import '../core/app_strings.dart';
import '../core/app_styles.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../services/vertical_feed_preloader.dart';
import '../utils/local_storage.dart';
import 'discover_feed_screen.dart';
import 'home_screen.dart';
import 'vertical_feed_screen.dart';
import 'join_livestream_screen.dart';
import 'start_livestream_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-fetch feed data and silently open players for the first 3 videos so
    // the feed plays instantly when the user taps "Short Videos".
    GetIt.instance<VerticalFeedPreloader>().warmUp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppColors.background,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Logout',
                onPressed: () =>
                    context.read<AuthBloc>().add(AuthLogoutRequested()),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(AppStrings.appTitle, style: AppStyles.appBarTitle),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.surface, AppColors.background],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (LocalStorage.cachedFirstName case final name?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Hello, $name!',
                        style: AppStyles.landingCardTitle,
                      ),
                    ),
                  Text(AppStrings.landingSubtitle, style: AppStyles.fileCount),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _FeatureCard(
                  icon: Icons.explore_rounded,
                  title: AppStrings.discover,
                  description: AppStrings.featureDiscoverDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DiscoverFeedScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.video_collection_rounded,
                  title: AppStrings.shortVideos,
                  description: AppStrings.featureShortVideosDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VerticalFeedScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.video_library_rounded,
                  title: AppStrings.featureGallery,
                  description: AppStrings.featureGalleryDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.videocam_rounded,
                  title: AppStrings.goLive,
                  description: AppStrings.featureStartLiveDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StartLivestreamScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FeatureCard(
                  icon: Icons.cast_rounded,
                  title: AppStrings.joinStream,
                  description: AppStrings.featureJoinLiveDesc,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JoinLivestreamScreen(),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppStyles.landingCardTitle),
                    const SizedBox(height: 3),
                    Text(description, style: AppStyles.landingCardDesc),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
