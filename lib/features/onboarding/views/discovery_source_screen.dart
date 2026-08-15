import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/features/onboarding/views/widgets/onboarding_progress_bar.dart';
import 'package:test_app/features/onboarding/views/widgets/radio_option_row.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum DiscoverySource {
  friend(AppStrings.discoveryFriend, AppAssets.iconSourceFriend),
  church(AppStrings.discoveryChurch, AppAssets.iconSourceChurch),
  social(AppStrings.discoverySocial, AppAssets.iconSourceSocial),
  youtube(AppStrings.discoveryYoutube, AppAssets.iconSourceYoutube),
  google(AppStrings.discoveryGoogle, AppAssets.iconSourceSearch),
  podcast(AppStrings.discoveryPodcast, AppAssets.iconSourcePodcast);

  const DiscoverySource(this.label, this.icon);

  final String label;
  final String icon;
}

class DiscoverySourceScreen extends StatefulWidget {
  const DiscoverySourceScreen({super.key, this.categorySlugs = const []});

  /// Carried from the interests step so both land in one payload.
  final List<String> categorySlugs;

  @override
  State<DiscoverySourceScreen> createState() => _DiscoverySourceScreenState();
}

class _DiscoverySourceScreenState extends State<DiscoverySourceScreen> {
  final _otherCtrl = TextEditingController();
  final _otherFocus = FocusNode();
  DiscoverySource? _selected;

  static const _progress = 316 / 350;

  @override
  void initState() {
    super.initState();
    _otherFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final source = _selected?.name;
    final detail = _otherCtrl.text.trim();
    final slugs = widget.categorySlugs;
    if (source != null || detail.isNotEmpty || slugs.isNotEmpty) {
      try {
        await getIt<OnboardingRepo>().updateViewerPreferences(
          categorySlugs: slugs.isEmpty ? null : slugs,
          discoverySource: source,
          discoveryDetail: detail,
        );
      } catch (e) {
        logger.w('Could not save discovery source', error: e);
      }
    }
    if (mounted) context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundColor: AppColors.brandSecondary,
      backgroundAsset: AppAssets.worshipBg,
      topBar: const _TopBar(progress: _progress),
      // The option list scrolls itself; the heading stays put.
      scrollable: false,
      footer: PrimaryButton(
        label: AppStrings.continueLabel,
        height: 54,
        onPressed: _continue,
      ),
      child: _content(),
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: GTubeLogoMark.compact()),
          const SizedBox(height: 8),
          Text(
            AppStrings.discoveryTitle,
            textAlign: TextAlign.center,
            style: AppStyles.heading(20, letterSpacing: -0.8),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.discoverySubtitle,
            textAlign: TextAlign.center,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final source in DiscoverySource.values) ...[
                    RadioOptionRow(
                      icon: source.icon,
                      label: source.label,
                      selected: _selected == source,
                      onTap: () => setState(() => _selected = source),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _OtherField(controller: _otherCtrl, focusNode: _otherFocus),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.progress});

  final double progress;

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
          child: Row(children: [GTubeBackButton(onTap: () => context.pop())]),
        ),
      ],
    );
  }
}

class _OtherField extends StatelessWidget {
  const _OtherField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: AppStyles.body(
        14,
        color: AppColors.textPrimary,
        lineHeight: 20 / 14,
      ),
      cursorColor: AppColors.textPrimary,
      decoration: InputDecoration(
        hintText: AppStrings.typeHere,
        hintStyle: AppStyles.body(
          14,
          color: AppColors.neutral400,
          lineHeight: 20 / 14,
        ),
        filled: true,
        fillColor: AppColors.brandAltDark,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        enabledBorder: _border(AppColors.neutral700),
        focusedBorder: _border(AppColors.brandPrimary),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );
}
