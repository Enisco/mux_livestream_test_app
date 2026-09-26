import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/onboarding/repo/onboarding_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/views/widgets/creator_topics_sheet.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/models/onboarding_models/onboarding_state.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

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
  final Set<String> _selectedSlugs = {};
  bool _saving = false;
  String? _error;

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
    final picked = await CreatorTopicsSheet.show(
      context,
      categories: _categories,
      selected: _selectedSlugs,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedSlugs
          ..clear()
          ..addAll(picked);
      });
    }
  }

  /// The chosen topics, named rather than slugged, for the closed field.
  String? get _categorySummary {
    if (_selectedSlugs.isEmpty) return null;
    return _categories
        .where((c) => _selectedSlugs.contains(c.slug))
        .map((c) => c.name)
        .join(', ');
  }

  /// What is missing, or null when the form is ready.
  String? _whatIsMissing() {
    if (_channelCtrl.text.trim().isEmpty) {
      return AppStrings.creatorNameRequired;
    }
    if (_selectedSlugs.isEmpty) return AppStrings.creatorCategoryMin1;
    if (_selectedSlugs.length > AppStrings.creatorCategoryMax) {
      return AppStrings.creatorCategoryTooMany;
    }
    return null;
  }

  Future<void> _continue() async {
    final missing = _whatIsMissing();
    if (missing != null) {
      setState(() => _error = missing);
      return;
    }
    setState(() => _error = null);
    final displayName = _channelCtrl.text.trim();
    await LocalStorage.setString(LocalStorage.creatorNameKey, displayName);
    setState(() => _saving = true);
    try {
      await _repo.saveCreatorProfile(
        handle: _resolvedHandle(displayName),
        displayName: displayName,
        type: 'individual',
        categorySlugs: _selectedSlugs.toList(),
      );
      // The channel exists now, so the funnel can name it; the plan step is
      // what comes next and it needs a creator to attach a subscription to.
      recordOnboardingState(
        step: OnboardingStep.creatorProfileForm,
        creatorType: OnboardingCreatorType.individual,
        creatorId: LocalStorage.creatorId,
      );
    } catch (e) {
      // Advancing past a channel that was never created would walk the reader
      // into the plan step with nothing to attach a subscription to.
      logger.e('Could not create the channel', error: e);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.creatorSetupFailed,
            style: AppStyles.body(13),
          ),
          backgroundColor: AppColors.neutral800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (mounted) context.go(AppRouter.planSelection);
  }

  String _resolvedHandle(String displayName) {
    if (_handleState == HandleState.available) return _handleCtrl.text.trim();
    return CreatorRepo.deriveHandle(displayName);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundColor: AppColors.brandSecondary,
      topBar: CreatorFlowHeader(
        title: AppStrings.creatorSetupTitle,
        subtitle: AppStrings.creatorSetupSubtitle,
        trailing: Image.asset(AppAssets.gtubeLogo, width: 24, height: 27),
        onBack: () => context.pop(),
      ),
      footer: PrimaryButton(
        label: AppStrings.creatorSetupProceed,
        height: 54,
        loading: _saving,
        onPressed: _continue,
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
            const SizedBox(height: 18),
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
              value: _categorySummary,
              onTap: _pickCategory,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
            ),
            if (_error case final message?) ...[
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppStyles.body(12, color: AppColors.destructive),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
