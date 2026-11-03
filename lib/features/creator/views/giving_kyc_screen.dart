import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/services/giving_evidence_upload.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/features/creator/views/widgets/moment_picker.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/country_flag_icon.dart';
import 'package:test_app/shared/components/country_picker_sheet.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/data/countries.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:test_app/utils/helpers/phone_number.dart';

/// Khaime's identity and bank form — the one provider whose onboarding the
/// app hosts itself.
///
/// Stripe and Paystack hand the creator to the provider; Khaime's
/// `provider.management.mode` is `khaime_kyc_form`, which means these fields
/// are ours to collect. Three constraints govern how:
///
/// - **Documents are evidence first.** Every file id the KYC payload names
///   must already be attached to this rail's verification case under the
///   right evidence type, or the request is refused before it reaches
///   Khaime. So a picked file goes ticket → S3 → attach, and only the id
///   that comes back is submitted.
/// - **Nothing identifying is kept.** The ID number and the full account
///   number are forwarded to Khaime and never stored by GospelTube, so
///   nothing here caches them, logs them, or puts them in analytics.
/// - **Documents already on file are reused.** Each creator-owned
///   requirement carries the newest non-rejected `fileId`, which is why a
///   second rail does not ask for the same passport twice.
class GivingKycScreen extends StatefulWidget {
  const GivingKycScreen({
    super.key,
    required this.creatorId,
    required this.rail,
    this.application,
    this.requirements,
    this.repo,
    this.api,
    this.send,
  });

  final String creatorId;
  final GivingRail rail;
  final GivingApplication? application;
  final RailRequirements? requirements;
  final GivingRepo? repo;

  /// The evidence ticket is minted straight off the API rather than through
  /// [GivingRepo], because the upload is a three-leg sequence that belongs
  /// with the screen that owns the files.
  final ApiService? api;
  final S3Send? send;

  @override
  State<GivingKycScreen> createState() => _GivingKycScreenState();
}

/// What a government ID can be.
enum IdType {
  passport('passport', 'International passport'),
  nationalId('national_id', 'National ID'),
  driversLicense('drivers_license', "Driver's licence");

  const IdType(this.wire, this.label);

  final String wire;
  final String label;
}

class _GivingKycScreenState extends State<GivingKycScreen> {
  late final _repo = widget.repo ?? GivingRepo();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();
  final _accountNumber = TextEditingController();
  final _accountName = TextEditingController();

  IdType _idType = IdType.passport;
  PayoutBank? _bank;
  List<PayoutBank> _banks = const [];

  /// Chosen from a wheel rather than typed. A free text field had to say
  /// "YYYY-MM-DD" underneath it and still took anything at all, and the one
  /// shape the route accepts is not the one most people write a date in.
  DateTime? _dateOfBirth;

  /// The settlement country is the right first guess for the account
  /// owner's number — never the device locale, which is wrong for anyone
  /// travelling or on a phone bought abroad.
  late Country _phoneCountry =
      Countries.byIsoCode(widget.rail.countryCode) ?? Countries.fallback;

  /// Evidence already accepted on this rail, by evidence type.
  late final Map<String, String> _files = {
    for (final requirement in widget.requirements?.requirements ?? const [])
      ?requirement.evidenceType: ?requirement.fileId,
  };

  bool _busy = false;

  /// Which evidence type is uploading, so only that card spins — and so
  /// the other one is still refused while it does, since two presigned
  /// uploads at once is a race nobody asked for.
  String? _uploadingType;

  /// The bank list is fetched while the rest of the form is being filled in.
  /// Until it lands, an empty list means "not here yet", not "none" — and
  /// saying the latter sends a creator looking for a problem that is about
  /// to solve itself.
  bool _loadingBanks = true;
  String? _problem;

  static const _identityEvidence = 'identity_document';
  static const _selfieEvidence = 'selfie';

  /// The ownership the active policy allows. Never inferred from the
  /// classification — the guide says so twice — so the first allowed value
  /// is used and the picker offers only what came back.
  ///
  /// An **empty** list falls back too, not just a missing policy: a policy
  /// that arrived without the field used to leave `_ownership` initialising
  /// off `[].first`, which threw out of a field initialiser and took the
  /// whole form down before it drew.
  List<String> get _ownerships {
    final allowed = widget.requirements?.policy?.allowedAccountOwnership;
    return allowed == null || allowed.isEmpty
        ? const ['legal_recipient']
        : allowed;
  }

  late String _ownership = _ownerships.first;

  /// `individual` for an individual or unregistered organisation,
  /// `registered_business` for everything else. The rule is the platform's,
  /// not a guess.
  String get _accountType => switch (widget.application?.legalClassification) {
    null ||
    LegalClassification.individual ||
    LegalClassification.unregisteredOrganisation => 'individual',
    _ => 'registered_business',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_loadBanks());
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _phone,
      _idNumber,
      _street,
      _city,
      _state,
      _postalCode,
      _accountNumber,
      _accountName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      if (mounted) setState(() => _loadingBanks = true);
      final banks = await _repo.fetchKhaimeBanks(
        creatorId: widget.creatorId,
        railId: widget.rail.id,
        currency: widget.rail.settlementCurrency,
      );
      if (mounted) setState(() => _banks = banks);
    } catch (e) {
      // A missing bank list is not fatal to the form: everything above it
      // still fills in, and the field says it has nothing to offer.
      logger.w('Khaime banks unavailable', error: e);
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  /// Pick a document, ticket it, send it to S3, attach it to the case.
  ///
  /// The same sequence the rail screen runs, and deliberately the same code:
  /// both verification tracks read the one set of evidence, so a document
  /// attached from either place satisfies both.
  Future<void> _upload(String evidenceType) async {
    if (_uploadingType != null) return;
    final result = await pickAndAttachEvidence(
      creatorId: widget.creatorId,
      railId: widget.rail.id,
      evidenceType: evidenceType,
      api: widget.api,
      send: widget.send,
      onPicked: () {
        if (mounted) setState(() => _uploadingType = evidenceType);
      },
    );
    if (!mounted) return;
    setState(() {
      _uploadingType = null;
      if (result.fileId case final fileId?) _files[evidenceType] = fileId;
    });
    if (result.problem case final problem?) _say(problem);
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await _repo.submitKhaimeKyc(
        creatorId: widget.creatorId,
        railId: widget.rail.id,
        accountOwnership: _ownership,
        accountType: _accountType,
        owner: {
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'dateOfBirth': ?_isoDateOfBirth,
          // E.164, because the number is forwarded to a provider that has no
          // way to know which country a bare "090…" belongs to.
          'phoneNumber': ?_e164Phone,
          'idType': _idType.wire,
          'idNumber': _idNumber.text.trim(),
          'idDocumentFileId': _files[_identityEvidence],
          'selfieFileId': ?_files[_selfieEvidence],
          'address': {
            'street': _street.text.trim(),
            'city': _city.text.trim(),
            'state': _state.text.trim(),
            'country': widget.rail.countryCode,
            'postalCode': ?_textOrNull(_postalCode),
          },
        },
        bankAccount: {
          'bankId': ?_bank?.id,
          'bankName': ?_bank?.name,
          'accountNumber': _accountNumber.text.trim(),
          'accountName': _accountName.text.trim(),
        },
        // A rejection or an information request reopens the same case, and
        // the resubmit route is the one that accepts a correction.
        resubmit: widget.rail.status == RailStatus.moreInformationRequired,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      logger.w('Khaime KYC failed', error: e);
      // The route names what it would not take — a document that is not
      // evidence on this case, a bank it does not know — and that is the
      // creator's next move.
      if (mounted) {
        setState(
          () => _problem = givingProblem(e) ?? AppStrings.givingWriteFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _textOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  /// The one shape the route documents: `1990-01-31`.
  String? get _isoDateOfBirth {
    final date = _dateOfBirth;
    if (date == null) return null;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  String? get _e164Phone {
    final number = PhoneNumber.e164(_phone.text, _phoneCountry.dialCode);
    return number.isEmpty ? null : number;
  }

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final picked = await pickMoment(
      context,
      initial:
          _dateOfBirth ?? DateTime(today.year - 30, today.month, today.day),
      dateOnly: true,
      maximum: today,
    );
    if (picked == null || !mounted) return;
    setState(
      () => _dateOfBirth = DateTime(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _pickPhoneCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await CountryPickerSheet.show(
      context,
      selected: _phoneCountry,
    );
    if (picked == null || !mounted) return;
    setState(() => _phoneCountry = picked);
  }

  /// What the route requires, checked here so a creator is told on the field
  /// rather than by a validation error after a round trip.
  String? _validate() {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      return AppStrings.givingKycNameRequired;
    }
    if (_idNumber.text.trim().isEmpty) {
      return AppStrings.givingKycIdNumberRequired;
    }
    // Nothing failed here — nothing was chosen. Saying an upload failed
    // sends a creator looking for a problem with a file they never picked.
    if (_files[_identityEvidence] == null) {
      return AppStrings.givingDocumentRequired;
    }
    if (_street.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _state.text.trim().isEmpty) {
      return AppStrings.givingKycAddressRequired;
    }
    if (_accountNumber.text.trim().isEmpty ||
        _accountName.text.trim().isEmpty) {
      return AppStrings.givingKycBankRequired;
    }
    // The number is optional, but a half-typed one reaches the provider as
    // an unreachable contact rather than as an error anybody sees.
    if (_phone.text.trim().isNotEmpty &&
        PhoneNumber.validate(_phone.text, _phoneCountry) != null) {
      return AppStrings.givingKycPhoneInvalid;
    }
    return null;
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
    final provider = widget.rail.provider?.label ?? '';
    final hold = widget.rail.holdDays;
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
          if (hold != null)
            Text(
              AppStrings.givingHoldNote(provider, hold),
              style: AppStyles.body(
                12,
                color: AppColors.neutral400,
                lineHeight: 17 / 12,
              ),
            ),
          SizedBox(height: 14.s),
          GivingInfoNote(AppStrings.givingKycNote(provider)),
          SizedBox(height: 22.s),
          const GivingSectionTitle(
            AppStrings.givingKycOwner,
            body: AppStrings.givingKycOwnerBody,
          ),
          Row(
            children: [
              Expanded(
                child: GivingField(
                  label: AppStrings.givingKycFirstName,
                  controller: _firstName,
                  fieldKey: const ValueKey('kyc-first-name'),
                ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: GivingField(
                  label: AppStrings.givingKycLastName,
                  controller: _lastName,
                  fieldKey: const ValueKey('kyc-last-name'),
                ),
              ),
            ],
          ),
          // A row each. Sharing one left the date under a format hint it no
          // longer needs and the number with no room for a dial code.
          GivingSelect(
            key: const ValueKey('kyc-dob'),
            label: AppStrings.givingKycDateOfBirth,
            value: _isoDateOfBirth ?? '',
            hint: AppStrings.givingKycDateOfBirthHint,
            onTap: _pickDateOfBirth,
          ),
          _PhoneField(
            label: AppStrings.givingKycPhone,
            controller: _phone,
            country: _phoneCountry,
            fieldKey: const ValueKey('kyc-phone'),
            onPickCountry: _pickPhoneCountry,
          ),
          GivingSelect(
            label: AppStrings.givingKycIdType,
            value: _idType.label,
            onTap: () async {
              final picked = await GivingPickerSheet.show<IdType>(
                context,
                title: AppStrings.givingKycIdType,
                options: IdType.values,
                labelOf: (type) => type.label,
                selected: _idType,
              );
              if (picked == null || !mounted) return;
              setState(() => _idType = picked);
            },
          ),
          GivingField(
            label: AppStrings.givingKycIdNumber,
            controller: _idNumber,
            fieldKey: const ValueKey('kyc-id-number'),
            hint: AppStrings.givingKycIdNumberHint(provider),
          ),
          SizedBox(height: 8.s),
          const GivingSectionTitle(AppStrings.givingKycAddress),
          GivingField(
            label: AppStrings.givingKycStreet,
            controller: _street,
            fieldKey: const ValueKey('kyc-street'),
          ),
          Row(
            children: [
              Expanded(
                child: GivingField(
                  label: AppStrings.givingKycCity,
                  controller: _city,
                  fieldKey: const ValueKey('kyc-city'),
                ),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: GivingField(
                  label: AppStrings.givingKycState,
                  controller: _state,
                  fieldKey: const ValueKey('kyc-state'),
                ),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: GivingField(
                  label: AppStrings.givingKycPostalCode,
                  controller: _postalCode,
                  fieldKey: const ValueKey('kyc-postal'),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.s),
          _DocumentCard(
            key: const ValueKey('kyc-identity-document'),
            title: AppStrings.givingKycIdDocument,
            fileId: _files[_identityEvidence],
            busy: _uploadingType != null,
            loading: _uploadingType == _identityEvidence,
            onPick: () => unawaited(_upload(_identityEvidence)),
          ),
          SizedBox(height: 12.s),
          _DocumentCard(
            key: const ValueKey('kyc-selfie'),
            title: AppStrings.givingKycSelfie,
            optional: true,
            fileId: _files[_selfieEvidence],
            busy: _uploadingType != null,
            loading: _uploadingType == _selfieEvidence,
            onPick: () => unawaited(_upload(_selfieEvidence)),
          ),
          SizedBox(height: 22.s),
          GivingSectionTitle(
            AppStrings.givingKycBankSection(widget.rail.settlementCurrency),
            body: AppStrings.givingKycBankSectionBody,
          ),
          if (_ownerships.length > 1)
            GivingSelect(
              label: AppStrings.givingKycOwnership,
              // Policy's own wire values, humanised rather than printed raw:
              // "legal_recipient" is not a thing to ask a creator to read.
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
                setState(() => _ownership = picked);
              },
            ),
          GivingSelect(
            key: const ValueKey('kyc-bank'),
            label: AppStrings.givingKycBank,
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
                title: AppStrings.givingKycBank,
                options: _banks,
                labelOf: (bank) => bank.name,
                selected: _bank,
              );
              if (picked == null || !mounted) return;
              setState(() => _bank = picked);
            },
          ),
          GivingField(
            label: AppStrings.givingKycAccountNumber,
            controller: _accountNumber,
            keyboardType: TextInputType.number,
            fieldKey: const ValueKey('kyc-account-number'),
          ),
          GivingField(
            label: AppStrings.givingKycAccountName,
            controller: _accountName,
            fieldKey: const ValueKey('kyc-account-name'),
            hint: AppStrings.givingKycAccountNameHint,
          ),
          if (_problem case final message?) ...[
            SizedBox(height: 8.s),
            Text(
              message,
              key: const ValueKey('kyc-problem'),
              style: AppStyles.label(12, color: AppColors.red500),
            ),
          ],
          SizedBox(height: 22.s),
          PrimaryButton(
            key: const ValueKey('kyc-submit'),
            label: AppStrings.givingSubmitForReview,
            loading: _busy,
            onPressed: () => unawaited(_submit()),
          ),
        ],
      ),
    );
  }
}

/// A dial code beside the number, in the setup form's own field styling.
///
/// [GTubePhoneField] exists and does the same job, but it is built out of
/// the auth screens' field shell — a different border, radius and focus
/// shadow — so dropping it into this form would put one field from another
/// screen in the middle of it. The picker sheet and the dial-code formatting
/// are shared; only the shell is local.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.label,
    required this.controller,
    required this.country,
    required this.fieldKey,
    required this.onPickCountry,
  });

  final String label;
  final TextEditingController controller;
  final Country country;
  final Key fieldKey;
  final Future<void> Function() onPickCountry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 14.s),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CreatorFieldLabel(label),
        SizedBox(height: 6.s),
        Row(
          children: [
            Material(
              color: AppColors.brandAltDark,
              borderRadius: BorderRadius.circular(8.s),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('kyc-phone-country'),
                onTap: () => unawaited(onPickCountry()),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.s,
                    vertical: 13.s,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.s),
                    border: Border.all(color: AppColors.neutral700),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // An SVG flag, not the emoji: no emoji glyph renders
                      // on the iOS simulator or on many Android builds.
                      CountryFlagIcon(isoCode: country.isoCode, height: 12.s),
                      SizedBox(width: 6.s),
                      Text(
                        country.display,
                        style: AppStyles.body(13, color: AppColors.neutral50),
                      ),
                      SizedBox(width: 4.s),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16.s,
                        color: AppColors.neutral400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.s),
            Expanded(
              child: CreatorTextField(
                key: fieldKey,
                controller: controller,
                hint: label,
                keyboardType: TextInputType.phone,
                contentPadding: EdgeInsets.all(12.s),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// A document the creator has to supply, and whether one is already on file.
class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    super.key,
    required this.title,
    required this.onPick,
    this.fileId,
    this.optional = false,
    this.busy = false,
    this.loading = false,
  });

  final String title;

  /// Already attached to this rail's case, so it is not asked for again.
  final String? fileId;

  final bool optional;
  final bool busy;

  /// This card's own upload is in flight. [busy] is the whole group's, which
  /// is what stops a second pick while this one runs.
  final bool loading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final onFile = fileId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: CreatorFieldLabel(title)),
            if (optional)
              Text(
                AppStrings.givingKycOptional,
                style: AppStyles.label(10, color: AppColors.neutral500),
              ),
          ],
        ),
        SizedBox(height: 8.s),
        GivingCard(
          padding: EdgeInsets.all(12.s),
          onTap: busy ? null : onPick,
          child: Row(
            children: [
              Icon(
                onFile ? Icons.check_circle : Icons.upload_file,
                size: 18.s,
                color: onFile ? AppColors.green500 : AppColors.neutral400,
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      onFile
                          ? AppStrings.givingDocumentOnFile
                          : AppStrings.givingUploadDocument,
                      style: AppStyles.label(12, weight: AppStyles.bold),
                    ),
                    if (onFile) ...[
                      SizedBox(height: 3.s),
                      Text(
                        // Only once something is actually on file. Shown
                        // before that, it describes an upload that never
                        // happened.
                        AppStrings.givingDocumentOnFileBody,
                        style: AppStyles.label(
                          10,
                          color: AppColors.neutral500,
                          lineHeight: 14 / 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.s),
              if (loading)
                SizedBox(
                  width: 14.s,
                  height: 14.s,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.s,
                    color: AppColors.brandPrimary,
                  ),
                )
              else
                Text(
                  onFile
                      ? AppStrings.givingReplaceDocument
                      : AppStrings.givingUploadDocument,
                  style: AppStyles.button(11, color: AppColors.brandPrimary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
