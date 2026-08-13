import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/views/widgets/category_picker_sheet.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/onboarding/views/widgets/onboarding_progress_bar.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// "Setup your profile in seconds" — the individual creator's profile setup.
/// The design frame is misleadingly named "How will you share your ministry".
class CreatorProfileSetupScreen extends StatefulWidget {
  const CreatorProfileSetupScreen({super.key});

  @override
  State<CreatorProfileSetupScreen> createState() =>
      _CreatorProfileSetupScreenState();
}

class _CreatorProfileSetupScreenState extends State<CreatorProfileSetupScreen> {
  final _channelCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _repo = getIt<CreatorRepo>();

  Timer? _debounce;
  HandleState _handleState = HandleState.idle;
  String _normalizedHandle = '';
  List<ContentCategory> _categories = const [];
  ContentCategory? _category;

  /// The design draws the fill at 236 of a 350-wide track.
  static const _progress = 236 / 350;

  static const _handleDebounce = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    _handleCtrl.addListener(_onHandleChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _channelCtrl.dispose();
    _handleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _repo.fetchCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (e) {
      logger.e('Failed to load categories', error: e);
    }
  }

  void _onHandleChanged() {
    _debounce?.cancel();
    final handle = _handleCtrl.text.trim();
    if (handle.isEmpty) {
      setState(() => _handleState = HandleState.idle);
      return;
    }
    setState(() => _handleState = HandleState.checking);
    _debounce = Timer(_handleDebounce, () => _checkHandle(handle));
  }

  Future<void> _checkHandle(String handle) async {
    try {
      final result = await _repo.checkHandleAvailability(handle);
      if (!mounted || _handleCtrl.text.trim() != handle) return;
      setState(() {
        _normalizedHandle = result.normalizedHandle;
        if (!result.valid) {
          _handleState = HandleState.invalid;
        } else {
          _handleState = result.available
              ? HandleState.available
              : HandleState.taken;
        }
      });
    } catch (e) {
      logger.e('Handle availability check failed', error: e);
      if (mounted) setState(() => _handleState = HandleState.idle);
    }
  }

  Future<void> _pickCategory() async {
    FocusScope.of(context).unfocus();
    if (_categories.isEmpty) await _loadCategories();
    if (!mounted || _categories.isEmpty) return;
    final picked = await CategoryPickerSheet.show(context, _categories);
    if (picked != null && mounted) setState(() => _category = picked);
  }

  /// Creates the channel — this screen is where a viewer becomes a creator.
  /// Skipping leaves them without one; the studio provisions it later.
  Future<void> _continue() async {
    final displayName = _channelCtrl.text.trim();
    if (displayName.isEmpty) {
      context.go(AppRouter.planSelection);
      return;
    }
    await _repo.saveCreatorProfile(
      handle: _resolvedHandle(displayName),
      displayName: displayName,
      type: 'individual',
      categorySlugs: _category == null ? null : [_category!.slug],
    );
    if (mounted) context.go(AppRouter.planSelection);
  }

  /// The typed handle once availability confirms it, else one derived from the
  /// channel name so the channel is still creatable.
  String _resolvedHandle(String displayName) {
    if (_handleState == HandleState.available) return _handleCtrl.text.trim();
    return CreatorRepo.deriveHandle(displayName);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundColor: AppColors.brandSecondary,
      backgroundAsset: AppAssets.worshipBg,
      topBar: _TopBar(progress: _progress, onSkip: _continue),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.creatorSetupFootnote,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: GTubeLogoMark.compact()),
            const SizedBox(height: 8),
            Text(
              AppStrings.creatorSetupTitle,
              textAlign: TextAlign.center,
              style: AppStyles.heading(20, letterSpacing: -0.8),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.creatorSetupSubtitle,
              textAlign: TextAlign.center,
              style: AppStyles.body(13),
            ),
            const SizedBox(height: 40),
            const CreatorFieldLabel(AppStrings.channelName),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _channelCtrl,
              hint: AppStrings.channelNameHint,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.handleLabel, size: 13),
            const SizedBox(height: 10),
            CreatorHandleField(
              controller: _handleCtrl,
              state: _handleState,
              normalizedHandle: _normalizedHandle,
              prefix: AppStrings.handlePrefix,
              availableLabel: AppStrings.handleAvailable,
              takenLabel: AppStrings.handleTaken,
              invalidLabel: AppStrings.handleInvalid,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.mostlyShare, bold: true),
            const SizedBox(height: 10),
            CreatorSelectField(
              hint: AppStrings.mostlyShareHint,
              value: _category?.name,
              onTap: _pickCategory,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
            ),
          ],
        ),
      ),
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

/// Field caption. The design uses three variants: 12 medium, 13 medium and
/// 12 bold — see docs/OPEN_ISSUES.md on inconsistent tokens.
