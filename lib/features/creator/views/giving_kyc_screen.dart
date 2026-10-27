import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/giving_repo.dart';
import 'package:test_app/features/creator/services/creator_image_picker.dart';
import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/features/creator/views/widgets/giving_sheets.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/shared/services/s3_upload.dart';
import 'package:test_app/utils/app_constants/api_endpoints.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';
import 'package:get_it/get_it.dart';

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
  late final _api = widget.api ?? GetIt.instance<ApiService>();
  late final _send = widget.send ?? S3PresignedUpload.send;

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dateOfBirth = TextEditingController();
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

  /// Evidence already accepted on this rail, by evidence type.
  late final Map<String, String> _files = {
    for (final requirement in widget.requirements?.requirements ?? const [])
      ?requirement.evidenceType: ?requirement.fileId,
  };

  bool _busy = false;
  bool _uploading = false;
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
      _dateOfBirth,
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
    }
  }

  /// Pick a document, ticket it, send it to S3, attach it to the case.
  ///
  /// The attach is what makes it evidence; an uploaded file nothing has
  /// attached is invisible to the verification case and would fail the KYC
  /// submit with a validation error.
  Future<void> _upload(String evidenceType) async {
    final result = await CreatorImagePicker.pick(maxBytes: 10 * 1024 * 1024);
    if (result.isCancelled || !mounted) return;
    if (result.failure case final failure?) {
      _say(
        failure == PickFailure.tooLarge
            ? AppStrings.givingEvidenceFailed
            : AppStrings.settingsPhotoUnreadable,
      );
      return;
    }
    final image = result.image!;
    setState(() => _uploading = true);
    try {
      final ticket = await _api.post(
        ApiEndpoints.givingEvidenceUploadUrl,
        data: {
          'creatorId': widget.creatorId,
          'railId': widget.rail.id,
          'evidenceType': evidenceType,
          'filename': image.filename,
          'mimeType': image.mimeType,
          // Exactly the bytes being sent: the presigned policy carries a
          // content-length-range of N,N and S3 refuses anything else.
          'size': image.size,
        },
      );
      final data =
          (ticket.data as Map<String, dynamic>?)?['data']
              as Map<String, dynamic>? ??
          const {};
      final fileId = data['fileId'] as String?;
      final uploadUrl = data['uploadUrl'] as String?;
      if (fileId == null || uploadUrl == null) {
        throw StateError('malformed evidence ticket');
      }
      await _send(
        uploadUrl: uploadUrl,
        fields: (data['fields'] as Map<String, dynamic>?) ?? const {},
        bytes: image.bytes,
        filename: image.filename,
      );
      await _api.post(
        ApiEndpoints.givingEvidence,
        data: {
          'creatorId': widget.creatorId,
          'railId': widget.rail.id,
          'evidenceType': evidenceType,
          'fileId': fileId,
        },
      );
      if (mounted) setState(() => _files[evidenceType] = fileId);
    } catch (e) {
      logger.w('Evidence upload failed', error: e);
      if (mounted) _say(AppStrings.givingEvidenceFailed);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
          'dateOfBirth': ?_textOrNull(_dateOfBirth),
          'phoneNumber': ?_textOrNull(_phone),
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
      if (mounted) setState(() => _problem = AppStrings.givingWriteFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _textOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
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
                child: _Field(
                  label: AppStrings.givingKycFirstName,
                  controller: _firstName,
                  fieldKey: const ValueKey('kyc-first-name'),
                ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: _Field(
                  label: AppStrings.givingKycLastName,
                  controller: _lastName,
                  fieldKey: const ValueKey('kyc-last-name'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: AppStrings.givingKycDateOfBirth,
                  controller: _dateOfBirth,
                  hint: AppStrings.givingKycDateOfBirthHint,
                  fieldKey: const ValueKey('kyc-dob'),
                ),
              ),
              SizedBox(width: 12.s),
              Expanded(
                child: _Field(
                  label: AppStrings.givingKycPhone,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  fieldKey: const ValueKey('kyc-phone'),
                ),
              ),
            ],
          ),
          _Select(
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
          _Field(
            label: AppStrings.givingKycIdNumber,
            controller: _idNumber,
            fieldKey: const ValueKey('kyc-id-number'),
            hint: AppStrings.givingKycIdNumberHint(provider),
          ),
          SizedBox(height: 8.s),
          const GivingSectionTitle(AppStrings.givingKycAddress),
          _Field(
            label: AppStrings.givingKycStreet,
            controller: _street,
            fieldKey: const ValueKey('kyc-street'),
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: AppStrings.givingKycCity,
                  controller: _city,
                  fieldKey: const ValueKey('kyc-city'),
                ),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: _Field(
                  label: AppStrings.givingKycState,
                  controller: _state,
                  fieldKey: const ValueKey('kyc-state'),
                ),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: _Field(
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
            busy: _uploading,
            onPick: () => unawaited(_upload(_identityEvidence)),
          ),
          SizedBox(height: 12.s),
          _DocumentCard(
            key: const ValueKey('kyc-selfie'),
            title: AppStrings.givingKycSelfie,
            optional: true,
            fileId: _files[_selfieEvidence],
            busy: _uploading,
            onPick: () => unawaited(_upload(_selfieEvidence)),
          ),
          SizedBox(height: 22.s),
          GivingSectionTitle(
            AppStrings.givingKycBankSection(widget.rail.settlementCurrency),
            body: AppStrings.givingKycBankSectionBody,
          ),
          if (_ownerships.length > 1)
            _Select(
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
          _Select(
            label: AppStrings.givingKycBank,
            value: _bank?.name ?? '',
            onTap: () async {
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
          _Field(
            label: AppStrings.givingKycAccountNumber,
            controller: _accountNumber,
            keyboardType: TextInputType.number,
            fieldKey: const ValueKey('kyc-account-number'),
          ),
          _Field(
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.fieldKey,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final Key fieldKey;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 14.s),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CreatorFieldLabel(label),
        SizedBox(height: 6.s),
        CreatorTextField(
          key: fieldKey,
          controller: controller,
          hint: label,
          keyboardType: keyboardType,
          contentPadding: EdgeInsets.all(12.s),
        ),
        if (hint case final note?) ...[
          SizedBox(height: 6.s),
          Text(note, style: AppStyles.label(10, color: AppColors.neutral500)),
        ],
      ],
    ),
  );
}

class _Select extends StatelessWidget {
  const _Select({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 14.s),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CreatorFieldLabel(label),
        SizedBox(height: 6.s),
        CreatorSelectField(
          hint: label,
          value: value,
          contentPadding: EdgeInsets.all(12.s),
          onTap: () => unawaited(onTap()),
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
  });

  final String title;

  /// Already attached to this rail's case, so it is not asked for again.
  final String? fileId;

  final bool optional;
  final bool busy;
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
