import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/views/giving_earnings_screen.dart';
import 'package:test_app/features/creator/views/giving_funds_screen.dart';
import 'package:test_app/features/creator/views/giving_rail_screen.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/features/creator/views/widgets/studio_parts.dart';
import 'package:test_app/features/creator/views/widgets/studio_sheets.dart';
import 'package:test_app/models/creator_models/dashboard_models.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Gifts the congregation has entrusted to this ministry, and the paperwork
/// that lets them arrive.
///
/// The tab is one screen with four faces, and which one it shows comes off
/// the application rather than off anything remembered here:
///
/// - **No application at all** — the route answers `{application: null}` —
///   is "not requested", and the hero card offers to start one.
/// - **An application with no rails** is a draft: the recipient is recorded
///   and a provider has still to be enrolled.
/// - **Rails under review** can only be waited on, so the cards say who is
///   reviewing and offer the application rather than a retry.
/// - **An active rail** is the only state that may say gifts are being
///   accepted, which the integration guide is explicit about.
///
/// Two further rules shape the wiring. Enrolling a rail and changing a live
/// one both need an emailed code, so each is a three-step dance — challenge,
/// code, grant — and the grant is spent immediately and never stored. And
/// `application/options` is re-read on every load, because it is current
/// policy and not a permanent capability.
class GivingScreen extends StatefulWidget {
  const GivingScreen({
    super.key,
    this.repo,
    this.context,
    this.studios = const [],
    this.onSwitchStudio,
  });

  final GivingRepo? repo;

  /// Fetched once by the shell and shared by every tab, for the header.
  final DashboardContext? context;

  final List<StudioMembership> studios;
  final Future<void> Function(String creatorId)? onSwitchStudio;

  @override
  State<GivingScreen> createState() => _GivingScreenState();
}

class _GivingScreenState extends State<GivingScreen> {
  late final _repo = widget.repo ?? GivingRepo();

  bool _loading = true;
  bool _failed = false;

  /// Null is a real answer: nothing has been applied for.
  GivingApplication? _application;

  GivingOptions _options = const GivingOptions();

  /// Set while a step-up dance or a write is in flight, so a second tap
  /// cannot start a second challenge against the same rail.
  bool _busy = false;

  String? get _creatorId => widget.context?.creatorId ?? LocalStorage.creatorId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final creatorId = _creatorId;
    if (creatorId == null || creatorId.isEmpty) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // Both at once, and `Future.wait` rather than two awaits so neither
      // failure goes unobserved while the other is still running.
      final results = await Future.wait([
        _repo.fetchApplication(creatorId),
        _repo.fetchOptions(creatorId),
      ]);
      if (!mounted) return;
      setState(() {
        _application = results.first as GivingApplication?;
        _options = results.last as GivingOptions;
        _loading = false;
      });
    } catch (e) {
      logger.w('Giving failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  // ---- Writes ------------------------------------------------------------

  /// "Start giving application" — the legal recipient and the terms.
  ///
  /// No step-up: the grant belongs to rail enrolment, and this call does not
  /// consume one.
  Future<void> _startApplication() async {
    final creatorId = _creatorId;
    if (creatorId == null) return;
    if (_options.isEmpty) {
      _say(AppStrings.givingNoOptions);
      return;
    }
    final details = await TurnOnGivingSheet.show(
      context,
      options: _options,
      initialName: widget.context?.displayName ?? '',
    );
    if (details == null || !mounted) return;
    await _write(
      () => _repo.createApplication(
        creatorId: creatorId,
        classification: details.classification,
        legalRecipientName: details.legalName,
        countryCode: details.countryCode,
        // The server's own current version, never one written into the app.
        termsVersion: _options.termsVersion,
      ),
    );
  }

  /// Enrol a provider: pick the route, prove it is you, then enrol.
  Future<void> _enrol(PaymentProvider provider) async {
    final creatorId = _creatorId;
    if (creatorId == null) return;
    // The same filter the card list used, so the sheet cannot offer a route
    // the tab did not.
    final routes = _options
        .enrollable(
          classification: _application?.legalClassification,
          countryCode: _application?.countryCode,
          enrolled: const [],
        )
        .where((option) => option.provider == provider)
        .toList();
    if (routes.isEmpty) {
      _say(AppStrings.givingNoOptions);
      return;
    }
    final choice = await RailSetupSheet.show(
      context,
      provider: provider,
      options: routes,
    );
    if (choice == null || !mounted) return;

    final grant = await _stepUp(
      creatorId: creatorId,
      operation: 'activate_givings',
      title: AppStrings.givingStepUpTitle(provider.label),
    );
    if (grant == null || !mounted) return;

    await _write(
      () => _repo.enrolRail(
        creatorId: creatorId,
        provider: provider,
        countryCode: choice.countryCode,
        settlementCurrency: choice.settlementCurrency,
        grantToken: grant,
      ),
    );
  }

  /// Change a live rail's country, currency or legal recipient.
  ///
  /// The old configuration keeps taking gifts throughout, so nothing here
  /// tells the creator that giving has stopped.
  Future<void> _updateRail(GivingRail rail) async {
    final creatorId = _creatorId;
    final application = _application;
    if (creatorId == null || application == null) return;
    final change = await UpdateSettlementSheet.show(
      context,
      rail: rail,
      options: _options.items
          .where((option) => option.provider == rail.provider)
          .toList(),
      legalName: application.legalRecipientName,
      classification:
          application.legalClassification ?? LegalClassification.individual,
    );
    if (change == null || !mounted) return;

    final grant = await _stepUp(
      creatorId: creatorId,
      operation: 'change_recipient_configuration',
      title: AppStrings.givingStepUpUpdateTitle(rail.provider?.label ?? ''),
    );
    if (grant == null || !mounted) return;

    await _write(
      () => _repo.requestConfigurationChange(
        creatorId: creatorId,
        railId: rail.id,
        operation: change.operation,
        countryCode: change.countryCode,
        settlementCurrency: change.settlementCurrency,
        classification:
            application.legalClassification ?? LegalClassification.individual,
        legalRecipientName: change.legalName,
        grantToken: grant,
      ),
    );
  }

  /// Take a rail in or out of donor routing.
  ///
  /// This does not touch its verification — it only stops new gifts being
  /// routed through it, and payments already in flight keep reconciling.
  Future<void> _setEnabled(GivingRail rail, bool enabled) async {
    final creatorId = _creatorId;
    if (creatorId == null) return;
    await _write(
      () => _repo.updateRail(rail.id, creatorId: creatorId, enabled: enabled),
    );
  }

  /// Which rail breaks a tie, when two would net the same.
  ///
  /// Lower priority wins, so the chosen rail is moved below the rest rather
  /// than every rail being renumbered.
  Future<void> _setPreferred(GivingRail rail) async {
    final creatorId = _creatorId;
    final rails = _application?.rails ?? const <GivingRail>[];
    if (creatorId == null || rails.isEmpty) return;
    final lowest = rails.map((r) => r.priority).reduce((a, b) => a < b ? a : b);
    if (rail.priority <= lowest) return;
    await _write(
      () => _repo.updateRail(
        rail.id,
        creatorId: creatorId,
        priority: lowest - 10,
      ),
    );
  }

  /// Challenge, code, grant.
  ///
  /// Returns null whenever the creator backs out at any step, and reports a
  /// refusal in one place rather than leaving each caller to.
  Future<String?> _stepUp({
    required String creatorId,
    required String operation,
    required String title,
  }) async {
    setState(() => _busy = true);
    StepUpChallenge challenge;
    try {
      challenge = await _repo.createStepUp(
        creatorId: creatorId,
        operation: operation,
      );
    } catch (e) {
      logger.w('Step-up challenge failed', error: e);
      if (mounted) {
        setState(() => _busy = false);
        _say(AppStrings.givingWriteFailed);
      }
      return null;
    }
    if (mounted) setState(() => _busy = false);
    if (!mounted) return null;

    final code = await StepUpCodeSheet.show(
      context,
      title: title,
      onResend: () => _repo.resendStepUp(challenge.challengeId),
    );
    if (code == null || !mounted) return null;

    setState(() => _busy = true);
    try {
      final grant = await _repo.verifyStepUp(
        challengeId: challenge.challengeId,
        code: code,
      );
      if (grant.isEmpty) throw StateError('no grant');
      return grant;
    } catch (e) {
      logger.w('Step-up verify failed', error: e);
      if (mounted) _say(AppStrings.givingWriteFailed);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Run one write, then re-read.
  ///
  /// Everything here changes server-side state the screen renders in several
  /// places at once, so nothing is applied optimistically: the application
  /// is read back and believed.
  Future<void> _write(Future<Object?> Function() call) async {
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      await _load();
    } catch (e) {
      logger.w('Giving write failed', error: e);
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

  Future<void> _openStudios() async {
    final current = openStudio(widget.context, widget.studios);
    if (current == null) return;
    final choice = await StudiosSheet.show(
      context,
      current: current,
      studios: widget.studios,
    );
    if (!mounted || choice == null) return;
    if (choice.switchTo case final creatorId?) {
      await widget.onSwitchStudio?.call(creatorId);
      if (!mounted) return;
      // The application, the rails and the policy options all belong to the
      // studio that was open, so none of them survives the switch.
      setState(() {
        _application = null;
        _options = const GivingOptions();
      });
      await _load();
    }
  }

  Future<void> _openRail(GivingRail rail) async {
    final creatorId = _creatorId;
    if (creatorId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GivingRailScreen(
          creatorId: creatorId,
          rail: rail,
          application: _application,
        ),
      ),
    );
    if (mounted) await _load();
  }

  // ---- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.base1,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.brandPrimary,
          backgroundColor: AppColors.base1,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 120.s),
            children: [
              _header(),
              SizedBox(height: 16.s),
              Text(
                AppStrings.givingTitle,
                style: AppStyles.heading(28, letterSpacing: -0.8),
              ),
              SizedBox(height: 4.s),
              Text(
                AppStrings.givingSubtitle,
                style: AppStyles.body(13, color: AppColors.neutral400),
              ),
              SizedBox(height: 18.s),
              if (_loading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 80.s),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                )
              else if (_failed)
                ErrorStateView(
                  onRetry: _load,
                  title: AppStrings.givingFailed,
                  showBack: false,
                )
              else
                ..._body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: StudioPill(
          name: openStudio(widget.context, widget.studios)?.displayName ?? '',
          onTap: () => unawaited(_openStudios()),
        ),
      ),
      SizedBox(width: 12.s),
      Container(
        width: 38.s,
        height: 38.s,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.fieldBg,
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedNotification01,
          color: AppColors.textPrimary,
          size: 18.s,
        ),
      ),
    ],
  );

  List<Widget> _body() {
    final application = _application;
    if (application == null) return [_notStarted()];
    return [
      _actions(),
      SizedBox(height: 16.s),
      _recipientCard(application),
      SizedBox(height: 24.s),
      const GivingSectionTitle(
        AppStrings.givingPaymentRails,
        body: AppStrings.givingRailsBody,
      ),
      SizedBox(height: 4.s),
      ..._railCards(application),
      SizedBox(height: 14.s),
      _policyLine(application),
      if (application.rails.where((rail) => rail.enabled).length > 1) ...[
        SizedBox(height: 16.s),
        _tieBreak(application),
      ],
    ];
  }

  /// The hero card, before anything has been applied for.
  Widget _notStarted() => GivingCard(
    padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 28.s),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52.s,
          height: 52.s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x26FFA500),
            borderRadius: BorderRadius.circular(12.s),
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedGift,
            color: AppColors.brandPrimary,
            size: 24.s,
          ),
        ),
        SizedBox(height: 16.s),
        Text(
          AppStrings.givingNotStartedTitle,
          textAlign: TextAlign.center,
          style: AppStyles.heading(18),
        ),
        SizedBox(height: 8.s),
        Text(
          AppStrings.givingNotStartedBody,
          textAlign: TextAlign.center,
          style: AppStyles.body(
            12,
            color: AppColors.neutral400,
            lineHeight: 18 / 12,
          ),
        ),
        SizedBox(height: 18.s),
        GestureDetector(
          key: const ValueKey('giving-start'),
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : () => unawaited(_startApplication()),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 22.s, vertical: 12.s),
            decoration: BoxDecoration(
              gradient: AppStyles.primaryButtonGradient,
              borderRadius: BorderRadius.circular(999.s),
            ),
            child: Text(
              AppStrings.givingStartApplication,
              style: AppStyles.button(13),
            ),
          ),
        ),
        SizedBox(height: 18.s),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14.s,
          runSpacing: 6.s,
          children: [
            for (final step in const [
              AppStrings.givingStep1,
              AppStrings.givingStep2,
              AppStrings.givingStep3,
            ])
              Text(
                step,
                style: AppStyles.label(10, color: AppColors.neutral500),
              ),
          ],
        ),
      ],
    ),
  );

  /// The two ways out of this tab.
  ///
  /// Both are live as soon as an application exists: the reporting routes
  /// refuse before that and answer for an empty studio after it.
  Widget _actions() => Row(
    children: [
      Expanded(
        child: GestureDetector(
          key: const ValueKey('giving-earnings'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _push(
            GivingEarningsScreen(
              creatorId: _creatorId ?? '',
              repo: widget.repo,
            ),
          ),
          child: Container(
            height: 40.s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppStyles.primaryButtonGradient,
              borderRadius: BorderRadius.circular(999.s),
            ),
            child: Text(
              AppStrings.givingViewEarnings,
              style: AppStyles.button(13),
            ),
          ),
        ),
      ),
      SizedBox(width: 10.s),
      Expanded(
        child: GestureDetector(
          key: const ValueKey('giving-funds'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _push(
            GivingFundsScreen(creatorId: _creatorId ?? '', repo: widget.repo),
          ),
          child: Container(
            height: 40.s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999.s),
              border: Border.all(color: AppColors.brandPrimary),
            ),
            child: Text(
              AppStrings.givingFundsAndPerformance,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.button(12, color: AppColors.brandPrimary),
            ),
          ),
        ),
      ),
    ],
  );

  void _push(Widget screen) {
    unawaited(
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((
        _,
      ) {
        if (mounted) unawaited(_load());
      }),
    );
  }

  /// Who is being paid, and whether anything is yet reaching them.
  Widget _recipientCard(GivingApplication application) => GivingCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedUser,
              color: AppColors.neutral300,
              size: 16.s,
            ),
            SizedBox(width: 8.s),
            Flexible(
              child: Text(
                application.legalRecipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(14, weight: AppStyles.bold),
              ),
            ),
            SizedBox(width: 8.s),
            GivingStatusPill(
              label: application.status.label,
              tone: toneFor(application.status),
            ),
          ],
        ),
        SizedBox(height: 8.s),
        Text(
          AppStrings.givingRecipientLine(
            application.legalClassification?.label ?? '',
            givingCountryName(application.countryCode),
            givingDate(application.termsAcceptedAt),
          ),
          style: AppStyles.label(
            11,
            color: AppColors.neutral500,
            lineHeight: 15 / 11,
          ),
        ),
        SizedBox(height: 6.s),
        Text(
          // The one line that must never overstate: a rail short of active
          // is not accepting anything.
          application.isAcceptingGifts
              ? AppStrings.givingAccepting
              : AppStrings.givingNotAccepting,
          style: AppStyles.label(
            11,
            color: application.isAcceptingGifts
                ? AppColors.green500
                : AppColors.neutral500,
          ),
        ),
        SizedBox(height: 14.s),
        GestureDetector(
          key: const ValueKey('giving-copy-link'),
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(_copyGivingLink()),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 9.s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.s),
              border: Border.all(color: AppColors.brandPrimary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCopy01,
                  color: AppColors.brandPrimary,
                  size: 14.s,
                ),
                SizedBox(width: 8.s),
                Text(
                  AppStrings.givingCopyLink,
                  style: AppStyles.button(12, color: AppColors.brandPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  /// The stable channel link a giver can be sent to.
  Future<void> _copyGivingLink() async {
    final handle = openStudio(widget.context, widget.studios)?.handle ?? '';
    await copyAndTell(
      context,
      'https://gospeltube.tv/@$handle?give=${GivingFund.generalSlug}',
      AppStrings.givingLinkCopied,
    );
  }

  /// One card per enrolled rail, then one per provider still on offer.
  List<Widget> _railCards(GivingApplication application) {
    final enrolled = application.rails;
    final offered = _options
        .enrollable(
          classification: application.legalClassification,
          countryCode: application.countryCode,
          enrolled: enrolled.map((rail) => rail.provider),
        )
        .map((option) => option.provider)
        .whereType<PaymentProvider>()
        .toSet();

    return [
      for (final rail in enrolled)
        Padding(
          padding: EdgeInsets.only(bottom: 12.s),
          child: GivingRailCard(
            rail: rail,
            actionLabel: rail.status.isActive
                ? AppStrings.givingUpdateAccount
                : rail.status.needsCreator
                ? AppStrings.givingContinueProvider(rail.provider?.label ?? '')
                : AppStrings.givingViewApplication,
            busy: _busy,
            onAction: () => unawaited(
              rail.status.isActive ? _updateRail(rail) : _openRail(rail),
            ),
            onDetails: () => unawaited(_openRail(rail)),
            onToggleEnabled: rail.status.isActive
                ? (value) => unawaited(_setEnabled(rail, value))
                : null,
          ),
        ),
      for (final provider in offered)
        Padding(
          padding: EdgeInsets.only(bottom: 12.s),
          child: _OfferCard(
            provider: provider,
            busy: _busy,
            onSetup: () => unawaited(_enrol(provider)),
          ),
        ),
    ];
  }

  /// The small print under the rails: what this recipient is, and the one
  /// thing a creator most often gets wrong about rails.
  ///
  /// Deliberately **not** [AppStrings.givingRailsBody] — that already sits
  /// under the section heading a few hundred pixels above, and printing it
  /// twice on one screen reads as a rendering fault.
  Widget _policyLine(GivingApplication application) => Text(
    '${application.legalClassification?.label ?? ''} · '
    '${givingCountryName(application.countryCode)}. '
    '${AppStrings.givingCurrencyNotProvider}',
    style: AppStyles.label(
      10,
      color: AppColors.neutral500,
      lineHeight: 14 / 10,
    ),
  );

  /// Which rail wins when two would pay the same.
  Widget _tieBreak(GivingApplication application) {
    final rails = application.rails.where((rail) => rail.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return GivingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.givingTieBreakTitle, style: AppStyles.heading(14)),
          SizedBox(height: 6.s),
          Text(
            AppStrings.givingTieBreakBody,
            style: AppStyles.body(
              11,
              color: AppColors.neutral500,
              lineHeight: 16 / 11,
            ),
          ),
          SizedBox(height: 12.s),
          Text(
            AppStrings.givingPreferredRail,
            style: AppStyles.label(11, color: AppColors.neutral400),
          ),
          SizedBox(height: 6.s),
          GestureDetector(
            key: const ValueKey('giving-preferred-rail'),
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : () => unawaited(_pickPreferred(rails)),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
              decoration: BoxDecoration(
                color: AppColors.brandAltDark,
                borderRadius: BorderRadius.circular(8.s),
                border: Border.all(color: AppColors.neutral700),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rails.first.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.body(13),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16.s,
                    color: AppColors.neutral400,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPreferred(List<GivingRail> rails) async {
    final picked = await GivingPickerSheet.show<GivingRail>(
      context,
      title: AppStrings.givingPreferredRail,
      options: rails,
      labelOf: (rail) => rail.label,
      selected: rails.first,
    );
    if (picked == null || !mounted) return;
    await _setPreferred(picked);
  }
}

/// A provider that may be enrolled but has not been.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.provider,
    required this.onSetup,
    this.busy = false,
  });

  final PaymentProvider provider;
  final VoidCallback onSetup;
  final bool busy;

  @override
  Widget build(BuildContext context) => GivingCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ProviderMark(provider),
            SizedBox(width: 10.s),
            Expanded(child: Text(provider.label, style: AppStyles.heading(16))),
            const GivingStatusPill(label: AppStrings.railDraft),
          ],
        ),
        SizedBox(height: 10.s),
        Text(
          provider == PaymentProvider.khaime
              ? AppStrings.givingVerifyHere
              : AppStrings.givingVerifyOnProvider,
          style: AppStyles.body(
            12,
            color: AppColors.neutral400,
            lineHeight: 17 / 12,
          ),
        ),
        SizedBox(height: 8.s),
        Text(
          provider == PaymentProvider.khaime
              ? AppStrings.givingKhaimeFormBody
              : AppStrings.givingProviderFormBody,
          style: AppStyles.body(
            12,
            color: AppColors.neutral500,
            lineHeight: 17 / 12,
          ),
        ),
        SizedBox(height: 14.s),
        GestureDetector(
          key: ValueKey('setup-${provider.wire}'),
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : onSetup,
          child: Container(
            height: 38.s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.s),
              border: Border.all(color: AppColors.neutral700),
            ),
            child: Text(
              AppStrings.givingSetupProvider(provider.label),
              style: AppStyles.button(12),
            ),
          ),
        ),
      ],
    ),
  );
}
