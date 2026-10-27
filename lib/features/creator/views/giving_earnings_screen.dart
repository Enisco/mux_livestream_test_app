import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/views/giving_funds_screen.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What has arrived, what is still held, and the only place a withdrawal
/// can be asked for.
///
/// The card at the top is the part that has to be read carefully, because
/// the two kinds of rail behave differently and the difference is real
/// money:
///
/// - A **direct** rail (Stripe, Paystack) is settled by its PSP on the PSP's
///   own schedule. There is nothing to withdraw, and the screen says so
///   rather than showing a disabled button that looks like a bug.
/// - A **provider-held** rail (Khaime) accumulates a balance that is paid
///   out only when the creator asks. Withdraw is offered only while
///   `availability` is `withdrawable`, and is disabled outright while a
///   request is already in flight — the server refuses a second one, so the
///   in-flight amount is shown instead of letting a creator submit and fail.
///
/// A balance the provider could not report is said out loud. It is never
/// rendered as a zero, which would read as "your money is gone".
class GivingEarningsScreen extends StatefulWidget {
  const GivingEarningsScreen({super.key, required this.creatorId, this.repo});

  final String creatorId;
  final GivingRepo? repo;

  @override
  State<GivingEarningsScreen> createState() => _GivingEarningsScreenState();
}

/// The four lists under the overview.
enum EarningsTab {
  gifts(AppStrings.earningsTabGifts),
  settlements(AppStrings.earningsTabSettlements),
  payouts(AppStrings.earningsTabPayouts),
  refunds(AppStrings.earningsTabRefunds);

  const EarningsTab(this.label);

  final String label;
}

class _GivingEarningsScreenState extends State<GivingEarningsScreen> {
  late final _repo = widget.repo ?? GivingRepo();

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  bool _loadingRows = false;

  GivingPeriod _period = GivingPeriod.last30;
  EarningsTab _tab = EarningsTab.gifts;

  /// Null is "all funds", which is the filter's default.
  GivingFund? _fund;

  EarningsSummary _summary = const EarningsSummary();
  GivingFundList _funds = const GivingFundList();
  List<GivingRecord> _rows = const [];
  String? _cursor;

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
    try {
      final results = await Future.wait([
        _repo.fetchSummary(
          widget.creatorId,
          from: _period.from(DateTime.now()),
          fundId: _fund?.id,
        ),
        _repo.fetchFunds(widget.creatorId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results.first as EarningsSummary;
        _funds = results.last as GivingFundList;
        _loading = false;
      });
      await _loadRows();
    } catch (e) {
      logger.w('Earnings failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// How many further pages the refunds tab will pull through before it
  /// gives up and says there is nothing.
  ///
  /// Refunds have no route of their own: they are transactions whose refund
  /// state has moved, filtered here. So a full page can contain none while
  /// plenty exist further back, and stopping at the first page would tell a
  /// creator they have had no refunds when they have. Bounded, because the
  /// alternative is walking a year of gifts on one tap.
  static const _refundLookahead = 4;

  /// The list under the overview, which changes with the tab as well as the
  /// filters — so the cursor is dropped whenever any of them moves.
  Future<void> _loadRows({bool more = false}) async {
    if (_loadingRows) return;
    setState(() => _loadingRows = true);
    final from = _period.from(DateTime.now());
    try {
      var looked = 0;
      var page = await _page(from, more: more);
      var items = _tab == EarningsTab.refunds
          ? page.items.where(_isRefund).toList()
          : page.items;
      while (_tab == EarningsTab.refunds &&
          items.isEmpty &&
          page.nextCursor != null &&
          looked < _refundLookahead) {
        looked++;
        _cursor = page.nextCursor;
        page = await _page(from, more: true);
        items = page.items.where(_isRefund).toList();
      }
      if (!mounted) return;
      setState(() {
        _rows = more ? [..._rows, ...items] : items;
        _cursor = page.nextCursor;
        _loadingRows = false;
      });
    } catch (e) {
      logger.w('Earnings rows failed', error: e);
      if (mounted) setState(() => _loadingRows = false);
    }
  }

  Future<GivingRecordPage> _page(DateTime? from, {required bool more}) async {
    return switch (_tab) {
      EarningsTab.gifts || EarningsTab.refunds => _repo.fetchTransactions(
        widget.creatorId,
        from: from,
        fundId: _fund?.id,
        cursor: more ? _cursor : null,
      ),
      EarningsTab.settlements => _repo.fetchSettlements(
        widget.creatorId,
        from: from,
        fundId: _fund?.id,
        cursor: more ? _cursor : null,
      ),
      EarningsTab.payouts => _repo.fetchPayouts(
        widget.creatorId,
        from: from,
        fundId: _fund?.id,
        cursor: more ? _cursor : null,
      ),
    };
  }

  static bool _isRefund(GivingRecord record) =>
      record.status == 'refunded' || record.status == 'partially_refunded';

  Future<void> _switchTab(EarningsTab tab) async {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _rows = const [];
      _cursor = null;
    });
    await _loadRows();
  }

  /// Ask for part of a provider-held balance.
  Future<void> _requestPayout(RailFunds rail) async {
    final available = rail.available;
    if (available == null) return;
    final amountMinor = await PayoutSheet.show(context, available: available);
    if (amountMinor == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.requestPayout(
        creatorId: widget.creatorId,
        amountMinor: amountMinor,
        railId: rail.railId,
        currency: rail.settlementCurrency,
      );
      if (!mounted) return;
      _say(AppStrings.earningsPayoutRequested);
      // Re-read rather than working the new balance out here: a withdrawal
      // is covered oldest gift first and may take a settlement in part.
      await _load();
    } catch (e) {
      logger.w('Payout request failed', error: e);
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
        title: Text(AppStrings.earningsTitle, style: AppStyles.heading(17)),
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
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final metrics = notification.metrics;
                  if (metrics.axis == Axis.vertical &&
                      metrics.extentAfter < 400 &&
                      _cursor != null &&
                      !_loadingRows) {
                    unawaited(_loadRows(more: true));
                  }
                  return false;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 40.s),
                  children: [
                    ..._balanceCards(),
                    SizedBox(height: 14.s),
                    Text(
                      AppStrings.earningsProviderNote,
                      style: AppStyles.label(
                        10,
                        color: AppColors.neutral500,
                        lineHeight: 14 / 10,
                      ),
                    ),
                    SizedBox(height: 24.s),
                    Text(
                      AppStrings.earningsOverview,
                      style: AppStyles.heading(17),
                    ),
                    SizedBox(height: 12.s),
                    _filters(),
                    SizedBox(height: 14.s),
                    ..._overview(),
                    SizedBox(height: 22.s),
                    LibraryFilterChips(
                      labels: [for (final tab in EarningsTab.values) tab.label],
                      selected: _tab.label,
                      onSelected: (label) => unawaited(
                        _switchTab(
                          EarningsTab.values.firstWhere(
                            (tab) => tab.label == label,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.s),
                    ..._rowList(),
                  ],
                ),
              ),
            ),
    );
  }

  /// One card per rail, each saying what it can honestly say about itself.
  List<Widget> _balanceCards() {
    if (!_summary.hasRails) {
      // No rail is a different thing from a rail whose provider went quiet,
      // and saying the provider failed would be a lie about the provider.
      return [
        GivingCard(
          child: Text(
            AppStrings.earningsNoRail,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
        ),
      ];
    }
    return [
      for (final rail in _summary.fundsByRail)
        Padding(
          padding: EdgeInsets.only(bottom: 12.s),
          child: _RailBalanceCard(
            rail: rail,
            busy: _busy,
            onWithdraw: () => unawaited(_requestPayout(rail)),
          ),
        ),
    ];
  }

  Widget _filters() => Row(
    children: [
      Expanded(
        child: _FilterField(
          key: const ValueKey('earnings-fund'),
          label: AppStrings.earningsGivingFunds,
          value: _fund?.name ?? AppStrings.earningsAllFunds,
          onTap: _pickFund,
        ),
      ),
      SizedBox(width: 12.s),
      Expanded(
        child: _FilterField(
          key: const ValueKey('earnings-period'),
          label: AppStrings.earningsPeriod,
          value: _period.label,
          onTap: _pickPeriod,
        ),
      ),
    ],
  );

  Future<void> _pickFund() async {
    // "All funds" is a real choice, so it cannot be modelled as a null
    // result: the picker returns null when it is dismissed too, and reading
    // that as "all funds" silently threw away the filter a creator had set.
    // Each row is wrapped, and only an unwrapped null means "cancelled".
    final options = <_FundChoice>[
      const _FundChoice(null),
      for (final fund in _funds.funds) _FundChoice(fund),
    ];
    final picked = await GivingPickerSheet.show<_FundChoice>(
      context,
      title: AppStrings.earningsGivingFunds,
      options: options,
      labelOf: (choice) => choice.fund?.name ?? AppStrings.earningsAllFunds,
      selected: _FundChoice(_fund),
    );
    if (picked == null || !mounted || picked.fund?.id == _fund?.id) return;
    setState(() {
      _fund = picked.fund;
      _rows = const [];
      _cursor = null;
    });
    await _load();
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
    setState(() {
      _period = picked;
      _rows = const [];
      _cursor = null;
    });
    await _load();
  }

  List<Widget> _overview() {
    final totals = _summary.primary;
    final held = _summary.withdrawable;
    return [
      GivingMetricCard(
        label: AppStrings.givingGrossGifts,
        amount: totals?.gross,
        hint: AppStrings.givingGrossHint,
        footnote: AppStrings.givingGiftsAcross(
          _summary.giftCount,
          _summary.donorCount,
        ),
      ),
      SizedBox(height: 12.s),
      GivingMetricCard(
        label: AppStrings.givingEstimatedProceeds,
        amount: totals?.creatorNet,
        hint: AppStrings.givingProceedsHint,
        tone: GivingTone.good,
        footnote: AppStrings.earningsCapturedFromQuotes,
      ),
      SizedBox(height: 12.s),
      GivingMetricCard(
        label: AppStrings.givingHeldByProvider,
        amount: held?.held,
        hint: AppStrings.givingHeldHint,
        unavailable: held?.isUnavailable ?? false,
        footnote: held?.provider == null
            ? null
            : AppStrings.givingHeldBy(held!.provider!.label),
      ),
      SizedBox(height: 12.s),
      GivingMetricCard(
        label: AppStrings.earningsReleasedToYou,
        amount: held?.released,
        unavailable: held?.isUnavailable ?? false,
        tone: GivingTone.good,
        footnote: held?.provider == null
            ? null
            : AppStrings.earningsReleasedBy(held!.provider!.label),
      ),
    ];
  }

  List<Widget> _rowList() {
    if (_rows.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28.s),
          child: Text(
            AppStrings.earningsNoRows,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
        ),
      ];
    }
    return [
      for (final record in _rows)
        GivingRecordRow(
          record: record,
          dateLabel: givingDateTime(record.createdAt),
        ),
      if (_loadingRows)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20.s),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.brandPrimary),
          ),
        ),
    ];
  }
}

/// One rail's balance, and whether anything can be done with it.
class _RailBalanceCard extends StatelessWidget {
  const _RailBalanceCard({
    required this.rail,
    required this.onWithdraw,
    this.busy = false,
  });

  final RailFunds rail;
  final VoidCallback onWithdraw;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final provider = rail.provider?.label ?? '';
    final unavailable = rail.availability == FundsAvailability.notAvailable;
    return GivingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ProviderMark(rail.provider, size: 30),
              SizedBox(width: 10.s),
              Expanded(
                child: Text(
                  rail.custodyMode.isProviderHeld
                      ? AppStrings.earningsHeldFunds(
                          provider,
                          rail.settlementCurrency,
                        )
                      : '$provider — ${rail.settlementCurrency}',
                  maxLines: 2,
                  style: AppStyles.label(13, weight: AppStyles.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.s),
          Text(
            AppStrings.earningsAvailable,
            style: AppStyles.label(11, color: AppColors.neutral400),
          ),
          SizedBox(height: 4.s),
          Text(
            // `not_available` is a statement, not a zero.
            unavailable
                ? AppStrings.earningsBalanceUnavailable
                : rail.available?.display ??
                      AppStrings.earningsBalanceUnavailable,
            style: unavailable || rail.available == null
                ? AppStyles.body(13, color: AppColors.neutral400)
                : AppStyles.heading(24, color: AppColors.green500),
          ),
          if (rail.nextReleaseAt case final next?) ...[
            SizedBox(height: 6.s),
            Text(
              AppStrings.earningsNextRelease(givingDate(next)),
              style: AppStyles.label(11, color: AppColors.green500),
            ),
          ],
          if (rail.held case final held?) ...[
            SizedBox(height: 12.s),
            Row(
              children: [
                Text(
                  AppStrings.earningsHolding,
                  style: AppStyles.label(11, color: AppColors.neutral400),
                ),
                const Spacer(),
                Text(held.display, style: AppStyles.label(12)),
              ],
            ),
          ],
          SizedBox(height: 14.s),
          if (!rail.custodyMode.isProviderHeld)
            // A direct rail has no withdrawal at all, which is a property of
            // the rail rather than a temporary state — so it is explained,
            // not disabled.
            Text(
              AppStrings.earningsNoWithdrawal,
              style: AppStyles.label(
                11,
                color: AppColors.neutral500,
                lineHeight: 15 / 11,
              ),
            )
          else if (rail.pendingPayout case final inFlight?)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const GivingStatusPill(
                  label: AppStrings.earningsPayoutInFlight,
                  tone: GivingTone.pending,
                ),
                SizedBox(height: 8.s),
                Text(
                  AppStrings.earningsPayoutPending(inFlight.display),
                  style: AppStyles.label(
                    11,
                    color: AppColors.neutral500,
                    lineHeight: 15 / 11,
                  ),
                ),
              ],
            )
          else
            PrimaryButton(
              key: ValueKey('withdraw-${rail.railId}'),
              label: AppStrings.earningsRequestPayout,
              enabled: rail.canWithdraw && !busy,
              onPressed: onWithdraw,
            ),
        ],
      ),
    );
  }
}

/// One row of the fund filter, so that "All funds" is a value rather than
/// the absence of one.
class _FundChoice {
  const _FundChoice(this.fund);

  final GivingFund? fund;

  @override
  bool operator ==(Object other) =>
      other is _FundChoice && other.fund?.id == fund?.id;

  @override
  int get hashCode => fund?.id.hashCode ?? 0;
}

/// A labelled dropdown in the overview's filter row.
class _FilterField extends StatelessWidget {
  const _FilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: AppStyles.label(11, color: AppColors.neutral400)),
      SizedBox(height: 6.s),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(onTap()),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 11.s),
          decoration: BoxDecoration(
            color: AppColors.brandAltDark,
            borderRadius: BorderRadius.circular(8.s),
            border: Border.all(color: AppColors.neutral700),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.body(12),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14.s,
                color: AppColors.neutral400,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
