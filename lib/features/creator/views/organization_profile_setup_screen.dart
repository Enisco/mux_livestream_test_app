import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/creator_topics_sheet.dart';
import 'package:test_app/shared/components/country_picker_sheet.dart';
import 'package:test_app/shared/data/countries.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

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
  final _orgEmailCtrl = TextEditingController();
  final _orgPhoneCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _repo = getIt<CreatorRepo>();

  Timer? _debounce;
  HandleState _handleState = HandleState.idle;
  String _normalizedHandle = '';
  Country? _country;
  List<ContentCategory> _categories = const [];
  String? _error;
  final Set<String> _selectedSlugs = {};
  bool _saving = false;

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
    for (final c in [
      _orgNameCtrl,
      _handleCtrl,
      _orgEmailCtrl,
      _orgPhoneCtrl,
      _aboutCtrl,
      _stateCtrl,
      _cityCtrl,
      _postalCtrl,
      _websiteCtrl,
    ]) {
      c.dispose();
    }
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

  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await CountryPickerSheet.show(context, selected: _country);
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Future<void> _pickCategories() async {
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

  String? get _categorySummary {
    if (_selectedSlugs.isEmpty) return null;
    final names = _categories
        .where((c) => _selectedSlugs.contains(c.slug))
        .map((c) => c.name);
    return names.join(', ');
  }

  /// What is missing, or null when the form is ready.
  ///
  /// The six organisation fields are checked here because the server refuses
  /// an organisation without them, and a 400 after the fact reads as a
  /// failure rather than as something to fill in.
  String? _whatIsMissing() {
    if (_orgNameCtrl.text.trim().isEmpty) {
      return AppStrings.creatorNameRequired;
    }
    if (_selectedSlugs.isEmpty) return AppStrings.creatorCategoryMin1;
    if (_selectedSlugs.length > AppStrings.creatorCategoryMax) {
      return AppStrings.creatorCategoryTooMany;
    }
    final email = _orgEmailCtrl.text.trim();
    if (email.isEmpty ||
        _orgPhoneCtrl.text.trim().isEmpty ||
        _aboutCtrl.text.trim().isEmpty ||
        _country == null ||
        _stateCtrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty) {
      return AppStrings.orgFieldsRequired;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return AppStrings.orgEmailInvalid;
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
    final displayName = _orgNameCtrl.text.trim();
    await LocalStorage.setString(LocalStorage.creatorNameKey, displayName);
    setState(() => _saving = true);
    try {
      await _repo.saveCreatorProfile(
        handle: _handleState == HandleState.available
            ? _handleCtrl.text.trim()
            : CreatorRepo.deriveHandle(displayName),
        displayName: displayName,
        type: 'organization',
        categorySlugs: _selectedSlugs.toList(),
        orgEmail: _orgEmailCtrl.text.trim(),
        orgPhone: _orgPhoneCtrl.text.trim(),
        about: _aboutCtrl.text.trim(),
        country: _country!.isoCode,
        stateOrProvince: _stateCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim(),
        // Website is collected but deliberately not sent: links are not being
        // accepted from creators yet. `POST /v1/creator/onboard` does take a
        // `website`, so this is the one line to restore when that changes.
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

            // Everything below is what `POST /v1/creator/onboard` demands of
            // an organisation. Without them it answers 400, which is why the
            // four-field version of this screen could never create a channel.
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.orgEmailLabel),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _orgEmailCtrl,
              hint: AppStrings.orgEmailHint,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.orgPhoneLabel),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _orgPhoneCtrl,
              hint: AppStrings.orgPhoneHint,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.orgAboutLabel),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _aboutCtrl,
              hint: AppStrings.orgAboutHint,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.orgCountryLabel),
            const SizedBox(height: 10),
            CreatorSelectField(
              hint: AppStrings.orgCountryHint,
              value: _country?.name,
              onTap: _pickCountry,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.orgStateLabel),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _stateCtrl,
              hint: AppStrings.orgStateHint,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.orgCityLabel),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _cityCtrl,
              hint: AppStrings.orgCityHint,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(AppStrings.orgPostalLabel),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _postalCtrl,
              hint: AppStrings.orgPostalHint,
            ),
            const SizedBox(height: 20),
            const CreatorFieldLabel(
              '${AppStrings.orgWebsiteLabel} '
              '(${AppStrings.orgWebsiteOptional})',
            ),
            const SizedBox(height: 10),
            CreatorTextField(
              controller: _websiteCtrl,
              hint: AppStrings.orgWebsiteHint,
              keyboardType: TextInputType.url,
            ),
            if (_error case final message?) ...[
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppStyles.body(12, color: AppColors.destructive),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
