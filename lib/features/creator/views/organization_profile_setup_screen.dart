import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/multi_category_sheet.dart';
import 'package:test_app/features/creator/views/widgets/org_type_sheet.dart';
import 'package:test_app/features/onboarding/views/widgets/onboarding_progress_bar.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/gtube_logo_mark.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Organisation variant of "Setup your profile in seconds".
class OrganizationProfileSetupScreen extends StatefulWidget {
  const OrganizationProfileSetupScreen({super.key});

  @override
  State<OrganizationProfileSetupScreen> createState() =>
      _OrganizationProfileSetupScreenState();
}

class _OrganizationProfileSetupScreenState
    extends State<OrganizationProfileSetupScreen> {
  final _orgNameCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _repo = getIt<CreatorRepo>();

  Timer? _debounce;
  HandleState _handleState = HandleState.idle;
  String _normalizedHandle = '';
  OrgType? _orgType;
  List<ContentCategory> _categories = const [];
  final Set<String> _selectedSlugs = {};

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
    _orgNameCtrl.dispose();
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

  Future<void> _pickOrgType() async {
    FocusScope.of(context).unfocus();
    final picked = await OrgTypeSheet.show(context);
    if (picked != null && mounted) setState(() => _orgType = picked);
  }

  Future<void> _pickCategories() async {
    FocusScope.of(context).unfocus();
    if (_categories.isEmpty) await _loadCategories();
    if (!mounted || _categories.isEmpty) return;
    final picked = await MultiCategorySheet.show(
      context,
      _categories,
      _selectedSlugs,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedSlugs
          ..clear()
          ..addAll(picked);
      });
    }
  }

  String? get _categorySummary {
    if (_selectedSlugs.isEmpty) return null;
    final names = _categories
        .where((c) => _selectedSlugs.contains(c.slug))
        .map((c) => c.name);
    return names.join(', ');
  }

  /// Creates the channel. "Type of organization" has no field on either creator
  /// DTO — see docs/OPEN_ISSUES.md.
  Future<void> _continue() async {
    final displayName = _orgNameCtrl.text.trim();
    if (displayName.isEmpty) {
      context.go(AppRouter.planSelection);
      return;
    }
    await _repo.saveCreatorProfile(
      handle: _handleState == HandleState.available
          ? _handleCtrl.text.trim()
          : CreatorRepo.deriveHandle(displayName),
      displayName: displayName,
      type: 'organization',
      categorySlugs: _selectedSlugs.isEmpty ? null : _selectedSlugs.toList(),
    );
    if (mounted) context.go(AppRouter.planSelection);
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
            const CreatorFieldLabel(AppStrings.orgTypeLabel),
            const SizedBox(height: 10),
            CreatorSelectField(
              hint: AppStrings.orgTypeHint,
              value: _orgType?.label,
              onTap: _pickOrgType,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.orgNameLabel),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _orgNameCtrl,
              hint: AppStrings.orgNameHint,
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
              value: _categorySummary,
              onTap: _pickCategories,
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
