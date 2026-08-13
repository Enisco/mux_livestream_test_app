import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

enum PaymentProvider {
  paystack(
    'paystack',
    AppStrings.providerPaystack,
    AppStrings.providerPaystackDesc,
    AppAssets.iconPaystack,
  ),
  flutterwave(
    'flutterwave',
    AppStrings.providerFlutterwave,
    AppStrings.providerFlutterwaveDesc,
    AppAssets.iconFlutterwave,
  ),
  stripe(
    'stripe',
    AppStrings.providerStripe,
    AppStrings.providerStripeDesc,
    AppAssets.iconStripe,
  );

  const PaymentProvider(this.value, this.label, this.description, this.icon);

  final String value;
  final String label;
  final String description;
  final String icon;

  static PaymentProvider? fromApi(String value) =>
      PaymentProvider.values.where((p) => p.value == value).firstOrNull;
}

class PaymentProviderSheet extends StatefulWidget {
  const PaymentProviderSheet({
    super.key,
    required this.planLabel,
    required this.yearly,
    this.recommended,
  });

  final String planLabel;
  final bool yearly;

  final PaymentProvider? recommended;

  static Future<PaymentProvider?> show(
    BuildContext context, {
    required String planLabel,
    required bool yearly,
    PaymentProvider? recommended,
  }) => showModalBottomSheet<PaymentProvider>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PaymentProviderSheet(
      planLabel: planLabel,
      yearly: yearly,
      recommended: recommended,
    ),
  );

  static const _cornerRadius = 24.0;

  @override
  State<PaymentProviderSheet> createState() => _PaymentProviderSheetState();
}

class _PaymentProviderSheetState extends State<PaymentProviderSheet> {
  late PaymentProvider _selected =
      widget.recommended ?? PaymentProvider.paystack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brandTertiary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PaymentProviderSheet._cornerRadius),
        ),
        border: Border(top: BorderSide(color: AppColors.neutral800)),
        boxShadow: AppStyles.logoTileShadow,
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: SizedBox(
              width: 40,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.neutral700,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _header(context),
          const SizedBox(height: 24),
          Text(
            AppStrings.payWith,
            style: AppStyles.caption(
              12,
              color: AppColors.textPrimary,
              lineHeight: 16 / 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.payWithSubtitle,
            style: AppStyles.caption(12, lineHeight: 16 / 12),
          ),
          const SizedBox(height: 16),
          for (final provider in PaymentProvider.values) ...[
            _ProviderTile(
              provider: provider,
              selected: _selected == provider,
              recommended: widget.recommended == provider,
              onTap: () => setState(() => _selected = provider),
            ),
            if (provider != PaymentProvider.values.last)
              const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: '${AppStrings.continueWith}${_selected.label}',
            height: 54,
            onPressed: () => Navigator.of(context).pop(_selected),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.providerFootnote,
            textAlign: TextAlign.center,
            style: AppStyles.caption(12, lineHeight: 16 / 12),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final cadence = widget.yearly
        ? AppStrings.billedYearly
        : AppStrings.billedMonthly;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.choosePaymentProvider,
                  style: AppStyles.label(
                    16,
                    weight: AppStyles.bold,
                    lineHeight: 24 / 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$cadence${widget.planLabel}${AppStrings.planSuffix}',
                  style: AppStyles.caption(12, lineHeight: 16 / 12),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(
            Icons.close,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.provider,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final PaymentProvider provider;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandAltDark : AppColors.brandTertiary,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.brandPrimary : AppColors.neutral900,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset(provider.icon, width: 20, height: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          provider.label,
                          style: AppStyles.label(13, weight: AppStyles.bold),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          const _RecommendedPill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.description,
                      style: AppStyles.caption(
                        12,
                        color: AppColors.textPrimary,
                        lineHeight: 16 / 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset(
                  selected
                      ? AppAssets.iconRadioSelected
                      : AppAssets.iconRadioUnselected,
                  width: 20,
                  height: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedPill extends StatelessWidget {
  const _RecommendedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Text(
        AppStrings.recommended,
        style: AppStyles.overline(
          10,
          color: AppColors.green600,
          lineHeight: 16 / 10,
        ),
      ),
    );
  }
}
