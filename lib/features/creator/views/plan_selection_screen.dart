import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/features/creator/views/widgets/plan_card.dart';
import 'package:test_app/features/creator/views/widgets/plan_comparison_sheet.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Free is not a row in the plan catalogue — the API's tiers are basic, pro
/// and enterprise, and "free" means no subscription at all. It is a card here
/// because the design offers it (the comparison table has a Free column and
/// the button has always said "Continue with Free"), and because a creator
/// must be able to get into the app without paying.
const _freeCopy = PlanCopy(
  title: AppStrings.planFree,
  tagline: AppStrings.planFreeTagline,
  // Free is the floor, so it inherits nothing.
  inheritsLine: AppStrings.planFreeIncludes,
  leftFeatures: ['3 uploads a month', '5 GB Storage', '7-day analytics'],
  rightFeatures: ['1 giving fund', 'Livestreaming', 'Community features'],
);

const _basicCopy = PlanCopy(
  title: AppStrings.planBasic,
  tagline: AppStrings.planBasicTagline,
  inheritsLine: AppStrings.everythingInFree,
  leftFeatures: ['20 uploads a month', '50 GB Storage', '30-day analytics'],
  rightFeatures: ['3 giving funds', '3 ad campaigns', '3 team seats'],
);

const _proCopy = PlanCopy(
  title: AppStrings.planPro,
  tagline: AppStrings.planProTagline,
  inheritsLine: AppStrings.everythingInBasic,
  highlighted: true,
  leftFeatures: [
    'Unlimited uploads',
    '500 GB . 4K upload',
    'Advanced Analytics (90 days)',
    'Unlimited giving funds',
  ],
  rightFeatures: [
    '20 team seats. 10 campaigns',
    'Verified badge',
    'Priority support',
  ],
);

const _enterpriseCopy = PlanCopy(
  title: AppStrings.planEnterprise,
  tagline: AppStrings.planEnterpriseTagline,
  inheritsLine: AppStrings.everythingInPro,
  leftFeatures: [
    'Unlimited storage',
    'Unlimited teams & campaign',
    'API access',
  ],
  rightFeatures: ['Dedicated support', 'Custom onboarding'],
);

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  final _repo = getIt<CreatorRepo>();

  List<SaasPlan> _plans = const [];
  String _currency = 'USD';
  bool _yearly = true;
  bool _loadingPlans = true;
  bool _plansFailed = false;
  bool _starting = false;

  /// Not a server tier — see [_freeCopy].
  static const _freeTier = 'free';

  /// Free by default: the button acts on what is selected, so the safe
  /// default is the one that costs nothing.
  String _selectedTier = _freeTier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadingPlans = true;
      _plansFailed = false;
    });

    // The currency-hint route answers 500 for everyone, so the currency comes
    // from the account's own country instead.
    final currency = CreatorRepo.currencyForCountry(
      LocalStorage.cachedCountryCode,
    );
    final subject = BillingSubject.fromCreatorType(
      LocalStorage.getString(LocalStorage.creatorTypeKey),
    );

    try {
      final plans = await _repo.fetchPlans(
        billingSubject: subject,
        currency: currency,
      );
      if (!mounted) return;
      setState(() {
        _currency = currency;
        _plans = plans;
        _loadingPlans = false;
      });
    } catch (e) {
      logger.e('Failed to load plans', error: e);
      if (!mounted) return;
      // Free is still reachable, so the screen stays usable — but it must not
      // show blank prices as though they were real.
      setState(() {
        _currency = currency;
        _loadingPlans = false;
        _plansFailed = true;
      });
    }
  }

  int? _priceFor(String tier) {
    final interval = _yearly ? 'year' : 'month';
    for (final plan in _plans) {
      if (plan.planTier == tier && plan.billingInterval == interval) {
        return _yearly ? (plan.amountMajor / 12).round() : plan.amountMajor;
      }
    }
    return null;
  }

  int? _monthlyPriceFor(String tier) {
    for (final plan in _plans) {
      if (plan.planTier == tier && plan.billingInterval == 'month') {
        return plan.amountMajor;
      }
    }
    return null;
  }

  /// Free needs no checkout — the channel already exists, so the reader goes
  /// straight on. Anything paid hands off to the web checkout, where the
  /// provider and the payment are chosen.
  Future<void> _continue() async {
    if (_starting) return;
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) {
      logger.w('Skipping checkout: no cached creatorId');
      context.go(AppRouter.home);
      return;
    }

    if (_selectedTier == _freeTier) {
      context.go(AppRouter.creatorLive);
      return;
    }

    setState(() => _starting = true);
    final result = await getIt<CheckoutHandoffService>().start(
      creatorId: creatorId,
      planTier: _selectedTier,
    );
    if (!mounted) return;
    setState(() => _starting = false);

    switch (result.outcome) {
      case HandoffOutcome.launched:
      case HandoffOutcome.alreadyActive:
        context.push(AppRouter.checkoutStatus, extra: result.sessionId);
      case HandoffOutcome.unavailable:
        _tell(AppStrings.checkoutUnavailable);
      case HandoffOutcome.failed:
        _tell(AppStrings.checkoutFailed);
    }
  }

  static String _tierLabel(String tier) => switch (tier) {
    'basic' => AppStrings.planBasic,
    'pro' => AppStrings.planPro,
    'enterprise' => AppStrings.planEnterprise,
    _ => AppStrings.planFree,
  };

  void _tell(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.brandSecondary,
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    return Column(
      children: [
        _Header(
          currency: _currency,
          yearly: _yearly,
          onIntervalChanged: (yearly) => setState(() => _yearly = yearly),
        ),
        // Prices come from the catalogue; when it is unreachable the cards
        // show no figure, so the reason is said rather than left blank.
        if (_loadingPlans)
          const Padding(
            padding: EdgeInsets.fromLTRB(23, 0, 23, 4),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.brandPrimary,
              backgroundColor: Colors.transparent,
            ),
          ),
        if (_plansFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 0, 23, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.plansUnavailable,
                    style: AppStyles.body(
                      12,
                      color: AppColors.neutral400,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  key: const ValueKey('plans-retry'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _load,
                  child: Text(
                    AppStrings.plansRetry,
                    style: AppStyles.label(
                      12,
                      weight: AppStyles.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(23, 0, 23, 24),
            children: [
              PlanCard(
                copy: _freeCopy,
                selected: _selectedTier == _freeTier,
                customPrice:
                    '${AppStrings.currencySymbolFor(_currency)}'
                    '${AppStrings.planFreePrice}',
                onTap: () => setState(() => _selectedTier = _freeTier),
              ),
              const SizedBox(height: 18),
              PlanCard(
                copy: _basicCopy,
                selected: _selectedTier == 'basic',
                price: _priceFor('basic'),
                onTap: () => setState(() => _selectedTier = 'basic'),
              ),
              const SizedBox(height: 18),
              PlanCard(
                copy: _proCopy,
                selected: _selectedTier == 'pro',
                price: _priceFor('pro'),
                onTap: () => setState(() => _selectedTier = 'pro'),
              ),
              const SizedBox(height: 18),
              PlanCard(
                copy: _enterpriseCopy,
                selected: _selectedTier == 'enterprise',
                customPrice: AppStrings.planEnterprisePrice,
                mutedInheritsLine: true,
                onTap: () => setState(() => _selectedTier = 'enterprise'),
              ),
            ],
          ),
        ),
        _BottomBar(
          label: _selectedTier == _freeTier
              ? AppStrings.continueWithFree
              : AppStrings.continueWithTier(_tierLabel(_selectedTier)),
          busy: _starting,
          onContinue: _continue,
          onCompare: () => PlanComparisonSheet.show(
            context,
            currency: _currency,
            basicPrice: _monthlyPriceFor('basic'),
            proPrice: _monthlyPriceFor('pro'),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.currency,
    required this.yearly,
    required this.onIntervalChanged,
  });

  final String currency;
  final bool yearly;
  final ValueChanged<bool> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandSecondary,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GTubeBackButton(onTap: () => context.pop()),
                    const SizedBox(width: 10),
                    Text(
                      AppStrings.yourPlan,
                      style: AppStyles.heading(
                        20,
                        lineHeight: 32 / 20,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
                _CurrencyPill(currency: currency),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _BillingToggle(yearly: yearly, onChanged: onIntervalChanged),
        ],
      ),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.buttonSecondaryActive,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.neutral400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${AppStrings.currencyPrefix}$currency',
            style: AppStyles.overline(
              10,
              weight: AppStyles.black,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            AppIcons.chevronDown,
            size: 12,
            color: AppColors.neutral400,
          ),
        ],
      ),
    );
  }
}

class _BillingToggle extends StatelessWidget {
  const _BillingToggle({required this.yearly, required this.onChanged});

  final bool yearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.buttonSecondaryActive,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: AppStrings.billingMonthly,
            active: !yearly,
            onTap: () => onChanged(false),
          ),
          _Segment(
            label: AppStrings.billingYearly,
            active: yearly,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: active
              ? const LinearGradient(
                  colors: [AppColors.brandPrimary, AppColors.brandPrimaryMid],
                )
              : null,
          color: active ? null : AppColors.buttonSecondaryActive,
        ),
        child: Text(label, style: AppStyles.label(13, weight: AppStyles.bold)),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.onContinue,
    required this.onCompare,
    this.busy = false,
  });

  /// Names the tier the button will act on, so the reader is never surprised
  /// by a checkout they did not ask for.
  final String label;

  final VoidCallback onContinue;
  final VoidCallback onCompare;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.brandSecondary,
      padding: const EdgeInsets.only(top: 20, bottom: 16),
      child: Column(
        children: [
          SizedBox(
            width: 350,
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCompare,
                  child: Text(
                    AppStrings.compareEverything,
                    style: AppStyles.body(
                      14,
                      color: AppColors.brandPrimary,
                      lineHeight: 16 / 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: label,
                  height: 54,
                  loading: busy,
                  onPressed: onContinue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
