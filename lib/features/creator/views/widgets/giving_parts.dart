import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/creator_models/giving_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The pieces the four Giving screens are assembled from.
///
/// Two conventions run through all of them. Status is **text plus a shape**,
/// never colour alone, because the integration guide asks for that and
/// because "green pill" means nothing read aloud. And every money figure is
/// a [Money] rendered through [Money.display] — no screen formats an amount
/// itself, and none adds two settlement currencies together.

/// How a status pill reads.
enum GivingTone { neutral, pending, good, bad }

extension on GivingTone {
  Color get fill => switch (this) {
    GivingTone.neutral => AppColors.neutral800,
    GivingTone.pending => const Color(0x33D08700),
    GivingTone.good => const Color(0x2600C951),
    GivingTone.bad => const Color(0x26FB2C36),
  };

  Color get ink => switch (this) {
    GivingTone.neutral => AppColors.neutral300,
    GivingTone.pending => AppColors.statusOpen,
    GivingTone.good => AppColors.green500,
    GivingTone.bad => AppColors.red500,
  };
}

/// Which tone a rail's state deserves.
GivingTone toneFor(RailStatus status) => switch (status) {
  RailStatus.active => GivingTone.good,
  RailStatus.rejected ||
  RailStatus.suspended ||
  RailStatus.restricted => GivingTone.bad,
  RailStatus.platformReview ||
  RailStatus.providerOnboarding ||
  RailStatus.moreInformationRequired => GivingTone.pending,
  _ => GivingTone.neutral,
};

/// A small word about where something stands.
class GivingStatusPill extends StatelessWidget {
  const GivingStatusPill({
    super.key,
    required this.label,
    this.tone = GivingTone.neutral,
  });

  final String label;
  final GivingTone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 8.s, vertical: 3.s),
    decoration: BoxDecoration(
      color: tone.fill,
      borderRadius: BorderRadius.circular(999.s),
    ),
    child: Text(
      label,
      style: AppStyles.label(
        10,
        weight: AppStyles.bold,
        color: tone.ink,
        lineHeight: 14 / 10,
      ),
    ),
  );
}

/// The blue note the dialogs carry.
class GivingInfoNote extends StatelessWidget {
  const GivingInfoNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(12.s),
    decoration: BoxDecoration(
      color: const Color(0xFF11213A),
      borderRadius: BorderRadius.circular(8.s),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedInformationCircle,
          color: AppColors.linkBlue,
          size: 16.s,
        ),
        SizedBox(width: 10.s),
        Expanded(
          child: Text(
            text,
            style: AppStyles.body(
              12,
              color: AppColors.neutral200,
              lineHeight: 17 / 12,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The caption over a block.
class GivingSectionTitle extends StatelessWidget {
  const GivingSectionTitle(this.text, {super.key, this.body, this.trailing});

  final String text;
  final String? body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 10.s),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: AppStyles.heading(17)),
              if (body case final line?) ...[
                SizedBox(height: 4.s),
                Text(
                  line,
                  style: AppStyles.body(
                    12,
                    color: AppColors.neutral400,
                    lineHeight: 17 / 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing case final action?) ...[SizedBox(width: 12.s), action],
      ],
    ),
  );
}

/// A bordered block, which most of this section is made of.
class GivingCard extends StatelessWidget {
  const GivingCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  /// An outlined card, for the one thing the screen wants looked at.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(16.s),
      decoration: BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.circular(12.s),
        border: Border.all(
          color: highlighted ? AppColors.brandPrimary : AppColors.neutral900,
        ),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}

/// A metric's caption and its information icon.
///
/// The hint matters more than it looks. "Estimated proceeds" is not earnings
/// and "Held by provider" is not a balance, and a creator reading a big
/// number with no caption will take either for money in the bank — so the
/// icon is a real [Tooltip] that opens on tap, not decoration. A card with
/// nothing to explain draws no icon at all rather than an empty promise.
class _MetricLabel extends StatelessWidget {
  const _MetricLabel(this.label, {this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.label(12, color: AppColors.neutral400),
        ),
      ),
      if (hint case final note?) ...[
        SizedBox(width: 5.s),
        Tooltip(
          message: note,
          triggerMode: TooltipTriggerMode.tap,
          preferBelow: false,
          showDuration: const Duration(seconds: 6),
          margin: EdgeInsets.symmetric(horizontal: 16.s),
          padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 10.s),
          decoration: BoxDecoration(
            color: AppColors.neutral800,
            borderRadius: BorderRadius.circular(8.s),
          ),
          textStyle: AppStyles.body(12, color: AppColors.neutral100),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            color: AppColors.neutral500,
            size: 13.s,
          ),
        ),
      ],
    ],
  );
}

/// One figure on the funds screen: a label, the money, and a line saying
/// what it is not.
class GivingMetricCard extends StatelessWidget {
  const GivingMetricCard({
    super.key,
    required this.label,
    required this.amount,
    this.hint,
    this.footnote,
    this.tone = GivingTone.neutral,
    this.subtitle,
    this.unavailable = false,
  });

  final String label;

  /// What this figure is, and is not. Shown by the information icon.
  final String? hint;

  /// Null when there is no figure. Why there is none decides what is drawn:
  /// see [unavailable].
  final Money? amount;

  /// Whether the **provider** could not report this, as opposed to there
  /// being nothing to report.
  ///
  /// The two must not be confused. A balance a provider failed to return is
  /// said out loud, because drawing it as a zero reads as "your money is
  /// gone". But a studio with no rail and no gifts has not suffered a
  /// failure, and telling it the provider is down would be a lie about the
  /// provider — so that shows a dash.
  final bool unavailable;

  final String? footnote;
  final String? subtitle;
  final GivingTone tone;

  @override
  Widget build(BuildContext context) => GivingCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetricLabel(label, hint: hint),
        SizedBox(height: 8.s),
        Text(
          amount?.display ??
              (unavailable ? AppStrings.earningsBalanceUnavailable : '—'),
          style: amount == null && unavailable
              ? AppStyles.body(13, color: AppColors.neutral400)
              : AppStyles.heading(
                  26,
                  color: amount == null
                      ? AppColors.neutral500
                      : tone == GivingTone.good
                      ? AppColors.green500
                      : AppColors.textPrimary,
                ),
        ),
        if (subtitle case final line?) ...[
          SizedBox(height: 6.s),
          Text(line, style: AppStyles.label(11, color: AppColors.neutral400)),
        ],
        if (footnote case final line?) ...[
          SizedBox(height: 12.s),
          Divider(color: AppColors.neutral900, height: 1.s),
          SizedBox(height: 10.s),
          Text(line, style: AppStyles.label(11, color: AppColors.neutral500)),
        ],
      ],
    ),
  );
}

/// A count, where the metric card would otherwise show money.
class GivingCountCard extends StatelessWidget {
  const GivingCountCard({
    super.key,
    required this.label,
    required this.count,
    this.hint,
    this.footnote,
  });

  final String label;
  final int count;
  final String? hint;
  final String? footnote;

  @override
  Widget build(BuildContext context) => GivingCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetricLabel(label, hint: hint),
        SizedBox(height: 8.s),
        Text('$count', style: AppStyles.heading(26)),
        if (footnote case final line?) ...[
          SizedBox(height: 12.s),
          Divider(color: AppColors.neutral900, height: 1.s),
          SizedBox(height: 10.s),
          Text(line, style: AppStyles.label(11, color: AppColors.neutral500)),
        ],
      ],
    ),
  );
}

/// A provider's mark.
///
/// The app ships no provider logos, so each is a monogram on its own tint —
/// recognisable, and honest about being the app's own drawing rather than a
/// brand asset it does not have.
class ProviderMark extends StatelessWidget {
  const ProviderMark(this.provider, {super.key, this.size = 26});

  final PaymentProvider? provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fill, ink, glyph) = switch (provider) {
      PaymentProvider.khaime => (
        AppColors.neutral800,
        AppColors.neutral100,
        'K',
      ),
      PaymentProvider.paystack => (const Color(0xFF0BA4DB), Colors.white, 'P'),
      PaymentProvider.stripe => (const Color(0xFF635BFF), Colors.white, 'S'),
      PaymentProvider.flutterwave => (
        const Color(0xFFF5A623),
        Colors.white,
        'F',
      ),
      null => (AppColors.neutral800, AppColors.neutral400, '·'),
    };
    return Container(
      width: size.s,
      height: size.s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6.s),
      ),
      child: Text(
        glyph,
        style: AppStyles.label(
          size * 0.5,
          weight: AppStyles.bold,
          color: ink,
          lineHeight: 1,
        ),
      ),
    );
  }
}

/// One enrolled rail: who it is, where it settles, and the one thing to do
/// about it next.
class GivingRailCard extends StatelessWidget {
  const GivingRailCard({
    super.key,
    required this.rail,
    required this.actionLabel,
    required this.onAction,
    this.onDetails,
    this.onToggleEnabled,
    this.busy = false,
  });

  final GivingRail rail;
  final String actionLabel;
  final VoidCallback onAction;

  /// Only an enrolled rail has anything to show; before that there is no
  /// case, no checklist and nothing to open.
  final VoidCallback? onDetails;

  /// Taking an active rail out of donor routing. Absent until it is active —
  /// there is nothing to switch off before then.
  final ValueChanged<bool>? onToggleEnabled;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final provider = rail.provider;
    final hold = rail.holdDays;
    return GivingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GivingStatusPill(
                label: rail.status.label,
                tone: toneFor(rail.status),
              ),
              const Spacer(),
              Text(
                rail.settlementCurrency,
                style: AppStyles.label(12, weight: AppStyles.bold),
              ),
            ],
          ),
          SizedBox(height: 12.s),
          Row(
            children: [
              ProviderMark(provider),
              SizedBox(width: 10.s),
              Expanded(
                child: Text(
                  provider?.label ?? rail.countryCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.heading(16),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.s),
          Text(
            rail.custodyMode.isProviderHeld && hold != null
                ? AppStrings.givingHoldNote(
                    provider?.label ?? AppStrings.providerKhaime,
                    hold,
                  )
                : AppStrings.givingDirectNote(
                    provider?.label ?? rail.countryCode,
                  ),
            style: AppStyles.body(
              12,
              color: AppColors.neutral400,
              lineHeight: 17 / 12,
            ),
          ),
          SizedBox(height: 8.s),
          Text(
            rail.custodyMode.isProviderHeld
                ? AppStrings.givingKhaimeFormBody
                : AppStrings.givingProviderFormBody,
            style: AppStyles.body(
              12,
              color: AppColors.neutral500,
              lineHeight: 17 / 12,
            ),
          ),
          SizedBox(height: 14.s),
          Row(
            children: [
              if (onDetails case final open?) ...[
                Expanded(
                  child: _RailButton(
                    key: const ValueKey('rail-details'),
                    label: AppStrings.givingDetails,
                    onTap: open,
                  ),
                ),
                SizedBox(width: 10.s),
              ],
              Expanded(
                child: _RailButton(
                  key: ValueKey('rail-action-${rail.id}'),
                  label: actionLabel,
                  onTap: busy ? null : onAction,
                  outlined: true,
                ),
              ),
            ],
          ),
          if (onToggleEnabled case final toggle?) ...[
            SizedBox(height: 12.s),
            GestureDetector(
              key: ValueKey('rail-enabled-${rail.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : () => toggle(!rail.enabled),
              child: Row(
                children: [
                  _Check(on: rail.enabled),
                  SizedBox(width: 8.s),
                  Text(
                    AppStrings.givingAccepting,
                    style: AppStyles.label(12, color: AppColors.neutral300),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    super.key,
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 38.s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.s),
        border: Border.all(
          color: outlined ? AppColors.brandPrimary : AppColors.neutral700,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppStyles.button(
          12,
          color: outlined ? AppColors.brandPrimary : AppColors.textPrimary,
        ),
      ),
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 18.s,
    height: 18.s,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: on ? AppColors.brandPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(999.s),
      border: Border.all(
        color: on ? AppColors.brandPrimary : AppColors.neutral700,
      ),
    ),
    child: on
        ? Icon(Icons.check, size: 12.s, color: AppColors.base1)
        : const SizedBox.shrink(),
  );
}

/// A labelled value, which the rail detail screen is mostly made of.
class GivingDetailRow extends StatelessWidget {
  const GivingDetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: 8.s),
    padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 10.s),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8.s),
      border: Border.all(color: AppColors.neutral900),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppStyles.label(10, color: AppColors.neutral500)),
        SizedBox(height: 3.s),
        Text(value, style: AppStyles.body(13)),
      ],
    ),
  );
}

/// One line of the review checklist.
class GivingChecklistRow extends StatelessWidget {
  const GivingChecklistRow({
    super.key,
    required this.requirement,
    this.onUpload,
    this.busy = false,
  });

  final RailRequirement requirement;

  /// Present only when this is the creator's to supply.
  final VoidCallback? onUpload;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final rejected = requirement.isRejected;
    return Container(
      margin: EdgeInsets.only(bottom: 8.s),
      padding: EdgeInsets.symmetric(horizontal: 14.s, vertical: 12.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.s),
        border: Border.all(color: AppColors.neutral900),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  requirement.label.isEmpty
                      ? requirement.code
                      : requirement.label,
                  style: AppStyles.body(13),
                ),
              ),
              SizedBox(width: 10.s),
              GivingStatusPill(
                label: requirement.status,
                tone: requirement.isSatisfied
                    ? GivingTone.good
                    : rejected
                    ? GivingTone.bad
                    : GivingTone.pending,
              ),
            ],
          ),
          SizedBox(height: 4.s),
          // Who is holding this up. The guide asks for it to be said rather
          // than left for the creator to guess from a pending pill.
          Text(
            requirement.owner.label,
            style: AppStyles.label(10, color: AppColors.neutral500),
          ),
          if (requirement.rejectionReason case final reason?) ...[
            SizedBox(height: 6.s),
            Text(reason, style: AppStyles.label(11, color: AppColors.red500)),
          ],
          if (onUpload case final upload?) ...[
            SizedBox(height: 10.s),
            _RailButton(
              label: requirement.fileId == null
                  ? AppStrings.givingUploadDocument
                  : AppStrings.givingReplaceDocument,
              onTap: busy ? null : upload,
            ),
          ],
        ],
      ),
    );
  }
}

/// One gift, settlement, payout or release.
class GivingRecordRow extends StatelessWidget {
  const GivingRecordRow({super.key, required this.record, this.dateLabel});

  final GivingRecord record;

  /// "16 Oct 2026, 18:29", formatted by the screen that owns the list.
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    final release = record.automatic == false;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.s),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.neutral900)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.s,
            height: 32.s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.neutral800,
              borderRadius: BorderRadius.circular(999.s),
            ),
            child: Text(
              _initials(record.donorName),
              style: AppStyles.label(
                11,
                weight: AppStyles.bold,
                color: AppColors.neutral300,
              ),
            ),
          ),
          SizedBox(width: 10.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.donorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.label(13, weight: AppStyles.bold),
                ),
                SizedBox(height: 3.s),
                Text(
                  [
                    if (record.fundName.isNotEmpty) record.fundName,
                    ?dateLabel,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.label(
                    11,
                    color: AppColors.neutral500,
                    lineHeight: 15 / 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.s),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                record.amount.display,
                style: AppStyles.label(13, weight: AppStyles.bold),
              ),
              if (record.statusLabel.isNotEmpty || release) ...[
                SizedBox(height: 5.s),
                GivingStatusPill(
                  // A `release` is a movement that has already happened, not
                  // a request waiting on anyone — so it is labelled as one.
                  label: release
                      ? AppStrings.earningsRelease
                      : record.statusLabel,
                  tone: switch (record.status) {
                    'finalized' => GivingTone.good,
                    'needs_review' => GivingTone.bad,
                    _ => GivingTone.pending,
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '·';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// One fund, with what it has raised.
class GivingFundRow extends StatelessWidget {
  const GivingFundRow({
    super.key,
    required this.fund,
    this.onEdit,
    this.onCopyLink,
  });

  final GivingFund fund;
  final VoidCallback? onEdit;
  final VoidCallback? onCopyLink;

  @override
  Widget build(BuildContext context) => GivingCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                fund.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(14, weight: AppStyles.bold),
              ),
            ),
            SizedBox(width: 8.s),
            GivingStatusPill(
              label: fund.active
                  ? AppStrings.railActive
                  : AppStrings.givingFundDeactivate,
              tone: fund.active ? GivingTone.good : GivingTone.neutral,
            ),
          ],
        ),
        if (fund.description case final body? when body.isNotEmpty) ...[
          SizedBox(height: 6.s),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppStyles.body(
              12,
              color: AppColors.neutral400,
              lineHeight: 17 / 12,
            ),
          ),
        ],
        SizedBox(height: 10.s),
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.givingFundStats(
                  fund.giftCount,
                  fund.donorCount,
                  // Only ever the first bucket: two settlement currencies are
                  // never added together, so a fund with gifts in both shows
                  // the leading one rather than an invented total.
                  fund.totalsByCurrency.isEmpty
                      ? '—'
                      : fund.totalsByCurrency.first.display,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.label(11, color: AppColors.neutral500),
              ),
            ),
            if (onCopyLink case final copy?)
              _IconAction(
                key: ValueKey('fund-copy-${fund.id}'),
                icon: HugeIcons.strokeRoundedCopy01,
                onTap: copy,
              ),
            if (onEdit case final edit?) ...[
              SizedBox(width: 6.s),
              _IconAction(
                key: ValueKey('fund-edit-${fund.id}'),
                icon: HugeIcons.strokeRoundedEdit02,
                onTap: edit,
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _IconAction extends StatelessWidget {
  const _IconAction({super.key, required this.icon, required this.onTap});

  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.all(4.s),
      child: HugeIcon(icon: icon, color: AppColors.neutral300, size: 16.s),
    ),
  );
}

/// "16 Oct 2026, 18:29".
String givingDateTime(DateTime? at) {
  if (at == null) return '';
  return '${givingDate(at)}, ${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

/// "16 Oct 2026".
String givingDate(DateTime? at) {
  if (at == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${at.day} ${months[at.month - 1]} ${at.year}';
}
