import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/library_models/give_flow_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// "What is this gift for?" — Figma `11117-116520`.
///
/// The app's whole share of the giving journey. The next frame in the design
/// (`11117-116521`, the amount and the fee breakdown) is deliberately **not**
/// built: amount, currency, the platform fee and the exact charge are all
/// server-computed and the giver meets them on the web surface, so drawing
/// them here would mean the app quoting figures it cannot be the source of.
///
/// The sheet is skipped entirely when a ministry has one fund, which is the
/// common case — the reserved `general` fund always exists, so "choose a
/// purpose" with a single row is a question with one answer.
class GiveFundSheet extends StatefulWidget {
  const GiveFundSheet({
    super.key,
    required this.ministry,
    required this.funds,
    this.initialSlug,
  });

  final String ministry;
  final List<GivingFundOption> funds;
  final String? initialSlug;

  /// Returns the chosen slug, or null when the giver backed out.
  static Future<String?> show(
    BuildContext context, {
    required String ministry,
    required List<GivingFundOption> funds,
    String? initialSlug,
  }) => showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => GiveFundSheet(
      ministry: ministry,
      funds: funds,
      initialSlug: initialSlug,
    ),
  );

  @override
  State<GiveFundSheet> createState() => _GiveFundSheetState();
}

class _GiveFundSheetState extends State<GiveFundSheet> {
  /// Preselected the way the guide asks: the giver's own `?give=` slug when
  /// one came in, otherwise the reserved general fund, otherwise the first
  /// row. Never nothing — an unselected list makes Continue look broken.
  late String _slug = _initialSelection();

  String _initialSelection() {
    final wanted = widget.initialSlug;
    final slugs = {for (final f in widget.funds) f.slug};
    if (wanted != null && slugs.contains(wanted)) return wanted;
    if (slugs.contains(GivingFundOption.generalSlug)) {
      return GivingFundOption.generalSlug;
    }
    return widget.funds.isEmpty ? '' : widget.funds.first.slug;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 60),
      decoration: BoxDecoration(
        color: AppColors.base1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.s)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.s, 24.s, 20.s, 0),
                child: _Header(ministry: widget.ministry),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.s, 28.s, 20.s, 12.s),
                child: Text(
                  AppStrings.giveFundPurpose,
                  style: AppStyles.body(14, color: AppColors.neutral300),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(20.s, 0, 20.s, 8.s),
                  itemCount: widget.funds.length,
                  separatorBuilder: (_, _) => SizedBox(height: 12.s),
                  itemBuilder: (_, i) {
                    final fund = widget.funds[i];
                    return _FundRow(
                      key: ValueKey('give-fund-${fund.slug}'),
                      fund: fund,
                      ministry: widget.ministry,
                      selected: fund.slug == _slug,
                      onTap: () => setState(() => _slug = fund.slug),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.s, 16.s, 20.s, 12.s),
                child: PrimaryButton(
                  key: const ValueKey('give-fund-continue'),
                  label: AppStrings.giveContinue,
                  height: 54,
                  enabled: _slug.isNotEmpty,
                  onPressed: () => Navigator.of(context).pop(_slug),
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
  const _Header({required this.ministry});

  final String ministry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.giveFundsTitle,
                style: AppStyles.heading(20, letterSpacing: -0.8),
              ),
              SizedBox(height: 8.s),
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedGift,
                    size: 16.s,
                    color: AppColors.brandPrimary,
                  ),
                  SizedBox(width: 6.s),
                  Flexible(
                    child: Text(
                      AppStrings.giveToMinistry(ministry),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.body(14, color: AppColors.neutral300),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 12.s),
        GestureDetector(
          key: const ValueKey('give-fund-close'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: EdgeInsets.all(4.s),
            child: Icon(Icons.close, size: 22.s, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _FundRow extends StatelessWidget {
  const _FundRow({
    super.key,
    required this.fund,
    required this.ministry,
    required this.selected,
    required this.onTap,
  });

  final GivingFundOption fund;
  final String ministry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The design captions the general fund with the ministry's name and the
    // rest with their own description. A fund whose description was left
    // blank falls back to the same caption rather than drawing an empty line.
    final caption = fund.description?.trim().isNotEmpty ?? false
        ? fund.description!.trim()
        : AppStrings.giveFundFor(ministry);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 14.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.s),
          color: AppColors.base2,
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.neutral700,
            width: 1.5.s,
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: fund.isGeneral
                  ? HugeIcons.strokeRoundedChurch
                  : HugeIcons.strokeRoundedCoins01,
              size: 22.s,
              color: AppColors.neutral300,
            ),
            SizedBox(width: 14.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fund.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.heading(14),
                  ),
                  SizedBox(height: 2.s),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.body(12, color: AppColors.neutral400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
