import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Paystack's settlement account, collected here rather than at Paystack.
///
/// Unlike Stripe, Paystack has **no hosted onboarding page** — section 8 of
/// the integration guide gives three ordinary routes (banks, resolve,
/// subaccount), so "Continue setup" has nowhere to send anyone. It used to
/// answer with a snackbar saying to finish on the provider, which was a
/// dead end and, for this provider, untrue.
///
/// Three rules from that section shape the screen:
///
/// - **The resolved name is shown for explicit confirmation.** The number
///   is resolved against the bank first and the account name that comes
///   back is put in front of the creator before anything is created.
/// - **No bypass.** A name that does not match the legal recipient is a
///   review blocker the server raises as `bank_account_name_review`; the
///   client neither edits the resolved name nor offers a way past it.
/// - **This is not identity verification.** An active subaccount completes
///   the technical provider step only — GospelTube's review still follows,
///   which the screen says rather than leaving the creator to assume they
///   are finished.
class GivingPaystackScreen extends StatefulWidget {
  const GivingPaystackScreen({
    super.key,
    required this.creatorId,
    required this.rail,
    this.application,
    this.requirements,
    this.repo,
  });

  final String creatorId;
  final GivingRail rail;
  final GivingApplication? application;
  final RailRequirements? requirements;
  final GivingRepo? repo;

  @override
  State<GivingPaystackScreen> createState() => _GivingPaystackScreenState();
}

class _GivingPaystackScreenState extends State<GivingPaystackScreen> {
  late final _repo = widget.repo ?? GivingRepo();

  final _accountNumber = TextEditingController();

  PayoutBank? _bank;
  List<PayoutBank> _banks = const [];

  /// The name the bank gave back for this number, and nothing else: the
  /// subaccount is only ever created for an account that resolved.
  String? _accountName;

  bool _loadingBanks = true;
  bool _resolving = false;
  bool _busy = false;
  String? _problem;

  /// The ownership the active policy allows. Never inferred from the
  /// classification, and a value outside the policy is refused before the
  /// subaccount is created — so the picker offers only what came back.
  List<String> get _ownerships {
    final allowed = widget.requirements?.policy?.allowedAccountOwnership;
    return allowed == null || allowed.isEmpty
        ? const ['legal_recipient']
        : allowed;
  }

  late String _ownership = _ownerships.first;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBanks());
    // A resolved name belongs to the number it was resolved for. Editing
    // the number afterwards would otherwise leave the old name on screen
    // and let it be connected.
    _accountNumber.addListener(_forgetResolution);
  }

  @override
  void dispose() {
    _accountNumber.removeListener(_forgetResolution);
    _accountNumber.dispose();
    super.dispose();
  }

  void _forgetResolution() {
    if (_accountName == null) return;
    setState(() => _accountName = null);
  }

  Future<void> _loadBanks() async {
    try {
      if (mounted) setState(() => _loadingBanks = true);
      final banks = await _repo.fetchPaystackBanks(
        creatorId: widget.creatorId,
        railId: widget.rail.id,
      );
      if (mounted) setState(() => _banks = banks);
    } catch (e) {
      // The rest of the form is still fillable; the field says it has
      // nothing to offer rather than the screen failing whole.
      logger.w('Paystack banks unavailable', error: e);
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  /// Ask the bank who owns this number.
  Future<void> _resolve() async {
    final bank = _bank;
    if (bank == null) {
      setState(() => _problem = AppStrings.givingPaystackBankRequired);
      return;
    }
    if (_accountNumber.text.trim().isEmpty) {
      setState(() => _problem = AppStrings.givingPaystackNumberRequired);
      return;
    }
    setState(() {
      _resolving = true;
      _problem = null;
    });
    try {
      final name = await _repo.resolvePaystackAccount(
        creatorId: widget.creatorId,
        railId: widget.rail.id,
        bankCode: bank.code.isEmpty ? bank.id : bank.code,
        accountNumber: _accountNumber.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _accountName = name;
        if (name == null || name.isEmpty) {
          _problem = AppStrings.givingPaystackResolveFailed;
          _accountName = null;
        }
      });
    } catch (e) {
      // Never the number itself.
      logger.w('Paystack account resolve failed', error: e);
      if (mounted) {
        setState(
          () => _problem =
              givingProblem(e) ?? AppStrings.givingPaystackResolveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _connect() async {
    final bank = _bank;
    if (bank == null) {
      setState(() => _problem = AppStrings.givingPaystackBankRequired);
      return;
    }
    // Resolution is the confirmation step, not a convenience, so there is
    // no path to the subaccount that skips it.
    if (_accountName == null) {
      setState(() => _problem = AppStrings.givingPaystackUnresolved);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await _repo.createPaystackSubaccount(
        creatorId: widget.creatorId,
        railId: widget.rail.id,
        accountOwnership: _ownership,
        settlementBankCode: bank.code.isEmpty ? bank.id : bank.code,
        accountNumber: _accountNumber.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      logger.w('Paystack subaccount failed', error: e);
      if (mounted) {
        setState(
          () => _problem = givingProblem(e) ?? AppStrings.givingWriteFailed,
        );
      }
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
    final provider = widget.rail.provider?.label ?? AppStrings.providerPaystack;
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.s, 4.s, 16.s, 40.s),
        children: [
          Text(
            AppStrings.givingDirectNote(provider),
            style: AppStyles.body(
              12,
              color: AppColors.neutral400,
              lineHeight: 17 / 12,
            ),
          ),
          SizedBox(height: 14.s),
          GivingInfoNote(AppStrings.givingPaystackNote(provider)),
          SizedBox(height: 22.s),
          const GivingSectionTitle(
            AppStrings.givingPaystackSection,
            body: AppStrings.givingPaystackSectionBody,
          ),
          if (_ownerships.length > 1)
            GivingSelect(
              key: const ValueKey('paystack-ownership'),
              label: AppStrings.givingKycOwnership,
              value: AppStrings.givingOwnershipLabel(_ownership),
              onTap: () async {
                final picked = await GivingPickerSheet.show<String>(
                  context,
                  title: AppStrings.givingKycOwnership,
                  options: _ownerships,
                  labelOf: AppStrings.givingOwnershipLabel,
                  selected: _ownership,
                );
                if (picked == null || !mounted) return;
                setState(() {
                  _ownership = picked;
                });
              },
            ),
          GivingSelect(
            key: const ValueKey('paystack-bank'),
            label: AppStrings.givingPaystackBank,
            value: _bank?.name ?? '',
            loading: _loadingBanks,
            onTap: () async {
              if (_loadingBanks) return;
              if (_banks.isEmpty) {
                _say(AppStrings.givingBanksUnavailable);
                return;
              }
              final picked = await GivingPickerSheet.show<PayoutBank>(
                context,
                title: AppStrings.givingPaystackBank,
                options: _banks,
                labelOf: (bank) => bank.name,
                selected: _bank,
              );
              if (picked == null || !mounted) return;
              setState(() {
                _bank = picked;
                // Another bank is another account, whatever the number says.
                _accountName = null;
              });
            },
          ),
          GivingField(
            label: AppStrings.givingPaystackAccountNumber,
            controller: _accountNumber,
            keyboardType: TextInputType.number,
            fieldKey: const ValueKey('paystack-account-number'),
          ),
          // Its own control rather than something the submit does on the
          // way past, because the guide asks for the name to be confirmed
          // — which means it has to be on screen before anything is
          // created.
          GivingOutlineButton(
            key: const ValueKey('paystack-check'),
            label: AppStrings.givingPaystackCheck,
            outlined: true,
            loading: _resolving,
            onTap: _resolving ? null : () => unawaited(_resolve()),
          ),
          if (_accountName case final name?) ...[
            SizedBox(height: 14.s),
            GivingCard(
              key: const ValueKey('paystack-account-name'),
              padding: EdgeInsets.all(12.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.givingPaystackAccountName,
                    style: AppStyles.label(10, color: AppColors.neutral500),
                  ),
                  SizedBox(height: 4.s),
                  // Read-only on purpose: a mismatch with the legal
                  // recipient is the server's to raise as a review item,
                  // and letting it be typed over would be the bypass the
                  // guide forbids.
                  Text(name, style: AppStyles.body(14)),
                  SizedBox(height: 6.s),
                  Text(
                    AppStrings.givingPaystackConfirmBody,
                    style: AppStyles.label(
                      10,
                      color: AppColors.neutral500,
                      lineHeight: 14 / 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_problem case final message?) ...[
            SizedBox(height: 10.s),
            Text(
              message,
              key: const ValueKey('paystack-problem'),
              style: AppStyles.label(12, color: AppColors.red500),
            ),
          ],
          SizedBox(height: 18.s),
          Text(
            AppStrings.givingPaystackReviewNote,
            style: AppStyles.label(
              10,
              color: AppColors.neutral500,
              lineHeight: 14 / 10,
            ),
          ),
          SizedBox(height: 18.s),
          PrimaryButton(
            key: const ValueKey('paystack-connect'),
            label: AppStrings.givingPaystackConnect,
            loading: _busy,
            onPressed: () => unawaited(_connect()),
          ),
        ],
      ),
    );
  }
}
