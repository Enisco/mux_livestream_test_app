import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/views/giving_kyc_screen.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// One rail: how far it has got, what it is settling to, and what is still
/// outstanding.
///
/// The screen's shape follows the one rule the integration guide repeats
/// most insistently: **GospelTube's review and the provider's run
/// independently.** Either can be started first and neither is hidden behind
/// the other, so both tracks are shown side by side with their own actions.
/// Collapsing them into one progress bar would make a creator wait on a
/// reviewer when the thing actually blocking them is a form at the provider.
///
/// Everything here is read, not remembered. A rail's requirements can change
/// when a re-verification or a configuration change selects a newer policy,
/// so this screen re-reads them each time it opens rather than trusting the
/// rail it was handed.
class GivingRailScreen extends StatefulWidget {
  const GivingRailScreen({
    super.key,
    required this.creatorId,
    required this.rail,
    this.application,
    this.repo,
  });

  final String creatorId;
  final GivingRail rail;

  /// For the legal recipient and classification, which belong to the
  /// application rather than to any one rail.
  final GivingApplication? application;

  final GivingRepo? repo;

  @override
  State<GivingRailScreen> createState() => _GivingRailScreenState();
}

class _GivingRailScreenState extends State<GivingRailScreen> {
  late final _repo = widget.repo ?? GivingRepo();

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  late GivingRail _rail = widget.rail;
  RailRequirements? _requirements;

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
        _repo.fetchRequirements(
          creatorId: widget.creatorId,
          railId: widget.rail.id,
        ),
        _repo.fetchApplication(widget.creatorId),
      ]);
      if (!mounted) return;
      final application = results.last as GivingApplication?;
      setState(() {
        _requirements = results.first as RailRequirements;
        // The rail passed in is a snapshot from the tab behind this screen;
        // the fresh read is what the actions are decided from.
        _rail =
            application?.rails.firstWhere(
              (rail) => rail.id == widget.rail.id,
              orElse: () => _rail,
            ) ??
            _rail;
        _loading = false;
      });
    } catch (e) {
      logger.w('Rail requirements failed', error: e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Hand GospelTube's half over for review.
  ///
  /// This marks only that track as submitted. If the provider is already
  /// ready the backend moves the whole application on; if it is not, the
  /// rail stays gated, and nothing here pretends otherwise.
  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await _repo.submitApplication(
        creatorId: widget.creatorId,
        railId: _rail.id,
      );
      if (!mounted) return;
      _say(AppStrings.givingSubmitted);
      await _load();
    } catch (e) {
      logger.w('Submit failed', error: e);
      if (mounted) _say(AppStrings.givingWriteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Continue at the provider.
  ///
  /// Khaime's form is rendered by the app; Stripe and Paystack are the
  /// provider's own flows, which this build does not host, so each says
  /// where the work has to happen instead of opening a dead end.
  Future<void> _continueProvider() async {
    if (_rail.managementMode == RailManagementMode.khaimeKycForm ||
        _rail.provider == PaymentProvider.khaime) {
      final done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GivingKycScreen(
            creatorId: widget.creatorId,
            rail: _rail,
            application: widget.application,
            requirements: _requirements,
            repo: widget.repo,
          ),
        ),
      );
      if (done == true && mounted) await _load();
      return;
    }
    _say(AppStrings.givingProviderFormBody);
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
    final provider = _rail.provider?.label ?? '';
    return Scaffold(
      backgroundColor: AppColors.base1,
      appBar: AppBar(
        backgroundColor: AppColors.base1,
        elevation: 0,
        title: Text(
          AppStrings.givingRailTitle(provider),
          style: AppStyles.heading(16),
        ),
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
                padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 32.s),
                children: [
                  _heading(provider),
                  SizedBox(height: 20.s),
                  const GivingSectionTitle(
                    AppStrings.givingVerificationTracks,
                    body: AppStrings.givingVerificationTracksBody,
                  ),
                  _trackCard(
                    key: const ValueKey('track-gospeltube'),
                    title: AppStrings.givingGospelTubeVerification,
                    requirements:
                        _ownedBy(RequirementOwner.gospeltube) +
                        _ownedBy(RequirementOwner.creator),
                    action: _canSubmit
                        ? AppStrings.givingSubmitForReview
                        : null,
                    onAction: _submit,
                  ),
                  SizedBox(height: 12.s),
                  _trackCard(
                    key: const ValueKey('track-provider'),
                    title: AppStrings.givingProviderVerification,
                    requirements: _ownedBy(RequirementOwner.provider),
                    action: _rail.status.isActive
                        ? null
                        : AppStrings.givingContinueProvider(provider),
                    onAction: _continueProvider,
                  ),
                  SizedBox(height: 24.s),
                  const GivingSectionTitle(AppStrings.givingRailDetails),
                  ..._details(provider),
                  SizedBox(height: 14.s),
                  Text(
                    AppStrings.givingLockedNote,
                    style: AppStyles.label(
                      10,
                      color: AppColors.neutral500,
                      lineHeight: 14 / 10,
                    ),
                  ),
                  SizedBox(height: 24.s),
                  const GivingSectionTitle(AppStrings.givingReviewChecklist),
                  ..._checklist(),
                  SizedBox(height: 24.s),
                  PrimaryButton(
                    key: const ValueKey('rail-done'),
                    label: AppStrings.givingDone,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
    );
  }

  List<RailRequirement> _ownedBy(RequirementOwner owner) =>
      (_requirements?.requirements ?? const <RailRequirement>[])
          .where((requirement) => requirement.owner == owner)
          .toList();

  /// Whether this rail is still the creator's move.
  ///
  /// Read off the rail's **status**, not off the requirement list. Gating on
  /// "the creator has something outstanding" looked right and was backwards
  /// in two ways: it hid the button at the one moment it is wanted — when
  /// everything has been supplied — and a rail whose case lists no
  /// requirements at all could never be submitted. An unknown status parses
  /// as `collecting_information`, so the button fails towards being offered.
  bool get _canSubmit => _rail.status.needsCreator;

  Widget _heading(String provider) {
    final hold = _rail.holdDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(provider, style: AppStyles.heading(20)),
            SizedBox(width: 10.s),
            GivingStatusPill(
              label: _rail.status.label,
              tone: toneFor(_rail.status),
            ),
          ],
        ),
        SizedBox(height: 8.s),
        Text(
          _rail.custodyMode.isProviderHeld && hold != null
              ? AppStrings.givingHoldNote(provider, hold)
              : AppStrings.givingDirectNote(provider),
          style: AppStyles.body(
            12,
            color: AppColors.neutral400,
            lineHeight: 17 / 12,
          ),
        ),
      ],
    );
  }

  /// One verification track, with whatever it is still waiting on.
  Widget _trackCard({
    required Key key,
    required String title,
    required List<RailRequirement> requirements,
    required String? action,
    required Future<void> Function() onAction,
  }) {
    final outstanding = requirements.where((r) => !r.isSatisfied).toList();
    final complete = requirements.isNotEmpty && outstanding.isEmpty;
    return GivingCard(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppStyles.heading(14))),
              GivingStatusPill(
                label: complete
                    ? AppStrings.givingTrackCompleted
                    : requirements.isEmpty
                    ? AppStrings.railPlatformReview
                    : AppStrings.railCollecting,
                tone: complete ? GivingTone.good : GivingTone.pending,
              ),
            ],
          ),
          if (outstanding.isNotEmpty) ...[
            SizedBox(height: 10.s),
            for (final requirement in outstanding)
              Padding(
                padding: EdgeInsets.only(bottom: 4.s),
                child: Text(
                  '• ${requirement.label.isEmpty ? requirement.code : requirement.label}'
                  ' — ${requirement.owner.label}',
                  style: AppStyles.label(
                    11,
                    color: AppColors.neutral400,
                    lineHeight: 16 / 11,
                  ),
                ),
              ),
          ],
          if (action case final label?) ...[
            SizedBox(height: 14.s),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _busy ? null : () => unawaited(onAction()),
              child: Container(
                height: 38.s,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.s),
                  border: Border.all(color: AppColors.neutral700),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.button(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _details(String provider) {
    final application = widget.application;
    final hold = _rail.holdDays;
    final account = _rail.settlementAccountLast4;
    return [
      GivingDetailRow(
        label: AppStrings.givingRailLegalRecipient,
        value:
            _rail.legalRecipientName ?? application?.legalRecipientName ?? '—',
      ),
      GivingDetailRow(
        label: AppStrings.givingRailLegalStructure,
        value: application?.legalClassification?.label ?? '—',
      ),
      GivingDetailRow(
        label: AppStrings.givingRailSettlementRoute,
        value:
            '${givingCountryName(_rail.countryCode)} · '
            '${_rail.settlementCurrency}',
      ),
      GivingDetailRow(label: AppStrings.givingRailProvider, value: provider),
      GivingDetailRow(
        label: AppStrings.givingRailCustody,
        value: _rail.custodyMode.isProviderHeld && hold != null
            ? AppStrings.givingCustodyHeld(hold)
            : AppStrings.givingCustodyDirect,
      ),
      if (_rail.submittedAt != null)
        GivingDetailRow(
          label: AppStrings.givingRailSubmitted,
          value: givingDateTime(_rail.submittedAt),
        ),
      if (account != null)
        GivingDetailRow(
          label: AppStrings.givingRailSettlementAccount,
          // Only ever the last four. The full number is forwarded to the
          // provider and never stored, so there is nothing else to show.
          value: [?_rail.settlementAccountName, '•••• $account'].join(' · '),
        ),
      if (_rail.settlementAccountHolder case final holder?)
        GivingDetailRow(
          label: AppStrings.givingRailAccountHolder,
          value: holder,
        ),
      if (_rail.accountOwnership case final ownership?)
        GivingDetailRow(
          label: AppStrings.givingRailAccountOwnership,
          value: ownership,
        ),
    ];
  }

  List<Widget> _checklist() {
    final requirements = _requirements?.requirements ?? const [];
    if (requirements.isEmpty) {
      return [
        Text(
          AppStrings.givingNoChecklist,
          style: AppStyles.body(
            12,
            color: AppColors.neutral500,
            lineHeight: 17 / 12,
          ),
        ),
      ];
    }
    return [
      for (final requirement in requirements)
        GivingChecklistRow(requirement: requirement, busy: _busy),
    ];
  }
}
