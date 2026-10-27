import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/creator_setup_fields.dart';
import 'package:test_app/features/creator/views/widgets/giving_parts.dart';
import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/data/countries.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The dialogs the Giving section opens.
///
/// All of them are centred cards rather than bottom sheets, which is what
/// the design draws and what suits a form whose footer must stay in view
/// while the keyboard is up.
///
/// None of them writes anything. Each collects what it needs, validates what
/// it can on the device, and hands a value back — the screen owns the call,
/// so a refusal is reported in one place and the dialog cannot be left
/// half-committed.

/// A centred modal with a title, a scrolling body and a pinned footer.
class _GivingDialog extends StatelessWidget {
  const _GivingDialog({
    required this.title,
    required this.children,
    this.subtitle,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.base2,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 40.s),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.s)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.s, 20.s, 20.s, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppStyles.heading(20)),
                      if (subtitle case final line?) ...[
                        SizedBox(height: 6.s),
                        Text(
                          line,
                          style: AppStyles.body(
                            13,
                            color: AppColors.neutral400,
                            lineHeight: 18 / 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 12.s),
                GestureDetector(
                  key: const ValueKey('giving-dialog-close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: AppColors.textPrimary,
                    size: 20.s,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 18.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
          if (footer case final actions?)
            Container(
              padding: EdgeInsets.fromLTRB(20.s, 14.s, 20.s, 20.s),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.neutral900)),
              ),
              child: actions,
            ),
        ],
      ),
    );
  }
}

/// A field's caption, in the dialogs' smaller type.
///
/// The caption is [Flexible] because these dialogs put two fields side by
/// side: "Settlement country *" overran half of a 320pt dialog by about four
/// pixels, which is a red stripe on every small phone. It wraps instead.
class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 6.s),
    child: Row(
      children: [
        Flexible(child: CreatorFieldLabel(text)),
        if (required)
          Text(' *', style: AppStyles.label(12, color: AppColors.brandPrimary)),
      ],
    ),
  );
}

/// "NG" as "Nigeria".
///
/// The routes speak ISO codes and the design speaks country names. An
/// unknown code prints itself rather than a blank — it is still true.
String givingCountryName(String? code) =>
    Countries.byIsoCode(code)?.name ?? code ?? '';

/// A message under a field, or under the whole form.
class _Problem extends StatelessWidget {
  const _Problem(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) {
    final message = text;
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 10.s),
      child: Text(
        message,
        key: const ValueKey('giving-problem'),
        style: AppStyles.label(12, color: AppColors.red500),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picker
// ---------------------------------------------------------------------------

/// One choice out of a list, for every dropdown in this section.
class GivingPickerSheet<T> extends StatelessWidget {
  const GivingPickerSheet({
    super.key,
    required this.title,
    required this.options,
    required this.labelOf,
    this.selected,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final T? selected;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    T? selected,
  }) => showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => GivingPickerSheet<T>(
      title: title,
      options: options,
      labelOf: labelOf,
      selected: selected,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 80),
      decoration: BoxDecoration(
        color: AppColors.base2,
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
                padding: EdgeInsets.fromLTRB(20.s, 18.s, 20.s, 10.s),
                child: Text(
                  title,
                  style: AppStyles.label(
                    13,
                    weight: AppStyles.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(12.s, 0, 12.s, 16.s),
                  children: [
                    for (final option in options)
                      GestureDetector(
                        key: ValueKey('pick-${labelOf(option)}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(context, option),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.s,
                            vertical: 14.s,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  labelOf(option),
                                  style: AppStyles.body(14),
                                ),
                              ),
                              if (option == selected)
                                Icon(
                                  Icons.check,
                                  size: 16.s,
                                  color: AppColors.brandPrimary,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Turn on Giving
// ---------------------------------------------------------------------------

/// What the application needs: who is being paid, and under what law.
class RecipientDetails {
  const RecipientDetails({
    required this.countryCode,
    required this.classification,
    required this.legalName,
  });

  final String countryCode;
  final LegalClassification classification;
  final String legalName;
}

/// "Turn on Giving" — the legal recipient and the terms.
///
/// The country and structure lists are the server's `options`, not a
/// hardcoded set: policy decides what may be enrolled, and offering a
/// combination it does not allow only produces a refusal later.
class TurnOnGivingSheet extends StatefulWidget {
  const TurnOnGivingSheet({
    super.key,
    required this.options,
    this.initialName = '',
  });

  final GivingOptions options;

  /// The studio's display name, which is the right first guess at the legal
  /// recipient for an individual and a starting point for an organisation.
  final String initialName;

  static Future<RecipientDetails?> show(
    BuildContext context, {
    required GivingOptions options,
    String initialName = '',
  }) => showDialog<RecipientDetails>(
    context: context,
    barrierColor: AppColors.overlayDark,
    builder: (_) =>
        TurnOnGivingSheet(options: options, initialName: initialName),
  );

  @override
  State<TurnOnGivingSheet> createState() => _TurnOnGivingSheetState();
}

class _TurnOnGivingSheetState extends State<TurnOnGivingSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late String _country = widget.options.countries.firstOrNull ?? '';
  LegalClassification? _classification;
  bool _accepted = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _classification = _classifications.firstOrNull;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<LegalClassification> get _classifications =>
      widget.options.classificationsFor(_country);

  void _submit() {
    final classification = _classification;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _problem = AppStrings.givingNameRequired);
      return;
    }
    if (!_accepted) {
      setState(() => _problem = AppStrings.givingTermsRequired);
      return;
    }
    if (classification == null || _country.isEmpty) {
      setState(() => _problem = AppStrings.givingNoOptions);
      return;
    }
    Navigator.pop(
      context,
      RecipientDetails(
        countryCode: _country,
        classification: classification,
        legalName: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GivingDialog(
      title: AppStrings.givingTurnOnTitle,
      subtitle: AppStrings.givingTurnOnBody,
      footer: PrimaryButton(
        key: const ValueKey('giving-save-recipient'),
        label: AppStrings.givingSaveAndChooseRails,
        onPressed: _submit,
      ),
      children: [
        const GivingInfoNote(AppStrings.givingSettleNote),
        SizedBox(height: 16.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Label(
                    AppStrings.givingRecipientCountry,
                    required: true,
                  ),
                  CreatorSelectField(
                    key: const ValueKey('giving-country'),
                    hint: AppStrings.givingRecipientCountry,
                    value: givingCountryName(_country),
                    contentPadding: EdgeInsets.all(12.s),
                    onTap: _pickCountry,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Label(AppStrings.givingLegalStructure, required: true),
                  CreatorSelectField(
                    key: const ValueKey('giving-classification'),
                    hint: AppStrings.givingLegalStructure,
                    value: _classification?.label,
                    contentPadding: EdgeInsets.all(12.s),
                    onTap: _pickClassification,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16.s),
        const _Label(AppStrings.givingLegalName, required: true),
        CreatorTextField(
          key: const ValueKey('giving-legal-name'),
          controller: _name,
          hint: AppStrings.givingLegalName,
          contentPadding: EdgeInsets.all(12.s),
        ),
        SizedBox(height: 8.s),
        Text(
          AppStrings.givingLegalNameHint,
          style: AppStyles.label(11, color: AppColors.neutral500),
        ),
        SizedBox(height: 16.s),
        Divider(color: AppColors.neutral900, height: 1.s),
        SizedBox(height: 14.s),
        GestureDetector(
          key: const ValueKey('giving-accept-terms'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _accepted = !_accepted),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18.s,
                height: 18.s,
                margin: EdgeInsets.only(top: 2.s),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accepted
                      ? AppColors.brandPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4.s),
                  border: Border.all(
                    color: _accepted
                        ? AppColors.brandPrimary
                        : AppColors.neutral700,
                  ),
                ),
                child: _accepted
                    ? Icon(Icons.check, size: 12.s, color: AppColors.base1)
                    : const SizedBox.shrink(),
              ),
              SizedBox(width: 10.s),
              Expanded(
                child: Text(
                  // The version is the server's, shown rather than hidden:
                  // this is the thing being agreed to, and a stale one is
                  // refused on submit.
                  AppStrings.givingTermsAccept(widget.options.termsVersion),
                  style: AppStyles.body(
                    12,
                    color: AppColors.neutral200,
                    lineHeight: 17 / 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.s),
        Text(
          AppStrings.givingNotTaxReceipts,
          style: AppStyles.label(
            11,
            color: AppColors.neutral500,
            lineHeight: 15 / 11,
          ),
        ),
        _Problem(_problem),
      ],
    );
  }

  Future<void> _pickCountry() async {
    final picked = await GivingPickerSheet.show<String>(
      context,
      title: AppStrings.givingRecipientCountry,
      options: widget.options.countries,
      labelOf: givingCountryName,
      selected: _country,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _country = picked;
      // The structures on offer belong to the country, so a change here
      // cannot leave the previous country's choice standing.
      _classification = _classifications.firstOrNull;
    });
  }

  Future<void> _pickClassification() async {
    final picked = await GivingPickerSheet.show<LegalClassification>(
      context,
      title: AppStrings.givingLegalStructure,
      options: _classifications,
      labelOf: (value) => value.label,
      selected: _classification,
    );
    if (picked == null || !mounted) return;
    setState(() => _classification = picked);
  }
}

// ---------------------------------------------------------------------------
// Rail setup
// ---------------------------------------------------------------------------

/// "khaime payment setup" — which of a provider's routes to enrol.
///
/// A provider may be offered in more than one country and currency, so the
/// pair is chosen here and the enrolment that follows is for exactly one
/// combination the server returned.
class RailSetupSheet extends StatefulWidget {
  const RailSetupSheet({
    super.key,
    required this.provider,
    required this.options,
  });

  final PaymentProvider provider;

  /// This provider's rows out of `application/options`.
  final List<RecipientOption> options;

  static Future<RecipientOption?> show(
    BuildContext context, {
    required PaymentProvider provider,
    required List<RecipientOption> options,
  }) => showDialog<RecipientOption>(
    context: context,
    barrierColor: AppColors.overlayDark,
    builder: (_) => RailSetupSheet(provider: provider, options: options),
  );

  @override
  State<RailSetupSheet> createState() => _RailSetupSheetState();
}

class _RailSetupSheetState extends State<RailSetupSheet> {
  late RecipientOption? _choice = widget.options.firstOrNull;

  List<String> get _countries {
    final seen = <String>[];
    for (final option in widget.options) {
      if (!seen.contains(option.countryCode)) seen.add(option.countryCode);
    }
    return seen;
  }

  List<String> get _currencies {
    final country = _choice?.countryCode;
    final seen = <String>[];
    for (final option in widget.options) {
      if (option.countryCode != country) continue;
      if (!seen.contains(option.settlementCurrency)) {
        seen.add(option.settlementCurrency);
      }
    }
    return seen;
  }

  @override
  Widget build(BuildContext context) {
    final choice = _choice;
    return _GivingDialog(
      title: AppStrings.givingRailSetupTitle(widget.provider.label),
      subtitle: AppStrings.givingRailSetupBody,
      footer: PrimaryButton(
        key: const ValueKey('giving-connect-securely'),
        label: AppStrings.givingConnectSecurely,
        enabled: choice != null,
        onPressed: () => Navigator.pop(context, choice),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Label(
                    AppStrings.givingSettlementCountry,
                    required: true,
                  ),
                  CreatorSelectField(
                    key: const ValueKey('rail-country'),
                    hint: AppStrings.givingSettlementCountry,
                    value: choice == null
                        ? null
                        : givingCountryName(choice.countryCode),
                    contentPadding: EdgeInsets.all(12.s),
                    onTap: _pickCountry,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Label(
                    AppStrings.givingSettlementCurrency,
                    required: true,
                  ),
                  CreatorSelectField(
                    key: const ValueKey('rail-currency'),
                    hint: AppStrings.givingSettlementCurrency,
                    value: choice?.settlementCurrency,
                    contentPadding: EdgeInsets.all(12.s),
                    onTap: _pickCurrency,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 18.s),
        Divider(color: AppColors.neutral900, height: 1.s),
        SizedBox(height: 14.s),
        Text(
          AppStrings.givingStepUpNote,
          style: AppStyles.label(
            11,
            color: AppColors.neutral500,
            lineHeight: 15 / 11,
          ),
        ),
      ],
    );
  }

  Future<void> _pickCountry() async {
    final picked = await GivingPickerSheet.show<String>(
      context,
      title: AppStrings.givingSettlementCountry,
      options: _countries,
      labelOf: givingCountryName,
      selected: _choice?.countryCode,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _choice = widget.options.firstWhere(
        (option) => option.countryCode == picked,
        orElse: () => widget.options.first,
      );
    });
  }

  Future<void> _pickCurrency() async {
    final picked = await GivingPickerSheet.show<String>(
      context,
      title: AppStrings.givingSettlementCurrency,
      options: _currencies,
      labelOf: (code) => code,
      selected: _choice?.settlementCurrency,
    );
    if (picked == null || !mounted) return;
    final country = _choice?.countryCode;
    setState(() {
      _choice = widget.options.firstWhere(
        (option) =>
            option.countryCode == country &&
            option.settlementCurrency == picked,
        orElse: () => widget.options.first,
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Step-up
// ---------------------------------------------------------------------------

/// The emailed code that unlocks an enrolment or a configuration change.
///
/// The code goes to the account email and never comes back on the challenge
/// response, so there is nothing here to prefill and nothing to log. The
/// grant it mints lives five minutes and is spent on the next call.
class StepUpCodeSheet extends StatefulWidget {
  const StepUpCodeSheet({
    super.key,
    required this.title,
    required this.onResend,
    this.body,
  });

  final String title;
  final String? body;

  /// Asking for another code. The dialog stays open — a creator who waited
  /// for a second email should not have to find their way back here.
  final Future<void> Function() onResend;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required Future<void> Function() onResend,
    String? body,
  }) => showDialog<String>(
    context: context,
    barrierColor: AppColors.overlayDark,
    builder: (_) =>
        StepUpCodeSheet(title: title, onResend: onResend, body: body),
  );

  @override
  State<StepUpCodeSheet> createState() => _StepUpCodeSheetState();
}

class _StepUpCodeSheetState extends State<StepUpCodeSheet> {
  final _code = TextEditingController();
  String? _problem;
  String? _note;
  bool _resending = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _problem = AppStrings.givingCodeRequired);
      return;
    }
    Navigator.pop(context, code);
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await widget.onResend();
      if (mounted) {
        setState(() {
          _note = AppStrings.givingCodeSent;
          _problem = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _problem = AppStrings.givingWriteFailed);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GivingDialog(
      title: widget.title,
      subtitle: widget.body ?? AppStrings.givingStepUpBody,
      footer: Row(
        children: [
          GestureDetector(
            key: const ValueKey('giving-resend'),
            behavior: HitTestBehavior.opaque,
            onTap: _resending ? null : _resend,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.s, horizontal: 4.s),
              child: Text(
                AppStrings.givingResendCode,
                style: AppStyles.button(
                  13,
                  color: _resending
                      ? AppColors.neutral500
                      : AppColors.brandPrimary,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.s),
          Expanded(
            child: PrimaryButton(
              key: const ValueKey('giving-verify'),
              label: AppStrings.givingVerifyAndContinue,
              onPressed: _submit,
            ),
          ),
        ],
      ),
      children: [
        const GivingInfoNote(AppStrings.givingStepUpHint),
        SizedBox(height: 16.s),
        const _Label(AppStrings.givingVerificationCode),
        CreatorTextField(
          key: const ValueKey('giving-code'),
          controller: _code,
          hint: AppStrings.givingCodeHint,
          keyboardType: TextInputType.number,
          contentPadding: EdgeInsets.all(12.s),
        ),
        if (_note case final note?)
          Padding(
            padding: EdgeInsets.only(top: 10.s),
            child: Text(
              note,
              style: AppStyles.label(12, color: AppColors.green500),
            ),
          ),
        _Problem(_problem),
      ],
    );
  }
}

/// "Update Khaime settlement account" — the versioned change.
///
/// What this cannot do is switch providers, which is why that is said on the
/// dialog rather than discovered through a refusal: another provider is
/// another rail.
class UpdateSettlementSheet extends StatefulWidget {
  const UpdateSettlementSheet({
    super.key,
    required this.rail,
    required this.options,
    required this.legalName,
    required this.classification,
  });

  final GivingRail rail;
  final List<RecipientOption> options;
  final String legalName;
  final LegalClassification classification;

  static Future<ConfigurationChange?> show(
    BuildContext context, {
    required GivingRail rail,
    required List<RecipientOption> options,
    required String legalName,
    required LegalClassification classification,
  }) => showDialog<ConfigurationChange>(
    context: context,
    barrierColor: AppColors.overlayDark,
    builder: (_) => UpdateSettlementSheet(
      rail: rail,
      options: options,
      legalName: legalName,
      classification: classification,
    ),
  );

  @override
  State<UpdateSettlementSheet> createState() => _UpdateSettlementSheetState();
}

/// What a creator asked to change, and which operation that is.
class ConfigurationChange {
  const ConfigurationChange({
    required this.operation,
    required this.countryCode,
    required this.settlementCurrency,
    required this.legalName,
  });

  /// `replace_destination`, `change_country`, `change_currency` or
  /// `change_legal_recipient` — derived from what actually moved rather than
  /// asked for, because a creator thinks in fields, not operations.
  final String operation;

  final String countryCode;
  final String settlementCurrency;
  final String legalName;
}

class _UpdateSettlementSheetState extends State<UpdateSettlementSheet> {
  late final _name = TextEditingController(text: widget.legalName);
  late String _country = widget.rail.countryCode;
  late String _currency = widget.rail.settlementCurrency;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<String> get _countries {
    final seen = <String>[];
    for (final option in widget.options) {
      if (!seen.contains(option.countryCode)) seen.add(option.countryCode);
    }
    if (!seen.contains(widget.rail.countryCode)) {
      seen.insert(0, widget.rail.countryCode);
    }
    return seen;
  }

  List<String> get _currencies {
    final seen = <String>[];
    for (final option in widget.options) {
      if (option.countryCode != _country) continue;
      if (!seen.contains(option.settlementCurrency)) {
        seen.add(option.settlementCurrency);
      }
    }
    if (seen.isEmpty) seen.add(widget.rail.settlementCurrency);
    return seen;
  }

  /// Which of the four operations this is.
  ///
  /// The order matters: country implies currency, and a rename alone is the
  /// weakest claim, so the strongest change that actually happened wins.
  String? get _operation {
    if (_country != widget.rail.countryCode) return 'change_country';
    if (_currency != widget.rail.settlementCurrency) return 'change_currency';
    if (_name.text.trim() != widget.legalName) return 'change_legal_recipient';
    return null;
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _problem = AppStrings.givingNameRequired);
      return;
    }
    // Nothing moved, so there is nothing to version. Replacing the
    // destination is the honest reading of "I opened this and pressed save".
    final operation = _operation ?? 'replace_destination';
    Navigator.pop(
      context,
      ConfigurationChange(
        operation: operation,
        countryCode: _country,
        settlementCurrency: _currency,
        legalName: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _GivingDialog(
      title: AppStrings.givingStepUpUpdateTitle(
        widget.rail.provider?.label ?? '',
      ),
      subtitle: AppStrings.givingStepUpBody,
      footer: PrimaryButton(
        key: const ValueKey('giving-update-connect'),
        label: AppStrings.givingConnectSecurely,
        onPressed: _submit,
      ),
      children: [
        const GivingInfoNote(AppStrings.givingChangeProviderNote),
        SizedBox(height: 16.s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Label(
                    AppStrings.givingSettlementCountry,
                    required: true,
                  ),
                  CreatorSelectField(
                    key: const ValueKey('update-country'),
                    hint: AppStrings.givingSettlementCountry,
                    value: givingCountryName(_country),
                    contentPadding: EdgeInsets.all(12.s),
                    onTap: () async {
                      final picked = await GivingPickerSheet.show<String>(
                        context,
                        title: AppStrings.givingSettlementCountry,
                        options: _countries,
                        labelOf: givingCountryName,
                        selected: _country,
                      );
                      if (picked == null || !mounted) return;
                      setState(() {
                        _country = picked;
                        _currency = _currencies.first;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Label(
                    AppStrings.givingSettlementCurrency,
                    required: true,
                  ),
                  CreatorSelectField(
                    key: const ValueKey('update-currency'),
                    hint: AppStrings.givingSettlementCurrency,
                    value: _currency,
                    contentPadding: EdgeInsets.all(12.s),
                    onTap: () async {
                      final picked = await GivingPickerSheet.show<String>(
                        context,
                        title: AppStrings.givingSettlementCurrency,
                        options: _currencies,
                        labelOf: (code) => code,
                        selected: _currency,
                      );
                      if (picked == null || !mounted) return;
                      setState(() => _currency = picked);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 18.s),
        Divider(color: AppColors.neutral900, height: 1.s),
        SizedBox(height: 14.s),
        const _Label(AppStrings.givingLegalName, required: true),
        CreatorTextField(
          key: const ValueKey('update-legal-name'),
          controller: _name,
          hint: AppStrings.givingLegalName,
          contentPadding: EdgeInsets.all(12.s),
        ),
        SizedBox(height: 8.s),
        Text(
          AppStrings.givingLegalNameMatchNote,
          style: AppStyles.label(
            11,
            color: AppColors.neutral500,
            lineHeight: 15 / 11,
          ),
        ),
        _Problem(_problem),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Funds
// ---------------------------------------------------------------------------

/// A fund's name and purpose.
class FundDraft {
  const FundDraft({required this.name, required this.description});

  final String name;
  final String description;
}

/// "New giving fund" — and the same dialog for editing one.
///
/// A fund's slug is immutable, so editing changes only what givers read.
/// That is why there is no slug field here to mislead anyone into thinking
/// an old shared link could be repointed.
class FundSheet extends StatefulWidget {
  const FundSheet({super.key, this.fund});

  final GivingFund? fund;

  static Future<FundDraft?> show(BuildContext context, {GivingFund? fund}) =>
      showDialog<FundDraft>(
        context: context,
        barrierColor: AppColors.overlayDark,
        builder: (_) => FundSheet(fund: fund),
      );

  @override
  State<FundSheet> createState() => _FundSheetState();
}

class _FundSheetState extends State<FundSheet> {
  late final _name = TextEditingController(text: widget.fund?.name ?? '');
  late final _description = TextEditingController(
    text: widget.fund?.description ?? '',
  );
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _problem = AppStrings.givingFundNameRequired);
      return;
    }
    Navigator.pop(
      context,
      FundDraft(name: name, description: _description.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.fund != null;
    return _GivingDialog(
      title: editing
          ? AppStrings.givingEditFundTitle
          : AppStrings.givingNewFundTitle,
      subtitle: AppStrings.givingFundPurpose,
      footer: Align(
        alignment: Alignment.centerRight,
        child: PrimaryButton(
          key: const ValueKey('giving-save-fund'),
          label: editing
              ? AppStrings.givingSaveFund
              : AppStrings.givingCreateFund,
          onPressed: _submit,
        ),
      ),
      children: [
        const _Label(AppStrings.givingFundName),
        CreatorTextField(
          key: const ValueKey('fund-name'),
          controller: _name,
          hint: AppStrings.givingFundNameHint,
          contentPadding: EdgeInsets.all(12.s),
        ),
        SizedBox(height: 16.s),
        const _Label(AppStrings.givingFundWhatFor),
        CreatorTextField(
          key: const ValueKey('fund-description'),
          controller: _description,
          hint: AppStrings.givingFundWhatForHint,
          maxLines: 4,
          contentPadding: EdgeInsets.all(12.s),
        ),
        SizedBox(height: 8.s),
        Text(
          AppStrings.givingFundSeenBy,
          style: AppStyles.label(11, color: AppColors.neutral500),
        ),
        if (widget.fund?.isGeneral ?? false) ...[
          SizedBox(height: 10.s),
          Text(
            AppStrings.givingFundGeneralLocked,
            style: AppStyles.label(
              11,
              color: AppColors.neutral500,
              lineHeight: 15 / 11,
            ),
          ),
        ],
        _Problem(_problem),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Payout
// ---------------------------------------------------------------------------

/// Withdrawing part of a provider-held balance.
///
/// Only ever opened for a rail whose `availability` is `withdrawable` and
/// which has nothing in flight — the server refuses a second request, so the
/// caller disables the action rather than letting this dialog fail.
class PayoutSheet extends StatefulWidget {
  const PayoutSheet({super.key, required this.available});

  final Money available;

  /// The amount in **minor units**, which is what the route takes.
  static Future<int?> show(BuildContext context, {required Money available}) =>
      showDialog<int>(
        context: context,
        barrierColor: AppColors.overlayDark,
        builder: (_) => PayoutSheet(available: available),
      );

  @override
  State<PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<PayoutSheet> {
  late final _amount = TextEditingController(
    text: widget.available.amount.toStringAsFixed(2),
  );
  String? _problem;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (typed == null || typed <= 0) {
      setState(() => _problem = AppStrings.earningsPayoutAmountRequired);
      return;
    }
    // Compared in major units against the server's own figure, then handed
    // over in minor ones. The ratio between the two is taken from the
    // balance itself rather than from a currency-exponent table the client
    // has no business keeping.
    if (typed > widget.available.amount) {
      setState(
        () => _problem = AppStrings.earningsPayoutTooMuch(
          widget.available.display,
        ),
      );
      return;
    }
    final perMajor = widget.available.amount == 0
        ? 100
        : widget.available.amountMinor / widget.available.amount;
    Navigator.pop(context, (typed * perMajor).round());
  }

  @override
  Widget build(BuildContext context) {
    return _GivingDialog(
      title: AppStrings.earningsPayoutTitle,
      subtitle: AppStrings.earningsPayoutBody(widget.available.display),
      footer: PrimaryButton(
        key: const ValueKey('giving-request-payout'),
        label: AppStrings.earningsPayoutConfirm,
        onPressed: _submit,
      ),
      children: [
        const _Label(AppStrings.earningsPayoutAmount),
        CreatorTextField(
          key: const ValueKey('payout-amount'),
          controller: _amount,
          hint: AppStrings.earningsPayoutAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          contentPadding: EdgeInsets.all(12.s),
        ),
        _Problem(_problem),
      ],
    );
  }
}

/// Put something on the clipboard and say so.
Future<void> copyAndTell(
  BuildContext context,
  String value,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppStyles.body(13)),
      backgroundColor: AppColors.neutral800,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
