/// What the creator's side of Giving is made of.
library;

import 'package:test_app/utils/app_constants/app_strings.dart';

// -------------------------------------------------------------------------
// -- Money ----------------------------------------------------------------
// -----------

/// One amount, in one currency.
class Money {
  const Money({
    required this.currency,
    required this.amountMinor,
    required this.amount,
  });

  final String currency;
  final int amountMinor;
  final double amount;

  static const zeroNgn = Money(currency: 'NGN', amountMinor: 0, amount: 0);

  bool get isZero => amountMinor == 0;

  factory Money.fromJson(Map<String, dynamic> json) => Money(
    currency: json['currency'] as String? ?? '',
    amountMinor: (json['amountMinor'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
  );

  /// Null-safe: a balance a provider could not report arrives as `null` and
  /// must stay null, because rendering it as a zero would claim the money is
  /// not there.
  static Money? maybe(Object? json) =>
      json is Map<String, dynamic> ? Money.fromJson(json) : null;

  /// "₦30,000.00", and "-₦30,000.00" for a reversal.
  String get display =>
      '${amount < 0 ? '-' : ''}${_symbol(currency)}${_grouped(amount.abs())}';

  static String _symbol(String currency) => switch (currency) {
    'NGN' => '₦',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$currency ',
  };

  /// Two decimals and thousands separators, done by hand because the app
  /// carries no `intl` dependency and this is the only place that needs it.
  static String _grouped(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '$buffer.${parts.last}';
  }
}

// -------------------------------------------------------------------------
// -- The application and its rails ----------------------------------------
// -----------------------------------

/// Who the money legally belongs to.
enum LegalClassification {
  individual('INDIVIDUAL', AppStrings.givingClassIndividual),
  unregisteredOrganisation(
    'UNREGISTERED_ORGANISATION',
    AppStrings.givingClassUnregistered,
  ),
  registeredBusiness('REGISTERED_BUSINESS', AppStrings.givingClassBusiness),
  registeredReligious(
    'REGISTERED_RELIGIOUS_ORGANISATION',
    AppStrings.givingClassReligious,
  ),
  nonprofitUnverified('NONPROFIT_UNVERIFIED', AppStrings.givingClassNonprofit),
  verifiedCharity('VERIFIED_CHARITY', AppStrings.givingClassCharity);

  const LegalClassification(this.wire, this.label);

  final String wire;
  final String label;

  static LegalClassification? from(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return null;
  }
}

/// Where a rail, or the application aggregating them, has got to.
enum RailStatus {
  draft('draft', AppStrings.railDraft),
  collectingInformation('collecting_information', AppStrings.railCollecting),
  providerOnboarding('provider_onboarding', AppStrings.railProviderOnboarding),
  platformReview('platform_review', AppStrings.railPlatformReview),
  moreInformationRequired(
    'more_information_required',
    AppStrings.railMoreInformation,
  ),
  active('active', AppStrings.railActive),
  restricted('restricted', AppStrings.railRestricted),
  suspended('suspended', AppStrings.railSuspended),
  rejected('rejected', AppStrings.railRejected),
  reonboardingRequired('reonboarding_required', AppStrings.railReonboarding);

  const RailStatus(this.wire, this.label);

  final String wire;
  final String label;

  /// Unknown states read as `collecting_information` rather than throwing: a
  /// state added server-side should slow a creator down, not break the tab.
  static RailStatus from(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return RailStatus.collectingInformation;
  }

  bool get isActive => this == RailStatus.active;

  /// Something is being looked at and the creator can only wait.
  bool get isUnderReview =>
      this == RailStatus.platformReview ||
      this == RailStatus.providerOnboarding;

  /// The creator has to do something before this moves.
  bool get needsCreator =>
      this == RailStatus.moreInformationRequired ||
      this == RailStatus.collectingInformation ||
      this == RailStatus.draft;

  /// The provider's own stage is still open.
  bool get providerStageOpen =>
      needsCreator ||
      this == RailStatus.providerOnboarding ||
      this == RailStatus.reonboardingRequired;
}

/// Who holds a gift between the giver paying and the creator being paid.
enum CustodyMode {
  direct('direct'),
  providerHeld('provider_held');

  const CustodyMode(this.wire);

  final String wire;

  static CustodyMode from(String? wire) =>
      wire == 'provider_held' ? CustodyMode.providerHeld : CustodyMode.direct;

  bool get isProviderHeld => this == CustodyMode.providerHeld;
}

/// The three providers the platform settles through.
enum PaymentProvider {
  stripe('stripe', AppStrings.providerStripe),
  paystack('paystack', AppStrings.providerPaystack),
  khaime('khaime', AppStrings.providerKhaime),
  flutterwave('flutterwave', AppStrings.providerFlutterwave);

  const PaymentProvider(this.wire, this.label);

  final String wire;
  final String label;

  static PaymentProvider? from(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return null;
  }
}

/// How a rail's provider onboarding is completed.
enum RailManagementMode {
  stripeEmbedded('stripe_embedded'),
  paystackBank('paystack_bank'),
  khaimeKycForm('khaime_kyc_form'),
  unknown('');

  const RailManagementMode(this.wire);

  final String wire;

  static RailManagementMode from(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return RailManagementMode.unknown;
  }
}

/// Who has to act on one outstanding requirement.
enum RequirementOwner {
  creator('creator', AppStrings.requirementOwnerCreator),
  gospeltube('gospeltube', AppStrings.requirementOwnerGospelTube),
  provider('provider', AppStrings.requirementOwnerProvider);

  const RequirementOwner(this.wire, this.label);

  final String wire;
  final String label;

  static RequirementOwner from(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return RequirementOwner.gospeltube;
  }
}

/// One thing standing between a rail and going live.
class RailRequirement {
  const RailRequirement({
    required this.code,
    required this.label,
    required this.owner,
    this.required = true,
    this.status = 'pending',
    this.evidenceType,
    this.rejectionReason,
    this.fileId,
  });

  final String code;
  final String label;
  final RequirementOwner owner;
  final bool required;

  /// `pending`, `submitted`, `accepted`, `rejected`, `satisfied`.
  final String status;

  /// What to upload against, when this is the creator's to supply.
  final String? evidenceType;
  final String? rejectionReason;

  /// The newest non-rejected file already attached for this requirement.
  final String? fileId;

  bool get isSatisfied => status == 'accepted' || status == 'satisfied';
  bool get isRejected => status == 'rejected';

  /// The creator can act on this one.
  bool get isUploadable =>
      owner == RequirementOwner.creator && evidenceType != null && !isSatisfied;

  factory RailRequirement.fromJson(Map<String, dynamic> json) =>
      RailRequirement(
        code: json['code'] as String? ?? '',
        label: json['label'] as String? ?? '',
        owner: RequirementOwner.from(json['owner'] as String?),
        required: json['required'] as bool? ?? true,
        status: json['status'] as String? ?? 'pending',
        evidenceType: json['evidenceType'] as String?,
        rejectionReason: json['rejectionReason'] as String?,
        fileId: json['fileId'] as String?,
      );
}

/// The immutable policy a verification case was opened under.
class RecipientPolicy {
  const RecipientPolicy({
    required this.id,
    required this.code,
    required this.version,
    this.allowedAccountOwnership = const [],
    this.supportedSettlementCurrencies = const [],
    this.internationalCardsAllowed = false,
    this.platformReviewRequired = false,
    this.reverificationDays,
  });

  final String id;
  final String code;
  final int version;

  /// Who may own the settlement account. A client must never infer these
  /// from the classification — the guide says so twice.
  final List<String> allowedAccountOwnership;
  final List<String> supportedSettlementCurrencies;
  final bool internationalCardsAllowed;
  final bool platformReviewRequired;
  final int? reverificationDays;

  factory RecipientPolicy.fromJson(Map<String, dynamic> json) =>
      RecipientPolicy(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 0,
        allowedAccountOwnership: _strings(json['allowedAccountOwnership']),
        supportedSettlementCurrencies: _strings(
          json['supportedSettlementCurrencies'],
        ),
        internationalCardsAllowed:
            json['internationalCardsAllowed'] as bool? ?? false,
        platformReviewRequired:
            json['platformReviewRequired'] as bool? ?? false,
        reverificationDays: (json['reverificationDays'] as num?)?.toInt(),
      );
}

/// A rail's requirements and the policy they were drawn from.
class RailRequirements {
  const RailRequirements({
    required this.railId,
    this.applicationId = '',
    this.requirements = const [],
    this.policy,
  });

  final String applicationId;
  final String railId;
  final List<RailRequirement> requirements;
  final RecipientPolicy? policy;

  /// What the creator still has to hand over.
  List<RailRequirement> get mine =>
      requirements.where((r) => r.isUploadable).toList();

  factory RailRequirements.fromJson(Map<String, dynamic> json) =>
      RailRequirements(
        applicationId: json['applicationId'] as String? ?? '',
        railId: json['railId'] as String? ?? '',
        requirements: _objects(
          json['requirements'],
        ).map(RailRequirement.fromJson).toList(),
        policy: json['policy'] is Map<String, dynamic>
            ? RecipientPolicy.fromJson(json['policy'] as Map<String, dynamic>)
            : null,
      );
}

/// A rail's KYC, as section 2's own state machine names it.
enum KycState {
  notStarted('not_started'),
  inProgress('in_progress'),
  submitted('submitted'),
  providerReview('provider_review'),
  platformReview('platform_review'),
  verified('verified'),
  rejected('rejected'),
  expired('expired'),

  /// Absent, or a state added server-side. Says nothing either way, so it
  /// never decides anything on its own.
  unknown('');

  const KycState(this.wire);

  final String wire;

  static KycState from(String? wire) {
    for (final value in values) {
      if (value.wire == wire && value != unknown) return value;
    }
    return unknown;
  }

  /// The creator's answers are in and somebody is looking at them.
  bool get isHandedOver =>
      this == submitted || this == providerReview || this == platformReview;

  /// Anything at all has happened.
  bool get isStarted => this != notStarted && this != unknown;
}

/// GospelTube's own verdict on the rail's verification case.
class RailReview {
  const RailReview({
    this.status = '',
    this.submittedAt,
    this.reviewedAt,
    this.reason,
  });

  final String status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  /// Why it was turned down or sent back.
  final String? reason;

  bool get isApproved => status == 'approved' || status == 'accepted';
  bool get isRejected => status == 'rejected';

  /// A reviewer asked for something rather than refusing outright.
  bool get needsMore =>
      status == 'information_requested' ||
      status == 'more_information_required';

  /// Handed over and nobody has decided yet.
  bool get isUnderReview =>
      status == 'submitted' ||
      status == 'in_review' ||
      status == 'provider_review' ||
      status == 'platform_review';

  /// Whether this says anything at all. An absent block decides nothing.
  bool get isKnown => status.isNotEmpty;

  factory RailReview.fromJson(Map<String, dynamic> json) => RailReview(
    status: json['status'] as String? ?? '',
    submittedAt: _date(json['submittedAt']),
    reviewedAt: _date(json['reviewedAt']),
    reason: json['reason'] as String?,
  );
}

/// Where the provider's half of a rail's verification actually stands.
enum ProviderStage {
  /// Nothing has reached the provider yet, or its initial onboarding was
  /// never finished.
  setup,

  /// It came back wanting something changed: a refusal, an information
  /// request, or a re-onboarding.
  update,

  /// Everything the creator can give is with the provider, and the
  /// provider is deciding.
  waiting,

  /// The provider's half is done.
  ready;

  /// Whether the card should offer a button at all.
  bool get needsCreator => this == setup || this == update;
}

/// One enrolled provider: where it settles, how far along it is, and what it
/// is still waiting for.
class GivingRail {
  const GivingRail({
    required this.id,
    required this.provider,
    required this.countryCode,
    required this.settlementCurrency,
    required this.status,
    this.custodyMode = CustodyMode.direct,
    this.holdDays,
    this.kycStatus = '',
    this.review = const RailReview(),
    this.enabled = true,
    this.priority = 0,
    this.requirements = const [],
    this.managementMode = RailManagementMode.unknown,
    this.providerRequirementsDue = const [],
    this.detailsSubmitted = false,
    this.providerApproved,
    this.releaseBlockedReason,
    this.releasesFrozen = false,
    this.changeRequestId,
    this.changeRequestStatus,
    this.submittedAt,
    this.settlementAccountName,
    this.settlementAccountHolder,
    this.settlementAccountLast4,
    this.accountOwnership,
    this.legalRecipientName,
  });

  final String id;
  final PaymentProvider? provider;
  final String countryCode;
  final String settlementCurrency;
  final RailStatus status;
  final CustodyMode custodyMode;

  /// How long a provider-held rail sits on a gift. Zero is a real answer on
  /// staging and means "released as soon as it settles", not "no hold".
  final int? holdDays;

  final String kycStatus;

  /// [kycStatus] in the vocabulary the guide actually documents.
  KycState get kyc => KycState.from(kycStatus);

  /// GospelTube's decision on this rail, when it has made one.
  final RailReview review;

  /// A creator can take an active rail out of donor routing without
  /// unpicking its verification.
  final bool enabled;
  final int priority;

  final List<RailRequirement> requirements;
  final RailManagementMode managementMode;
  final List<String> providerRequirementsDue;

  /// Whether the creator's own details have reached the provider.
  final bool detailsSubmitted;

  /// Stripe's own verdict on the connected account, from
  /// `provider.stripeAccountControls.approved`.
  final bool? providerApproved;

  /// Why a provider-held rail is not releasing, when it is not.
  final String? releaseBlockedReason;
  final bool releasesFrozen;

  final String? changeRequestId;
  final String? changeRequestStatus;
  final DateTime? submittedAt;

  /// The settlement account itself — the bank or institution it sits with.
  final String? settlementAccountName;

  /// The person or entity it is held by, which the design shows on its own
  /// line because it is a different fact from the account.
  final String? settlementAccountHolder;

  final String? settlementAccountLast4;
  final String? accountOwnership;
  final String? legalRecipientName;

  /// "Khaime · NGN" — how the preferred-rail picker names it.
  String get label => '${provider?.label ?? countryCode} · $settlementCurrency';

  bool get hasChangeInFlight => changeRequestId != null;

  /// Only a provider-held rail is ever withdrawn from.
  bool get offersWithdrawal => custodyMode.isProviderHeld;

  /// Whether the provider still has something for the creator to do.
  bool get providerNeedsCreator => providerStage.needsCreator;

  /// The same question in four answers rather than two.
  ProviderStage get providerStage {
    if (status.isActive) return ProviderStage.ready;
    // Ahead of every "it is done" clause below: a rail sent back keeps the
    // KYC it had, so a case that was verified once and then reopened still
    // reads `verified` while its status says otherwise.
    if (status == RailStatus.moreInformationRequired ||
        status == RailStatus.rejected ||
        status == RailStatus.reonboardingRequired ||
        kyc == KycState.rejected ||
        kyc == KycState.expired) {
      return ProviderStage.update;
    }
    if (kyc == KycState.verified) return ProviderStage.ready;
    if (providerApproved == true && providerRequirementsDue.isEmpty) {
      return ProviderStage.ready;
    }
    // `currently_due` is Stripe's word for what it wants *now*, from the
    // account owner; what it is merely verifying is not in it.
    if (provider == PaymentProvider.stripe &&
        providerRequirementsDue.isNotEmpty) {
      return ProviderStage.setup;
    }
    // The rail's own KYC outranks the provider's mirror of it.
    if (kyc.isHandedOver) return ProviderStage.waiting;
    if (provider == PaymentProvider.stripe) {
      return detailsSubmitted ? ProviderStage.waiting : ProviderStage.setup;
    }
    if (!providerHasDetails && status.providerStageOpen) {
      return ProviderStage.setup;
    }
    return ProviderStage.waiting;
  }

  /// Whether the provider already holds the creator's side of its form.
  bool get providerHasDetails =>
      detailsSubmitted || settlementAccountLast4 != null;

  factory GivingRail.fromJson(Map<String, dynamic> json) {
    final provider = (json['provider'] as Map<String, dynamic>?) ?? const {};
    final management =
        (provider['management'] as Map<String, dynamic>?) ?? const {};
    final change =
        (json['configurationChange'] as Map<String, dynamic>?) ?? const {};
    final destination =
        (json['settlementAccount'] as Map<String, dynamic>?) ?? const {};
    return GivingRail(
      id: json['id'] as String? ?? '',
      provider: PaymentProvider.from(json['paymentProvider'] as String?),
      countryCode: json['countryCode'] as String? ?? '',
      settlementCurrency: json['settlementCurrency'] as String? ?? '',
      status: RailStatus.from(json['status'] as String?),
      custodyMode: CustodyMode.from(json['custodyMode'] as String?),
      holdDays: (json['holdDays'] as num?)?.toInt(),
      kycStatus: json['kycStatus'] as String? ?? '',
      review: RailReview.fromJson(
        (json['review'] as Map<String, dynamic>?) ?? const {},
      ),
      enabled: json['enabled'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      requirements: _objects(
        json['requirements'],
      ).map(RailRequirement.fromJson).toList(),
      managementMode: RailManagementMode.from(management['mode'] as String?),
      providerRequirementsDue: _strings(provider['requirementsCurrentlyDue']),
      detailsSubmitted: provider['detailsSubmitted'] as bool? ?? false,
      providerApproved:
          ((provider['stripeAccountControls'] as Map<String, dynamic>?) ??
                  const {})['approved']
              as bool?,
      releaseBlockedReason: json['releaseBlockedReason'] as String?,
      releasesFrozen: json['releasesFrozen'] as bool? ?? false,
      changeRequestId: change['id'] as String?,
      changeRequestStatus: change['status'] as String?,
      submittedAt: _date(json['submittedAt']),
      settlementAccountName: destination['accountName'] as String?,
      settlementAccountHolder:
          destination['holderName'] as String? ??
          destination['accountHolderName'] as String?,
      settlementAccountLast4:
          destination['accountNumberLast4'] as String? ??
          destination['last4'] as String?,
      accountOwnership: destination['accountOwnership'] as String?,
      legalRecipientName: json['legalRecipientName'] as String?,
    );
  }
}

/// The legal recipient, and every rail enrolled under it.
class GivingApplication {
  const GivingApplication({
    required this.id,
    required this.creatorId,
    required this.legalRecipientName,
    required this.countryCode,
    required this.status,
    this.creatorType = '',
    this.legalClassification,
    this.kycStatus = '',
    this.termsVersion = '',
    this.termsAcceptedAt,
    this.restrictionReason,
    this.rails = const [],
  });

  final String id;
  final String creatorId;
  final String creatorType;
  final LegalClassification? legalClassification;
  final String legalRecipientName;
  final String countryCode;
  final RailStatus status;
  final String kycStatus;
  final String termsVersion;
  final DateTime? termsAcceptedAt;
  final String? restrictionReason;
  final List<GivingRail> rails;

  /// Gifts are only being accepted when a rail is active **and** enabled.
  /// The guide forbids saying "Givings enabled" on anything less.
  bool get isAcceptingGifts =>
      rails.any((rail) => rail.status.isActive && rail.enabled);

  bool get hasRails => rails.isNotEmpty;

  /// Something is with a reviewer and nothing is live yet.
  bool get isUnderReview =>
      !isAcceptingGifts && rails.any((rail) => rail.status.isUnderReview);

  factory GivingApplication.fromJson(Map<String, dynamic> json) =>
      GivingApplication(
        id: json['id'] as String? ?? '',
        creatorId: json['creatorId'] as String? ?? '',
        creatorType: json['creatorType'] as String? ?? '',
        legalClassification: LegalClassification.from(
          json['legalClassification'] as String?,
        ),
        legalRecipientName: json['legalRecipientName'] as String? ?? '',
        countryCode: json['countryCode'] as String? ?? '',
        status: RailStatus.from(json['status'] as String?),
        kycStatus: json['kycStatus'] as String? ?? '',
        termsVersion: json['termsVersion'] as String? ?? '',
        termsAcceptedAt: _date(json['termsAcceptedAt']),
        restrictionReason: json['restrictionReason'] as String?,
        rails: _objects(json['rails']).map(GivingRail.fromJson).toList(),
      );
}

/// One provider / country / currency combination policy currently allows.
class RecipientOption {
  const RecipientOption({
    required this.provider,
    required this.countryCode,
    required this.settlementCurrency,
    required this.legalClassification,
    this.policyId = '',
    this.policyVersion = 0,
    this.custodyMode = CustodyMode.direct,
    this.holdDays,
    this.creatorType = '',
    this.allowedAccountOwnership = const [],
    this.internationalCardsAllowed = false,
    this.platformReviewRequired = false,
    this.reverificationDays,
  });

  final String policyId;
  final int policyVersion;
  final PaymentProvider? provider;
  final CustodyMode custodyMode;
  final int? holdDays;
  final String countryCode;
  final String creatorType;
  final LegalClassification? legalClassification;
  final String settlementCurrency;
  final List<String> allowedAccountOwnership;
  final bool internationalCardsAllowed;
  final bool platformReviewRequired;
  final int? reverificationDays;

  factory RecipientOption.fromJson(Map<String, dynamic> json) =>
      RecipientOption(
        policyId: json['policyId'] as String? ?? '',
        policyVersion: (json['policyVersion'] as num?)?.toInt() ?? 0,
        provider: PaymentProvider.from(json['paymentProvider'] as String?),
        custodyMode: CustodyMode.from(json['custodyMode'] as String?),
        holdDays: (json['holdDays'] as num?)?.toInt(),
        countryCode: json['countryCode'] as String? ?? '',
        creatorType: json['creatorType'] as String? ?? '',
        legalClassification: LegalClassification.from(
          json['legalClassification'] as String?,
        ),
        settlementCurrency: json['settlementCurrency'] as String? ?? '',
        allowedAccountOwnership: _strings(json['allowedAccountOwnership']),
        internationalCardsAllowed:
            json['internationalCardsAllowed'] as bool? ?? false,
        platformReviewRequired:
            json['platformReviewRequired'] as bool? ?? false,
        reverificationDays: (json['reverificationDays'] as num?)?.toInt(),
      );
}

/// What may be enrolled, and the terms version an application must cite.
class GivingOptions {
  const GivingOptions({this.termsVersion = '', this.items = const []});

  final String termsVersion;
  final List<RecipientOption> items;

  bool get isEmpty => items.isEmpty;

  /// The countries on offer, once, in the order the server listed them.
  List<String> get countries {
    final seen = <String>[];
    for (final item in items) {
      if (!seen.contains(item.countryCode)) seen.add(item.countryCode);
    }
    return seen;
  }

  /// The classifications on offer for one country.
  List<LegalClassification> classificationsFor(String countryCode) {
    final seen = <LegalClassification>[];
    for (final item in items) {
      final value = item.legalClassification;
      if (value == null || item.countryCode != countryCode) continue;
      if (!seen.contains(value)) seen.add(value);
    }
    return seen;
  }

  /// Everything enrollable under one application, minus the providers
  /// already enrolled — a second rail for the same provider is a `CONFLICT`.
  List<RecipientOption> enrollable({
    LegalClassification? classification,
    String? countryCode,
    Iterable<PaymentProvider?> enrolled = const [],
  }) => items
      .where(
        (item) =>
            (classification == null ||
                item.legalClassification == classification) &&
            (countryCode == null || item.countryCode == countryCode) &&
            !enrolled.contains(item.provider),
      )
      .toList();

  factory GivingOptions.fromJson(Map<String, dynamic> json) => GivingOptions(
    termsVersion: json['termsVersion'] as String? ?? '',
    items: _objects(json['items']).map(RecipientOption.fromJson).toList(),
  );
}

// -------------------------------------------------------------------------
// -- Step-up --------------------------------------------------------------
// -------------

/// An emailed one-time code, and when another may be asked for.
class StepUpChallenge {
  const StepUpChallenge({
    required this.challengeId,
    this.expiresAt,
    this.delivery = 'email',
    this.resendAvailableAt,
  });

  final String challengeId;
  final DateTime? expiresAt;
  final String delivery;
  final DateTime? resendAvailableAt;

  factory StepUpChallenge.fromJson(Map<String, dynamic> json) =>
      StepUpChallenge(
        challengeId: json['challengeId'] as String? ?? '',
        expiresAt: _date(json['expiresAt']),
        delivery: json['delivery'] as String? ?? 'email',
        resendAvailableAt: _date(json['resendAvailableAt']),
      );
}

// -------------------------------------------------------------------------
// -- Funds ----------------------------------------------------------------
// -----------

/// A purpose a giver can choose between.
class GivingFund {
  const GivingFund({
    required this.id,
    required this.slug,
    required this.name,
    this.creatorId = '',
    this.description,
    this.active = true,
    this.giftCount = 0,
    this.donorCount = 0,
    this.totalsByCurrency = const [],
  });

  final String id;
  final String creatorId;
  final String slug;
  final String name;
  final String? description;
  final bool active;
  final int giftCount;
  final int donorCount;

  /// Finalized totals, bucketed by settlement currency and never summed.
  final List<Money> totalsByCurrency;

  static const generalSlug = 'general';

  bool get isGeneral => slug == generalSlug;

  factory GivingFund.fromJson(Map<String, dynamic> json) => GivingFund(
    id: json['id'] as String? ?? '',
    creatorId: json['creatorId'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    active: json['active'] as bool? ?? true,
    giftCount: (json['giftCount'] as num?)?.toInt() ?? 0,
    donorCount: (json['donorCount'] as num?)?.toInt() ?? 0,
    // The row has been seen wrapped in `total` and flat; anything else is
    // skipped rather than cast, because one unreadable bucket must not take
    // the whole fund list down with it.
    totalsByCurrency: [
      for (final entry in _objects(json['totalsByCurrency']))
        ?(Money.maybe(entry['total']) ??
            Money.maybe(entry['gross']) ??
            (entry.containsKey('currency') ? Money.fromJson(entry) : null)),
    ],
  );
}

/// How many funds this creator's plan allows.
class FundLimits {
  const FundLimits({
    this.maxFunds,
    this.currentFunds = 0,
    this.canCreate = false,
  });

  /// Null means unlimited.
  final int? maxFunds;
  final int currentFunds;
  final bool canCreate;

  factory FundLimits.fromJson(Map<String, dynamic> json) => FundLimits(
    maxFunds: (json['maxFunds'] as num?)?.toInt(),
    currentFunds: (json['currentFunds'] as num?)?.toInt() ?? 0,
    canCreate: json['canCreate'] as bool? ?? false,
  );
}

/// The fund list and the plan limit that governs it.
class GivingFundList {
  const GivingFundList({
    this.funds = const [],
    this.limits = const FundLimits(),
  });

  final List<GivingFund> funds;
  final FundLimits limits;

  factory GivingFundList.fromJson(Map<String, dynamic> json) => GivingFundList(
    funds: _objects(json['funds']).map(GivingFund.fromJson).toList(),
    limits: FundLimits.fromJson(
      (json['limits'] as Map<String, dynamic>?) ?? const {},
    ),
  );
}

// -------------------------------------------------------------------------
// -- Reporting ------------------------------------------------------------
// ---------------

/// One settlement currency's totals. Never added to another's.
class CurrencyTotals {
  const CurrencyTotals({
    required this.settlementCurrency,
    required this.gross,
    required this.processingFees,
    required this.platformFees,
    required this.creatorNet,
    required this.refunded,
    required this.disputed,
  });

  final String settlementCurrency;
  final Money gross;
  final Money processingFees;
  final Money platformFees;

  /// An **estimate** until the provider's actuals arrive. The guide forbids
  /// showing it as finalized earnings, which is why the screen labels it
  /// "estimated proceeds" rather than a balance.
  final Money creatorNet;

  final Money refunded;
  final Money disputed;

  /// What GospelTube took, for the line under the givers count.
  Money get platformFeesTotal => platformFees;

  factory CurrencyTotals.fromJson(Map<String, dynamic> json) {
    final currency = json['settlementCurrency'] as String? ?? '';
    Money read(String key) =>
        Money.maybe(json[key]) ??
        Money(currency: currency, amountMinor: 0, amount: 0);
    return CurrencyTotals(
      settlementCurrency: currency,
      gross: read('gross'),
      processingFees: read('processingFees'),
      platformFees: read('platformFees'),
      creatorNet: read('creatorNet'),
      refunded: read('refunded'),
      disputed: read('disputed'),
    );
  }
}

/// Whether a rail's balance can be read, and what may be done with it.
enum FundsAvailability {
  /// A direct rail, reporting the PSP's own figures. No withdrawal.
  providerReported('provider_reported'),

  /// A provider-held rail with a released balance to withdraw.
  withdrawable('withdrawable'),

  /// The balance could not be retrieved. Said out loud, never shown as zero.
  notAvailable('not_available');

  const FundsAvailability(this.wire);

  final String wire;

  static FundsAvailability from(String? wire) {
    for (final value in values) {
      if (value.wire == wire) return value;
    }
    return FundsAvailability.notAvailable;
  }
}

/// What one rail is holding, by whichever measure applies to it.
class RailFunds {
  const RailFunds({
    required this.railId,
    required this.provider,
    required this.settlementCurrency,
    this.custodyMode = CustodyMode.direct,
    this.availability = FundsAvailability.notAvailable,
    this.pending,
    this.available,
    this.scheduled,
    this.held,
    this.released,
    this.pendingPayout,
    this.nextReleaseAt,
  });

  final String railId;
  final PaymentProvider? provider;
  final CustodyMode custodyMode;
  final String settlementCurrency;
  final FundsAvailability availability;

  /// Direct rails only, and only when the provider exposes them.
  final Money? pending;
  final Money? available;
  final Money? scheduled;

  /// Provider-held rails: still inside the hold window.
  final Money? held;

  /// Provider-held rails: cumulative amount already released.
  final Money? released;

  /// Committed to a withdrawal already requested. A second request is
  /// **refused** while this is non-null, so the action is disabled rather
  /// than offered and failed.
  final Money? pendingPayout;

  final DateTime? nextReleaseAt;

  bool get hasPayoutInFlight => pendingPayout != null;

  /// The provider was asked and could not say. Not the same as nothing
  /// having arrived yet.
  bool get isUnavailable => availability == FundsAvailability.notAvailable;

  /// Withdrawal is offered only on a provider-held rail that says it is
  /// withdrawable and has nothing already in flight.
  bool get canWithdraw =>
      custodyMode.isProviderHeld &&
      availability == FundsAvailability.withdrawable &&
      (available?.amountMinor ?? 0) > 0 &&
      !hasPayoutInFlight;

  factory RailFunds.fromJson(Map<String, dynamic> json) => RailFunds(
    railId: json['railId'] as String? ?? '',
    provider: PaymentProvider.from(json['paymentProvider'] as String?),
    custodyMode: CustodyMode.from(json['custodyMode'] as String?),
    settlementCurrency: json['settlementCurrency'] as String? ?? '',
    availability: FundsAvailability.from(json['availability'] as String?),
    pending: Money.maybe(json['pending']),
    available: Money.maybe(json['available']),
    scheduled: Money.maybe(json['scheduled']),
    held: Money.maybe(json['held']),
    released: Money.maybe(json['released']),
    pendingPayout: Money.maybe(json['pendingPayout']),
    nextReleaseAt: _date(json['nextReleaseAt']),
  );
}

/// Provider-reported totals for a window.
class EarningsSummary {
  const EarningsSummary({
    this.dataSource = 'provider_reported',
    this.activeSettlementCurrency,
    this.giftCount = 0,
    this.donorCount = 0,
    this.totalsByCurrency = const [],
    this.fundsByRail = const [],
  });

  final String dataSource;

  /// The primary rail's settlement currency, and null before any rail is
  /// enrolled — which is how the screen knows it has nothing to show yet.
  final String? activeSettlementCurrency;

  final int giftCount;
  final int donorCount;
  final List<CurrencyTotals> totalsByCurrency;
  final List<RailFunds> fundsByRail;

  bool get isEmpty => totalsByCurrency.isEmpty && giftCount == 0;

  /// Whether any rail is enrolled at all.
  bool get hasRails => fundsByRail.isNotEmpty;

  /// The bucket the screen leads with: the active settlement currency's, or
  /// the first one returned.
  CurrencyTotals? get primary {
    if (totalsByCurrency.isEmpty) return null;
    for (final totals in totalsByCurrency) {
      if (totals.settlementCurrency == activeSettlementCurrency) return totals;
    }
    return totalsByCurrency.first;
  }

  /// The rail a withdrawal would come from, if any offers one.
  RailFunds? get withdrawable {
    for (final rail in fundsByRail) {
      if (rail.custodyMode.isProviderHeld) return rail;
    }
    return null;
  }

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        dataSource: json['dataSource'] as String? ?? 'provider_reported',
        activeSettlementCurrency: json['activeSettlementCurrency'] as String?,
        giftCount: (json['giftCount'] as num?)?.toInt() ?? 0,
        donorCount: (json['donorCount'] as num?)?.toInt() ?? 0,
        totalsByCurrency: _objects(
          json['totalsByCurrency'],
        ).map(CurrencyTotals.fromJson).toList(),
        fundsByRail: _objects(
          json['fundsByRail'],
        ).map(RailFunds.fromJson).toList(),
      );
}

/// One gift, settlement, payout or refund row.
class GivingRecord {
  const GivingRecord({
    required this.id,
    required this.amount,
    this.fundName = '',
    this.donorName = '',
    this.createdAt,
    this.status = '',
    this.statusLabel = '',
    this.provider,
    this.railId = '',
    this.automatic,
  });

  final String id;

  /// What the row is worth, in the settlement currency.
  final Money amount;

  final String fundName;

  /// Degrades to a neutral "Giver" when the donor lookup fails — financial
  /// history stays readable either way.
  final String donorName;

  final DateTime? createdAt;
  final String status;

  /// The wording the row shows: "Settlement finalized", "Under review".
  final String statusLabel;

  final PaymentProvider? provider;
  final String railId;

  /// Payout rows only. `false` marks a release on a provider-held rail —
  /// either one GospelTube released on schedule or one the creator asked
  /// for. The guide says to label it "release", not "payout".
  final bool? automatic;

  factory GivingRecord.fromJson(Map<String, dynamic> json) {
    final fund = (json['fund'] as Map<String, dynamic>?) ?? const {};
    final donor = (json['donor'] as Map<String, dynamic>?) ?? const {};
    final amount =
        Money.maybe(json['creatorNet']) ??
        Money.maybe(json['amount']) ??
        Money.maybe(json['gross']) ??
        Money.maybe(json['net']) ??
        Money.zeroNgn;
    return GivingRecord(
      id:
          json['id'] as String? ??
          json['givingPaymentId'] as String? ??
          json['settlementId'] as String? ??
          '',
      amount: amount,
      fundName: fund['name'] as String? ?? json['fundName'] as String? ?? '',
      donorName:
          donor['displayName'] as String? ??
          json['donorDisplayName'] as String? ??
          AppStrings.givingNeutralDonor,
      createdAt: _date(json['createdAt'] ?? json['paidAt']),
      status:
          json['settlementStatus'] as String? ??
          json['status'] as String? ??
          '',
      statusLabel:
          json['statusLabel'] as String? ??
          _settlementLabel(
            json['settlementStatus'] as String? ?? json['status'] as String?,
          ),
      provider: PaymentProvider.from(json['paymentProvider'] as String?),
      railId: json['railId'] as String? ?? '',
      automatic: json['automatic'] as bool?,
    );
  }

  static String _settlementLabel(String? status) => switch (status) {
    'finalized' => AppStrings.givingStatusFinalized,
    'pending_provider_truth' => AppStrings.givingStatusUnderReview,
    'needs_review' => AppStrings.givingStatusNeedsReview,
    'refunded' || 'partially_refunded' => AppStrings.givingStatusRefunded,
    null || '' => '',
    _ => AppStrings.givingStatusPending,
  };
}

/// One page of a reporting list.
class GivingRecordPage {
  const GivingRecordPage({this.items = const [], this.nextCursor});

  final List<GivingRecord> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  factory GivingRecordPage.fromJson(Map<String, dynamic> json) =>
      GivingRecordPage(
        items: _objects(json['items']).map(GivingRecord.fromJson).toList(),
        nextCursor: json['nextCursor'] as String?,
      );
}

/// A bank a payout can be sent to.
class PayoutBank {
  const PayoutBank({
    required this.id,
    required this.name,
    this.code = '',
    this.country = '',
    this.currency = '',
  });

  final String id;
  final String name;
  final String code;
  final String country;
  final String currency;

  factory PayoutBank.fromJson(Map<String, dynamic> json) => PayoutBank(
    id: json['id'] as String? ?? json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    code: json['code'] as String? ?? '',
    country: json['country'] as String? ?? '',
    currency: json['currency'] as String? ?? '',
  );
}

// ---------------------------------------------------------------------------

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const <String>[];

List<Map<String, dynamic>> _objects(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList()
    : const <Map<String, dynamic>>[];

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
