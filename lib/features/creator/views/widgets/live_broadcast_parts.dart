import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/home/views/widgets/feed_card.dart'
    show formatCount;
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The pieces the broadcast screen is made of.

/// The red pill that says this is going out right now.
class LivePill extends StatelessWidget {
  const LivePill({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('live-pill'),
    padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 7.s),
    decoration: BoxDecoration(
      color: AppColors.destructive,
      borderRadius: BorderRadius.circular(999.s),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.s,
          height: 7.s,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(width: 6.s),
        Text(
          AppStrings.goLiveLivePill,
          style: AppStyles.label(12, weight: AppStyles.bold),
        ),
      ],
    ),
  );
}

/// One of the counters along the top: likes, watchers, giving.
class LiveStatPill extends StatelessWidget {
  const LiveStatPill({
    super.key,
    required this.pillKey,
    required this.icon,
    required this.value,
  });

  final Key pillKey;
  final List<List<dynamic>> icon;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    key: pillKey,
    padding: EdgeInsets.symmetric(horizontal: 11.s, vertical: 7.s),
    decoration: BoxDecoration(
      color: AppColors.overlayMid,
      borderRadius: BorderRadius.circular(999.s),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, color: AppColors.textPrimary, size: 14.s),
        SizedBox(width: 6.s),
        Text(value, style: AppStyles.label(12, weight: AppStyles.bold)),
      ],
    ),
  );
}

/// What the giving pill reads.
///
/// `metrics.giving` is null when the payment service is unreachable, and
/// the contract is explicit that a zero must not be shown in a made-up
/// currency then — so it shows a dash. Totals in different settlement
/// currencies are never added together; the pill shows the first, and
/// names its currency so the figure cannot be read as the wrong money.
///
/// The amount arrives in minor units with no exponent alongside it, so two
/// decimal places are assumed. That holds for NGN and USD; a zero-decimal
/// currency such as JPY would read a hundred times small, which is why the
/// code is shown rather than a bare number.
String givingLabel(LivestreamStudio studio) {
  if (studio.giving == null) return AppStrings.goLiveNoGiving;
  final total = studio.headlineGiving;
  if (total == null) return '0';
  return '${total.currency} ${_grouped(total.grossMinor ~/ 100)}'.trim();
}

/// "18000" → "18,000". Money reads in full; it is not a view count.
String _grouped(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A round control on the broadcast bar.
class LiveRoundButton extends StatelessWidget {
  const LiveRoundButton({
    super.key,
    required this.buttonKey,
    required this.icon,
    required this.onTap,
    this.active = true,
  });

  final Key buttonKey;
  final List<List<dynamic>> icon;
  final VoidCallback onTap;

  /// A muted microphone reads as off.
  final bool active;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: buttonKey,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 44.s,
      height: 44.s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.overlayMid : AppColors.destructive,
      ),
      child: HugeIcon(icon: icon, color: AppColors.textPrimary, size: 19.s),
    ),
  );
}

/// The 3-2-1 the design counts down before the first frame goes out.
class LiveCountdown extends StatelessWidget {
  const LiveCountdown({super.key, required this.value});

  /// 3, 2 or 1. Anything else draws nothing.
  final int value;

  @override
  Widget build(BuildContext context) => value < 1 || value > 3
      ? const SizedBox.shrink()
      : Center(
          child: Text(
            '$value',
            key: ValueKey('live-countdown-$value'),
            style: AppStyles.display(
              140,
              color: AppColors.textPrimary.withValues(alpha: 0.12),
            ),
          ),
        );
}

/// "End your livestream" — what stopping will cost, before it happens.
class EndLivestreamSheet extends StatelessWidget {
  const EndLivestreamSheet({
    super.key,
    required this.studio,
    required this.replayPolicy,
    required this.onKeep,
    required this.onEnd,
  });

  final LivestreamStudio studio;
  final ReplayPolicy replayPolicy;
  final VoidCallback onKeep;
  final VoidCallback onEnd;

  static Future<bool> show(
    BuildContext context, {
    required LivestreamStudio studio,
    required ReplayPolicy replayPolicy,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) => EndLivestreamSheet(
          studio: studio,
          replayPolicy: replayPolicy,
          onKeep: () => Navigator.pop(sheetContext, false),
          onEnd: () => Navigator.pop(sheetContext, true),
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16.s,
      0,
      16.s,
      16.s + MediaQuery.paddingOf(context).bottom,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Container(
        padding: EdgeInsets.all(20.s),
        decoration: BoxDecoration(
          color: AppColors.base2,
          borderRadius: BorderRadius.circular(16.s),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.goLiveEndTitle,
              style: AppStyles.heading(17, letterSpacing: -0.4),
            ),
            SizedBox(height: 8.s),
            Text(
              _watching,
              style: AppStyles.body(
                13,
                color: AppColors.neutral400,
                lineHeight: 18 / 13,
              ),
            ),
            SizedBox(height: 16.s),
            Container(
              padding: EdgeInsets.all(14.s),
              decoration: BoxDecoration(
                color: AppColors.fieldBg,
                borderRadius: BorderRadius.circular(10.s),
              ),
              child: Text(
                switch (replayPolicy) {
                  ReplayPolicy.autoPublish => AppStrings.goLiveEndReplay,
                  ReplayPolicy.savePrivate => AppStrings.goLiveEndReplayPrivate,
                  ReplayPolicy.discard => AppStrings.goLiveEndReplayNone,
                },
                style: AppStyles.body(
                  12,
                  color: AppColors.neutral300,
                  lineHeight: 17 / 12,
                ),
              ),
            ),
            if (studio.prayerCount > 0) ...[
              SizedBox(height: 12.s),
              Text(
                _prayers,
                style: AppStyles.label(12, color: AppColors.neutral400),
              ),
            ],
            SizedBox(height: 18.s),
            Row(
              children: [
                Expanded(
                  child: _Action(
                    actionKey: const ValueKey('live-keep'),
                    label: AppStrings.goLiveKeepStreaming,
                    onTap: onKeep,
                  ),
                ),
                SizedBox(width: 12.s),
                Expanded(
                  child: _Action(
                    actionKey: const ValueKey('live-confirm-end'),
                    label: AppStrings.goLiveEndStream,
                    onTap: onEnd,
                    destructive: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  String get _watching {
    final count = studio.viewerCount;
    final people = count == 1
        ? '1 person is'
        : '${formatCount(count)} people are';
    return '$people watching right now. Ending the stream will disconnect '
        'them.';
  }

  String get _prayers {
    final count = studio.prayerCount;
    final word = count == 1 ? 'prayer request is' : 'prayer requests are';
    return '$count $word saved to your inbox.';
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.actionKey,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final Key actionKey;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: actionKey,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 46.s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999.s),
        border: Border.all(
          color: destructive ? AppColors.destructive : AppColors.neutral700,
        ),
      ),
      child: Text(
        label,
        style: AppStyles.label(
          13,
          weight: AppStyles.bold,
          color: destructive ? AppColors.destructive : AppColors.textPrimary,
        ),
      ),
    ),
  );
}

/// "1:04" — how long this has been going out.
String formatElapsed(Duration elapsed) {
  final minutes = elapsed.inMinutes;
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (elapsed.inHours > 0) {
    final mm = minutes.remainder(60).toString().padLeft(2, '0');
    return '${elapsed.inHours}:$mm:$seconds';
  }
  return '$minutes:$seconds';
}
