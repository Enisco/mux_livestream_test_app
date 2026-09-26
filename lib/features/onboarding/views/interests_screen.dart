import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/onboarding/views/widgets/category_glyphs.dart';
import 'package:test_app/features/onboarding/views/widgets/interest_chip.dart';
import 'package:test_app/features/onboarding/views/widgets/onboarding_progress_bar.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  /// Selection is by slug, which is also exactly what gets sent — there is no
  /// label-to-slug table left to disagree with the backend.
  final _selected = <String>{};

  List<ContentCategory> _categories = const [];
  bool _loading = true;

  static const _progress = 236 / 350;

  List<String> get _slugs => _selected.toList();

  @override
  void initState() {
    super.initState();
    unawaited(_loadCategories());
  }

  /// The chips are the live taxonomy, ordered the way the API orders it.
  ///
  /// A failed lookup leaves the list empty rather than falling back to a
  /// hardcoded copy: a stale copy is how the labels and the slugs drifted
  /// apart in the first place, and this step is skippable.
  Future<void> _loadCategories() async {
    try {
      final rows = await getIt<CreatorRepo>().fetchCategories();
      final live = rows.where((c) => c.isActive && c.slug.isNotEmpty).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (mounted) setState(() => _categories = live);
    } catch (e) {
      logger.w('Could not load interest categories', error: e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continue() async {
    final slugs = _slugs;
    if (slugs.isNotEmpty) {
      try {
        await getIt<OnboardingRepo>().updateViewerPreferences(
          categorySlugs: slugs,
        );
      } catch (e) {
        logger.w('Could not save interests', error: e);
      }
    }
    // Carried on so the discovery step can resend them alongside its own
    // fields; the endpoint replaces rather than merges.
    if (mounted) context.go(AppRouter.discoverySource, extra: slugs);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundColor: AppColors.brandSecondary,
      backgroundAsset: AppAssets.worshipBg,
      topBar: _TopBar(progress: _progress, onSkip: _continue),
      // The chip grid scrolls itself; the heading stays put.
      scrollable: false,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.interestsHint,
            textAlign: TextAlign.center,
            style: AppStyles.caption(
              12,
              weight: AppStyles.medium,
              lineHeight: 16 / 12,
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: AppStrings.continueLabel,
            height: 54,
            onPressed: _continue,
          ),
        ],
      ),
      child: _content(),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: GTubeLogoMark.compact()),
        const SizedBox(height: 8),
        Text(
          AppStrings.interestsTitle,
          textAlign: TextAlign.center,
          style: AppStyles.heading(20, letterSpacing: -0.8),
        ),
        const SizedBox(height: 8),
        Text(
          AppStrings.interestsSubtitle,
          textAlign: TextAlign.center,
          style: AppStyles.body(13, color: AppColors.neutral400),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: _loading && _categories.isEmpty
              ? const Center(child: CupertinoActivityIndicator())
              : SingleChildScrollView(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 17,
                    children: [
                      for (final category in _categories)
                        InterestChip(
                          label: category.name,
                          icon: CategoryGlyphs.forSlug(category.slug),
                          selected: _selected.contains(category.slug),
                          onTap: () => setState(() {
                            if (!_selected.remove(category.slug)) {
                              _selected.add(category.slug);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.progress, required this.onSkip});

  final double progress;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OnboardingProgressBar(progress: progress),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GTubeBackButton(onTap: () => context.pop()),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSkip,
                child: Text(
                  AppStrings.skip,
                  style: AppStyles.caption(
                    12,
                    color: AppColors.neutral50,
                    weight: AppStyles.medium,
                    lineHeight: 16 / 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
