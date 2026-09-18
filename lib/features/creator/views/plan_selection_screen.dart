import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/core/router.dart';
import 'package:test_app/features/creator/services/checkout_handoff_service.dart';
import 'package:test_app/features/creator/views/widgets/creator_onboarding_parts.dart';
import 'package:test_app/shared/components/onboarding_scaffold.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Where a creator chooses whether to pay for the studio.
///
/// **The plans themselves are not shown here.** Per the payment guide, the
/// first-party web surface owns the plan screen: mobile creates a durable
/// checkout session, opens its `launchUrl` in a system browser, and reads the
/// outcome back from the session. Tier, billing interval, currency and
/// provider are all chosen there, so a catalogue on this screen would be a
/// second source of truth that could only drift — and it would depend on
/// `GET /v1/payment/saas/plans`, which is unavailable.
///
/// Free needs no session at all: it means no subscription, so it goes straight
/// on. Both creator types arrive here the same way — the handoff needs only a
/// `creatorId`, which individuals and organisations both have by this point.
class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  bool _starting = false;

  /// Null until the capability check answers. The purchase action stays hidden
  /// until then: the guide requires hiding it — not disabling it — wherever a
  /// storefront may not sell subscriptions.
  bool? _canPurchase;

  @override
  void initState() {
    super.initState();
    _checkCapability();
  }

  Future<void> _checkCapability() async {
    final available = await getIt<CheckoutHandoffService>()
        .canPurchaseSubscription();
    if (mounted) setState(() => _canPurchase = available);
  }

  /// The way past this step without paying, and the only way past it where
  /// the storefront cannot sell at all.
  void _continueFree() {
    context.go(
      LocalStorage.creatorId == null ? AppRouter.home : AppRouter.creatorLive,
    );
  }

  Future<void> _choosePlan() async {
    if (_starting) return;
    final creatorId = LocalStorage.creatorId;
    if (creatorId == null) {
      context.go(AppRouter.home);
      return;
    }

    setState(() => _starting = true);
    final result = await getIt<CheckoutHandoffService>().start(
      creatorId: creatorId,
    );
    if (!mounted) return;
    setState(() => _starting = false);

    switch (result.outcome) {
      case HandoffOutcome.launched:
      case HandoffOutcome.alreadyActive:
        // The browser is open; the session is the only thing to trust.
        context.push(AppRouter.checkoutStatus, extra: result.sessionId);
      case HandoffOutcome.unavailable:
        setState(() => _canPurchase = false);
        _tell(AppStrings.checkoutUnavailable);
      case HandoffOutcome.failed:
        _tell(AppStrings.checkoutFailed);
    }
  }

  void _tell(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppStyles.body(13)),
      backgroundColor: AppColors.neutral800,
      behavior: SnackBarBehavior.floating,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final canPurchase = _canPurchase ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: OnboardingScaffold(
        backgroundColor: AppColors.brandSecondary,
        topBar: CreatorFlowHeader(
          title: AppStrings.yourPlan,
          subtitle: AppStrings.planHandoffSubtitle,
          onBack: () => context.pop(),
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canPurchase) ...[
              PrimaryButton(
                key: const ValueKey('choose-plan'),
                label: AppStrings.planChoose,
                height: 54,
                loading: _starting,
                onPressed: _choosePlan,
              ),
              const SizedBox(height: 12),
            ],
            GestureDetector(
              key: const ValueKey('continue-free'),
              behavior: HitTestBehavior.opaque,
              onTap: _continueFree,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  AppStrings.continueWithFree,
                  textAlign: TextAlign.center,
                  style: AppStyles.button(
                    14,
                    color: canPurchase
                        ? AppColors.neutral200
                        : AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 28),
            const _FreeSummary(),
            const SizedBox(height: 18),
            if (canPurchase)
              const _HandoffNote()
            else if (_canPurchase != null)
              const _UnavailableNote(),
          ],
        ),
      ),
    );
  }
}

/// What a creator gets without paying, so Free reads as a choice rather than
/// as a refusal.
class _FreeSummary extends StatelessWidget {
  const _FreeSummary();

  static const _includes = [
    'Upload sermons, music and messages',
    'Go live from your phone',
    'Receive giving',
    'Your channel page and followers',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.planFreeHeading,
            style: AppStyles.label(15, weight: AppStyles.bold),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.planFreeTagline,
            style: AppStyles.body(12, color: AppColors.neutral400),
          ),
          const SizedBox(height: 14),
          for (final line in _includes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    color: AppColors.statusDone,
                    size: 15,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      line,
                      style: AppStyles.body(
                        13,
                        color: AppColors.neutral200,
                        lineHeight: 18 / 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Says where the paid plans are, so the browser is expected rather than a
/// surprise.
class _HandoffNote extends StatelessWidget {
  const _HandoffNote();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const HugeIcon(
        icon: HugeIcons.strokeRoundedInformationCircle,
        color: AppColors.neutral500,
        size: 15,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          AppStrings.planHandoffNote,
          style: AppStyles.body(
            12,
            color: AppColors.neutral400,
            lineHeight: 17 / 12,
          ),
        ),
      ),
    ],
  );
}

/// The storefront may not sell subscriptions here.
class _UnavailableNote extends StatelessWidget {
  const _UnavailableNote();

  @override
  Widget build(BuildContext context) => Text(
    AppStrings.planUnavailableHere,
    style: AppStyles.body(12, color: AppColors.neutral400, lineHeight: 17 / 12),
  );
}
