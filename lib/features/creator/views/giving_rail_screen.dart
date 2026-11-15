import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/services/giving_evidence_upload.dart';
import 'package:test_app/features/creator/views/giving_kyc_screen.dart';
import 'package:test_app/features/creator/views/giving_paystack_screen.dart';
import 'package:test_app/features/creator/views/giving_stripe_screen.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/busy_barrier.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// One rail: how far it has got, what it is settling to, and what is still
/// outstanding.
class GivingRailScreen extends StatefulWidget {
  const GivingRailScreen({
    super.key,
    required this.creatorId,
    required this.rail,
    this.application,
    this.repo,
    this.api,
    this.send,
  });

  final String creatorId;
  final GivingRail rail;

  /// For the legal recipient and classification, which belong to the
  /// application rather than to any one rail.
  final GivingApplication? application;

  final GivingRepo? repo;

  /// The evidence upload is a three-leg sequence rather than a repo call,
  /// so it takes the client and the S3 leg directly — and passes both on to
  /// the Khaime form, which uploads the same documents.
  final ApiService? api;
  final S3Send? send;

  @override
  State<GivingRailScreen> createState() => _GivingRailScreenState();
}

class _GivingRailScreenState extends State<GivingRailScreen> {
  late final _repo = widget.repo ?? GivingRepo();

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  /// Which evidence type is uploading, so only that row spins and a second
  /// pick is refused while the first is still going.
  String? _uploadingType;

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
  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await runBusy(
        context,
        () => _repo.submitApplication(
          creatorId: widget.creatorId,
          railId: _rail.id,
        ),
        message: AppStrings.givingWorking,
      );
      if (!mounted) return;
      _say(AppStrings.givingSubmitted);
      await _load();
    } catch (e) {
      logger.w('Submit failed', error: e);
      // The refusal names the documents it is still waiting on, one per
      // line. That is the creator's next step, so it is shown.
      if (mounted) _say(givingProblem(e) ?? AppStrings.givingWriteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Supply one of the documents GospelTube's review is waiting on.
  Future<void> _uploadEvidence(RailRequirement requirement) async {
    final evidenceType = requirement.evidenceType;
    if (evidenceType == null || _uploadingType != null) return;
    final result = await pickAndAttachEvidence(
      creatorId: widget.creatorId,
      railId: _rail.id,
      evidenceType: evidenceType,
      api: widget.api,
      send: widget.send,
      onPicked: () {
        if (mounted) setState(() => _uploadingType = evidenceType);
      },
    );
    if (!mounted) return;
    setState(() => _uploadingType = null);
    if (result.problem case final problem?) {
      _say(problem);
      return;
    }
    // What the attach did to the requirement is the case's to say — pending
    // becomes submitted, a rejected one reopens — so it is re-read rather
    // than assumed.
    if (result.attached) await _load();
  }

  /// Continue at the provider.
  Future<void> _continueProvider() async {
    final (Widget, String?)? next = switch (_rail) {
      final rail
          when rail.managementMode == RailManagementMode.khaimeKycForm ||
              rail.provider == PaymentProvider.khaime =>
        (
          GivingKycScreen(
            creatorId: widget.creatorId,
            rail: rail,
            application: widget.application,
            requirements: _requirements,
            repo: widget.repo,
            api: widget.api,
            send: widget.send,
          ),
          // The form already ends on its own submitted state; a second
          // "sent" on the way back would be saying it twice.
          null,
        ),
      final rail
          when rail.managementMode == RailManagementMode.paystackBank ||
              rail.provider == PaymentProvider.paystack =>
        (
          GivingPaystackScreen(
            creatorId: widget.creatorId,
            rail: rail,
            application: widget.application,
            requirements: _requirements,
            repo: widget.repo,
          ),
          AppStrings.givingPaystackConnected,
        ),
      final rail
          when rail.managementMode == RailManagementMode.stripeEmbedded ||
              rail.provider == PaymentProvider.stripe =>
        (
          GivingStripeScreen(
            creatorId: widget.creatorId,
            rail: rail,
            application: widget.application,
            requirements: _requirements,
            repo: widget.repo,
          ),
          // Nothing to announce: the creator has been at Stripe, and what
          // Stripe decided is read off the rail rather than claimed here.
          null,
        ),
      _ => null,
    };
    if (next == null) {
      _say(AppStrings.givingProviderFormBody);
      return;
    }
    final (screen, settled) = next;
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (done != true || !mounted) return;
    if (settled != null) _say(settled);
    await _load();
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
                    // The rail carries `review` — the reviewer's actual
                    // decision, with its reason.
                    pill: _reviewPill,
                    complete: _rail.review.isApproved ? true : null,
                    note: _reviewNote,
                    // A document still owed outranks the submit: posting
                    // without it is refused, and the creator is standing in
                    // front of the list of what is missing.
                    action: _blocking.isNotEmpty
                        ? AppStrings.givingUploadDocuments
                        : _canSubmit
                        ? AppStrings.givingSubmitForReview
                        : null,
                    loading: _blocking.isNotEmpty && _uploadingType != null,
                    onAction: _blocking.isNotEmpty
                        ? () => _uploadEvidence(_blocking.first)
                        : _submit,
                  ),
                  SizedBox(height: 12.s),
                  _trackCard(
                    key: const ValueKey('track-provider'),
                    title: AppStrings.givingProviderVerification,
                    requirements: _ownedBy(RequirementOwner.provider),
                    // The pill is the stage's to say, not the requirement
                    // list's: a provider-owned requirement stays
                    // outstanding for the whole time the provider is
                    // deciding, so reading the card off it alone cannot
                    // tell "still verifying" from "your move".
                    pill: _providerDone ? null : _providerPill,
                    complete: _providerDone,
                    action: switch (_rail.providerStage) {
                      ProviderStage.setup => AppStrings.givingContinueProvider(
                        provider,
                      ),
                      ProviderStage.update => AppStrings.givingProviderUpdate,
                      _ => null,
                    },
                    // With nothing left for the creator to do, say so.
                    note: _providerNote(provider),
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
  bool get _canSubmit => _rail.status.needsCreator;

  /// Documents the creator could still act on: nothing uploaded yet, one
  /// that was rejected, or one already submitted that may be replaced.
  List<RailRequirement> get _mine =>
      _requirements?.mine ?? const <RailRequirement>[];

  /// The ones that will stop a submit, which is a narrower thing.
  List<RailRequirement> get _blocking => _mine
      .where(
        (requirement) =>
            requirement.required &&
            (requirement.fileId == null || requirement.isRejected),
      )
      .toList();

  /// GospelTube's half, in the card's own words. Null leaves the pill to
  /// the requirement list, which is right while no decision exists.
  (String, GivingTone)? get _reviewPill {
    final review = _rail.review;
    if (!review.isKnown) return null;
    if (review.isApproved) {
      return (AppStrings.givingTrackCompleted, GivingTone.good);
    }
    if (review.isRejected || review.needsMore) {
      return (AppStrings.givingTrackActionNeeded, GivingTone.bad);
    }
    if (review.isUnderReview) {
      return (AppStrings.givingTrackUnderReview, GivingTone.pending);
    }
    return null;
  }

  /// A reviewer's own words where there are any; the stock line otherwise.
  String? get _reviewNote {
    final review = _rail.review;
    if (review.reason case final reason? when reason.trim().isNotEmpty) {
      return reason;
    }
    if (review.isRejected) return AppStrings.givingReviewRejected;
    if (review.needsMore) return AppStrings.givingReviewNeedsMore;
    if (review.isApproved) return AppStrings.givingReviewApproved;
    return null;
  }

  /// Whether the provider's half is finished.
  bool get _providerDone {
    if (_rail.providerStage == ProviderStage.ready) return true;
    final owned = _ownedBy(RequirementOwner.provider);
    return owned.isNotEmpty && owned.every((r) => r.isSatisfied);
  }

  /// What the provider half is doing, in the card's own words.
  (String, GivingTone) get _providerPill => switch (_rail.providerStage) {
    ProviderStage.ready => (AppStrings.givingTrackCompleted, GivingTone.good),
    ProviderStage.update => (
      AppStrings.givingTrackActionNeeded,
      GivingTone.bad,
    ),
    ProviderStage.waiting => (
      AppStrings.givingTrackWaiting,
      GivingTone.pending,
    ),
    // "Not started" is a claim, and the payload often disproves it: a rail
    // reading `in_progress` or carrying a submitted case has started,
    // whatever is still outstanding.
    ProviderStage.setup when _rail.kyc.isStarted => (
      AppStrings.givingTrackActionNeeded,
      GivingTone.pending,
    ),
    ProviderStage.setup => (
      AppStrings.givingTrackNotStarted,
      GivingTone.neutral,
    ),
  };

  /// The line under a card with no button on it, or above one that is
  /// asking for a correction.
  String? _providerNote(String provider) => switch (_rail.providerStage) {
    ProviderStage.update =>
      _providerRejection ?? AppStrings.givingProviderUpdateNote(provider),
    // The two reasons a Stripe rail is still the creator's move look
    // identical on screen and are not the same thing at all: one needs the
    // flow finishing, the other needs something new.
    ProviderStage.setup when _rail.providerRequirementsDue.isNotEmpty =>
      AppStrings.givingProviderWants(provider),
    ProviderStage.setup when _rail.kyc.isStarted =>
      AppStrings.givingProviderUnfinished(provider),
    // Stripe is the one provider that says, in so many words, that it has
    // not finished looking.
    ProviderStage.waiting when _rail.providerApproved == false =>
      AppStrings.givingProviderVerifying(provider),
    ProviderStage.waiting
        when _rail.providerHasDetails || _rail.kyc.isHandedOver =>
      AppStrings.givingProviderWaiting(provider),
    _ => null,
  };

  /// The first reason the provider gave for turning something down.
  String? get _providerRejection {
    for (final requirement in _ownedBy(RequirementOwner.provider)) {
      if (requirement.isRejected) {
        if (requirement.rejectionReason case final reason?
            when reason.trim().isNotEmpty) {
          return reason;
        }
      }
    }
    return null;
  }

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
    String? note,
    bool loading = false,
    (String, GivingTone)? pill,
    bool? complete,
  }) {
    final outstanding = requirements.where((r) => !r.isSatisfied).toList();
    final done = complete ?? (requirements.isNotEmpty && outstanding.isEmpty);
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
                label:
                    pill?.$1 ??
                    (done
                        ? AppStrings.givingTrackCompleted
                        : requirements.isEmpty
                        ? AppStrings.railPlatformReview
                        : AppStrings.railCollecting),
                tone: pill?.$2 ?? (done ? GivingTone.good : GivingTone.pending),
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
          // A finished track has nothing left to do, whatever the rail as a
          // whole is still waiting on.
          if (note case final text? when !done) ...[
            SizedBox(height: 10.s),
            Text(
              text,
              key: const ValueKey('track-note'),
              style: AppStyles.label(
                10,
                color: AppColors.neutral500,
                lineHeight: 14 / 10,
              ),
            ),
          ],
          if (action case final label? when !done) ...[
            SizedBox(height: 14.s),
            GivingOutlineButton(
              label: label,
              loading: loading,
              onTap: _busy ? null : () => unawaited(onAction()),
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
        GivingChecklistRow(
          requirement: requirement,
          busy: _busy || _uploadingType != null,
          loading:
              _uploadingType != null &&
              _uploadingType == requirement.evidenceType,
          onUpload: requirement.isUploadable
              ? () => unawaited(_uploadEvidence(requirement))
              : null,
        ),
    ];
  }
}
