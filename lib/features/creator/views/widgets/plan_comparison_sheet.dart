import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

class _Row {
  const _Row(this.label, this.free, this.basic, this.pro);

  final String label;
  final String free;
  final String basic;
  final String pro;
}

const _rows = <_Row>[
  _Row('Video uploads /mo', '5', '20', '∞'),
  _Row('Storage', '5 GB', '50 GB', '500 GB'),
  _Row('Livestreaming', '✓', '✓', '✓'),
  _Row('HD upload', '✓', '✓', '✓'),
  _Row('4K upload', '—', '—', '✓'),
  _Row('Analytics window', '7 days', '30 days', '90 days'),
  _Row('Advanced analytics', '—', '—', '✓'),
  _Row('Giving funds', 'General', '3', '∞'),
  _Row('Promotions running', '1', '3', '10'),
  _Row('Priority support', '—', '—', '✓'),
];

class PlanComparisonSheet extends StatelessWidget {
  const PlanComparisonSheet({
    super.key,
    required this.currency,
    this.basicPrice,
    this.proPrice,
  });

  final String currency;

  final int? basicPrice;
  final int? proPrice;

  static Future<void> show(
    BuildContext context, {
    required String currency,
    int? basicPrice,
    int? proPrice,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PlanComparisonSheet(
      currency: currency,
      basicPrice: basicPrice,
      proPrice: proPrice,
    ),
  );

  static const _cornerRadius = 32.0;
  static const _freeColWidth = 60.0;
  static const _tierColWidth = 75.0;

  static String symbolFor(String code) => switch (code) {
    'USD' => r'$',
    'NGN' => '₦',
    'GBP' => '£',
    'EUR' => '€',
    _ => '$code ',
  };

  String _price(int? amount) {
    if (amount == null) return '—';
    final symbol = symbolFor(currency);
    final digits = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$symbol$digits';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.84,
      ),
      decoration: const BoxDecoration(
        color: AppColors.brandSecondary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_cornerRadius),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                AppStrings.everyFeatureEveryPlan,
                textAlign: TextAlign.center,
                style: AppStyles.heading(22, weight: AppStyles.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const _TableRow(
                    label: '',
                    free: AppStrings.tierFree,
                    basic: AppStrings.planBasic,
                    pro: AppStrings.planPro,
                    isHeader: true,
                  ),
                  _TableRow(
                    label: AppStrings.rowPricePerMonth,
                    free: '${symbolFor(currency)}0',
                    basic: _price(basicPrice),
                    pro: _price(proPrice),
                    highlightBasic: true,
                  ),
                  for (final row in _rows)
                    _TableRow(
                      label: row.label,
                      free: row.free,
                      basic: row.basic,
                      pro: row.pro,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.label,
    required this.free,
    required this.basic,
    required this.pro,
    this.isHeader = false,
    this.highlightBasic = false,
  });

  final String label;
  final String free;
  final String basic;
  final String pro;
  final bool isHeader;
  final bool highlightBasic;

  @override
  Widget build(BuildContext context) {
    final valueStyle = isHeader
        ? AppStyles.label(15, weight: AppStyles.bold)
        : AppStyles.label(14, weight: AppStyles.semiBold);
    final basicStyle = isHeader
        ? AppStyles.label(15, weight: AppStyles.bold)
        : highlightBasic
        ? AppStyles.label(
            14,
            color: AppColors.brandPrimary,
            weight: AppStyles.bold,
          )
        : AppStyles.label(14, weight: AppStyles.bold);

    return Container(
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: AppColors.tableBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.body(14, color: AppColors.neutral400),
            ),
          ),
          SizedBox(
            width: PlanComparisonSheet._freeColWidth,
            child: Text(free, textAlign: TextAlign.center, style: valueStyle),
          ),
          SizedBox(
            width: PlanComparisonSheet._tierColWidth,
            child: Text(basic, textAlign: TextAlign.center, style: basicStyle),
          ),
          SizedBox(
            width: PlanComparisonSheet._tierColWidth,
            child: Text(pro, textAlign: TextAlign.center, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
