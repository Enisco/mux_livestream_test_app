import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/features/onboarding/views/widgets/interest_chip.dart';
import 'package:test_app/features/onboarding/views/widgets/onboarding_progress_bar.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class Interest {
  const Interest(this.label, {this.icon, this.slugs = const []});

  final String label;

  final Widget Function()? icon;

  /// Category slugs from `/v1/user/categories`. Empty where the design's chip
  /// has no equivalent in the API taxonomy — see docs/OPEN_ISSUES.md.
  final List<String> slugs;
}

Widget _svg(String asset) => SvgPicture.asset(
  asset,
  width: InterestChip.iconSize,
  height: InterestChip.iconSize,
);

final _interests = <Interest>[
  Interest(
    AppStrings.interestPreaching,
    icon: () => _svg(AppAssets.iconCatMicrophone),
    slugs: ['sermons'],
  ),
  Interest(
    AppStrings.interestWorship,
    icon: () => _svg(AppAssets.iconCatDove),
    slugs: ['worship'],
  ),
  Interest(
    AppStrings.interestBibleStudy,
    icon: () => _svg(AppAssets.iconCatBible),
    slugs: ['bible-study'],
  ),
  Interest(
    AppStrings.interestYouthFamily,
    icon: () => const FamilyGlyph(),
    slugs: ['youth', 'family'],
  ),
  Interest(
    AppStrings.interestMission,
    icon: () => _svg(AppAssets.iconCatGlobe),
  ),
  Interest(
    AppStrings.interestGrief,
    icon: () => _svg(AppAssets.iconCatHeartHand),
  ),
  Interest(
    AppStrings.interestMarriageFamilyRelationships,
    icon: () => _svg(AppAssets.iconCatRings),
    slugs: ['family'],
  ),
  Interest(
    AppStrings.interestLeadership,
    icon: () => _svg(AppAssets.iconCatCrown),
  ),
  Interest(AppStrings.interestFaith, icon: () => _svg(AppAssets.iconCatCoins)),
  Interest(
    AppStrings.interestGospelArtist,
    icon: () => _svg(AppAssets.iconCatMusicNote),
    slugs: ['gospel-music'],
  ),
];

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final _selected = <String>{};

  static const _progress = 236 / 350;

  /// Slugs for the picks, deduped. Chips with no API category contribute none.
  List<String> get _slugs => <String>{
    for (final interest in _interests)
      if (_selected.contains(interest.label)) ...interest.slugs,
  }.toList();

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
          child: SingleChildScrollView(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 17,
              children: [
                for (final interest in _interests)
                  InterestChip(
                    label: interest.label,
                    icon: interest.icon?.call(),
                    selected: _selected.contains(interest.label),
                    onTap: () => setState(() {
                      if (!_selected.remove(interest.label)) {
                        _selected.add(interest.label);
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.pop(),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: SvgPicture.asset(
                      AppAssets.iconArrowLeft,
                      width: 20,
                      height: 10,
                    ),
                  ),
                ),
              ),
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
