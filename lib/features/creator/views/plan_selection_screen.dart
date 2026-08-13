import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/logger.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/views/widgets/plan_card.dart';
import 'package:test_app/features/creator/views/widgets/payment_provider_sheet.dart';
import 'package:test_app/features/creator/views/widgets/plan_comparison_sheet.dart';
import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

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
  PaymentProvider? _recommendedProvider;
  bool _yearly = true;
  String? _selectedTier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final hint = await _repo.fetchCurrencyHint();
      final subject = BillingSubject.fromCreatorType(
        LocalStorage.getString(LocalStorage.creatorTypeKey),
      );
      final plans = await _repo.fetchPlans(
        billingSubject: subject,
        currency: hint.recommendedCurrency,
      );
      if (!mounted) return;
      setState(() {
        _currency = hint.recommendedCurrency;
        _plans = plans;
        _recommendedProvider = PaymentProvider.fromApi(
          hint.recommendedProvider,
        );
      });
    } catch (e) {
      logger.e('Failed to load plans', error: e);
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

  Future<void> _continue() async {
    final tier = _selectedTier ?? 'pro';
    final provider = await PaymentProviderSheet.show(
      context,
      planLabel: tier,
      yearly: _yearly,
      recommended: _recommendedProvider,
    );
    if (provider == null || !mounted) return;

    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) {
      logger.w('Skipping checkout: no cached creatorId');
      if (mounted) context.go(AppRouter.home);
      return;
    }

    try {
      final checkout = await _repo.createCheckout(
        creatorId: creatorId,
        planTier: tier,
        yearly: _yearly,
        provider: provider.value,
        currency: _currency,
      );
      // TODO(creator): open checkout.checkoutUrl in a browser/webview once the
      logger.i('Checkout created: ${checkout.reference}');
    } catch (e) {
      logger.e('Checkout failed', error: e);
    }
    if (mounted) context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.brandSecondary,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                currency: _currency,
                yearly: _yearly,
                onIntervalChanged: (yearly) => setState(() => _yearly = yearly),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(23, 0, 23, 24),
                  children: [
                    PlanCard(
                      copy: _basicCopy,
                      selected: _selectedTier == 'basic',
                      price: _priceFor('basic'),
                      onTap: () => setState(() => _selectedTier = 'basic'),
                    ),
                    const SizedBox(height: 18),
                    PlanCard(
                      copy: _proCopy,
                      selected: _selectedTier == 'pro' || _selectedTier == null,
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
                onContinue: _continue,
                onCompare: () => PlanComparisonSheet.show(
                  context,
                  currency: _currency,
                  basicPrice: _monthlyPriceFor('basic'),
                  proPrice: _monthlyPriceFor('pro'),
                ),
              ),
            ],
          ),
        ),
      ),
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
          SvgPicture.asset(
            AppAssets.iconChevronDown,
            width: 7.072,
            height: 4.713,
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
  const _BottomBar({required this.onContinue, required this.onCompare});

  final VoidCallback onContinue;
  final VoidCallback onCompare;

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
                  label: AppStrings.continueWithFree,
                  height: 54,
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
