import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/views/giving_earnings_screen.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// How much came in over a window, what it was given towards, and the last
/// gifts to arrive.
///
/// Every figure on this screen is provider-reported and bucketed by
/// settlement currency. The screen leads with one bucket — the active
/// settlement currency's — and never adds two together, which is why there
/// is no single "total raised" anywhere on it.
///
/// The wording is load-bearing. **Gross gifts** is what givers sent;
/// **estimated proceeds** is what should arrive and is explicitly not
/// earnings, because provider adjustments can still move it; **held by
/// provider** is settled money still inside its hold window. Collapsing any
/// of the three into "earnings" would tell a creator they have money they
/// cannot yet touch.
class GivingFundsScreen extends StatefulWidget {
  const GivingFundsScreen({super.key, required this.creatorId, this.repo});

  final String creatorId;
  final GivingRepo? repo;

  @override
  State<GivingFundsScreen> createState() => _GivingFundsScreenState();
}

/// The windows the period picker offers.
enum GivingPeriod {
  thisMonth(AppStrings.givingThisMonth, null),
  last7(AppStrings.earningsLast7, 7),
  last30(AppStrings.earningsLast30, 30),
  last90(AppStrings.earningsLast90, 90),
  allTime(AppStrings.earningsAllTime, 0);

  const GivingPeriod(this.label, this.days);

  final String label;

  /// Null is the calendar month; 0 is no boundary at all.
  final int? days;

  /// The inclusive start boundary, or null for everything.
  DateTime? from(DateTime now) => switch (days) {
    null => DateTime(now.year, now.month),
    0 => null,
    final int window => now.subtract(Duration(days: window)),
  };
}

class _GivingFundsScreenState extends State<GivingFundsScreen> {
  late final _repo = widget.repo ?? GivingRepo();

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  GivingPeriod _period = GivingPeriod.thisMonth;
  EarningsSummary _summary = const EarningsSummary();
  GivingFundList _funds = const GivingFundList();
  List<GivingRecord> _recent = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final from = _period.from(DateTime.now());
    try {
      final results = await Future.wait([
        _repo.fetchSummary(widget.creatorId, from: from),
        _repo.fetchFunds(widget.creatorId),
        _repo.fetchTransactions(widget.creatorId, from: from, limit: 5),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as EarningsSummary;
        _funds = results[1] as GivingFundList;
        _recent = (results[2] as GivingRecordPage).items;
        _loading = false;
      });
    } catch (e) {
      logger.w('Giving funds failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _pickPeriod() async {
    final picked = await GivingPickerSheet.show<GivingPeriod>(
      context,
      title: AppStrings.earningsPeriod,
      options: GivingPeriod.values,
      labelOf: (value) => value.label,
      selected: _period,
    );
    if (picked == null || !mounted || picked == _period) return;
    setState(() => _period = picked);
    await _load();
  }

  /// Make a fund, or change one.
  ///
  /// The plan ceiling is checked before the dialog opens so a creator is not
  /// asked to write a description for a fund that cannot be created — but
  /// the refusal is still handled, because a slot can go between the read
  /// and the write.
  Future<void> _editFund([GivingFund? fund]) async {
    if (fund == null && !_funds.limits.canCreate) {
      _say(AppStrings.givingFundLimitReached);
      return;
    }
    final draft = await FundSheet.show(context, fund: fund);
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (fund == null) {
        await _repo.createFund(
          creatorId: widget.creatorId,
          name: draft.name,
          description: draft.description.isEmpty ? null : draft.description,
        );
      } else {
        await _repo.updateFund(
          fund.id,
          name: draft.name,
          description: draft.description,
        );
      }
      if (mounted) await _load();
    } catch (e) {
      logger.w('Fund write failed', error: e);
      if (mounted) _say(AppStrings.givingWriteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      appBar: AppBar(
        backgroundColor: AppColors.base1,
        elevation: 0,
        title: Text(AppStrings.givingFundsTitle, style: AppStyles.heading(17)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandPrimary),
            )
          : _failed
          ? ErrorStateView(onRetry: _load, title: AppStrings.givingFailed)
          : RefreshIndicator(
              color: AppColors.brandPrimary,
              backgroundColor: AppColors.base1,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 40.s),
                children: [
                  _periodButton(),
                  SizedBox(height: 14.s),
                  ..._metrics(),
                  SizedBox(height: 10.s),
                  Text(
                    AppStrings.givingGiftsAcross(
                      _summary.giftCount,
                      _summary.donorCount,
                    ),
                    style: AppStyles.label(12, color: AppColors.neutral300),
                  ),
                  SizedBox(height: 24.s),
                  GivingSectionTitle(
                    AppStrings.givingFundsHeading,
                    body: AppStrings.givingFundsBody,
                    trailing: GestureDetector(
                      key: const ValueKey('new-fund'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _busy ? null : () => unawaited(_editFund()),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.s,
                          vertical: 8.s,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.s),
                          border: Border.all(
                            color: _funds.limits.canCreate
                                ? AppColors.brandPrimary
                                : AppColors.neutral700,
                          ),
                        ),
                        child: Text(
                          AppStrings.givingNewFund,
                          style: AppStyles.button(
                            12,
                            color: _funds.limits.canCreate
                                ? AppColors.brandPrimary
                                : AppColors.neutral500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ..._fundRows(),
                  SizedBox(height: 24.s),
                  GivingSectionTitle(
                    AppStrings.givingRecentGifts,
                    trailing: GestureDetector(
                      key: const ValueKey('funds-view-earnings'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GivingEarningsScreen(
                            creatorId: widget.creatorId,
                            repo: widget.repo,
                          ),
                        ),
                      ),
                      child: Text(
                        AppStrings.givingViewEarnings,
                        style: AppStyles.button(
                          12,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                  ..._giftRows(),
                ],
              ),
            ),
    );
  }

  Widget _periodButton() => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(
      key: const ValueKey('funds-period'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_pickPeriod()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _period.label.toUpperCase(),
            style: AppStyles.label(
              12,
              weight: AppStyles.bold,
              color: AppColors.brandPrimary,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(width: 4.s),
          Icon(
            Icons.keyboard_arrow_down,
            size: 16.s,
            color: AppColors.brandPrimary,
          ),
        ],
      ),
    ),
  );

  List<Widget> _metrics() {
    final totals = _summary.primary;
    final held = _summary.withdrawable;
    return [
      GivingMetricCard(
        label: AppStrings.givingGrossGifts,
        amount: totals?.gross,
        hint: AppStrings.givingGrossHint,
        footnote: AppStrings.givingGiftsInPeriod(_summary.giftCount),
      ),
      SizedBox(height: 12.s),
      GivingMetricCard(
        label: AppStrings.givingEstimatedProceeds,
        amount: totals?.creatorNet,
        hint: AppStrings.givingProceedsHint,
        tone: GivingTone.good,
        // Never shortened. An estimate presented as earnings is the one
        // thing the integration guide forbids outright.
        footnote: AppStrings.givingProceedsNote,
      ),
      SizedBox(height: 12.s),
      GivingMetricCard(
        label: AppStrings.givingHeldByProvider,
        hint: AppStrings.givingHeldHint,
        // Null here means the provider could not report it, and the card
        // says so rather than drawing a zero.
        amount: held?.held,
        unavailable: held?.isUnavailable ?? false,
        footnote: held?.provider == null
            ? null
            : AppStrings.givingHeldBy(held!.provider!.label),
      ),
      SizedBox(height: 12.s),
      GivingCountCard(
        label: AppStrings.givingGivers,
        hint: AppStrings.givingGiversHint,
        count: _summary.donorCount,
        footnote: totals == null
            ? null
            : AppStrings.givingPlatformFees(totals.platformFees.display),
      ),
    ];
  }

  List<Widget> _fundRows() {
    if (_funds.funds.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20.s),
          child: Text(
            AppStrings.givingNoFunds,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
        ),
      ];
    }
    return [
      for (final fund in _funds.funds)
        Padding(
          padding: EdgeInsets.only(bottom: 12.s),
          child: GivingFundRow(
            fund: fund,
            onEdit: _busy ? null : () => unawaited(_editFund(fund)),
            onCopyLink: () => unawaited(
              copyAndTell(
                context,
                'https://gospeltube.tv/giving?fund=${fund.slug}',
                AppStrings.givingLinkCopied,
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _giftRows() {
    if (_recent.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.givingNoGifts, style: AppStyles.body(14)),
              SizedBox(height: 6.s),
              Text(
                AppStrings.givingNoGiftsBody,
                style: AppStyles.body(12, color: AppColors.neutral500),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      for (final record in _recent)
        GivingRecordRow(
          record: record,
          dateLabel: givingDateTime(record.createdAt),
        ),
    ];
  }
}
