import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/services/playback_controller.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Playback speed and video quality.
///
/// The legacy player carried both and the redesigned one lost them — a video
/// could only be played at 1x, at whatever rendition the network happened to
/// pick. Quality is offered only when the stream actually has more than one
/// rendition to choose between, so a progressive file shows speed alone
/// rather than a menu with a single entry.
Future<void> showPlaybackSettings(
  BuildContext context, {
  required PlaybackHandle playback,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => PlaybackSettingsSheet(playback: playback),
);

class PlaybackSettingsSheet extends StatelessWidget {
  const PlaybackSettingsSheet({super.key, required this.playback});

  final PlaybackHandle playback;

  static String rateLabel(double rate) =>
      rate == 1.0 ? AppStrings.speedNormal : '${_trim(rate)}x';

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.neutral900,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.s)),
        ),
        padding: EdgeInsets.fromLTRB(20.s, 12.s, 20.s, 20.s),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.s,
                  height: 4.s,
                  decoration: BoxDecoration(
                    color: AppColors.neutral700,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: 18.s),
              Text(
                AppStrings.playbackSpeed,
                style: AppStyles.heading(15, letterSpacing: -0.2),
              ),
              SizedBox(height: 10.s),
              ValueListenableBuilder<double>(
                valueListenable: playback.rate,
                builder: (context, rate, _) => Wrap(
                  spacing: 8.s,
                  runSpacing: 8.s,
                  children: [
                    for (final choice in PlaybackController.rateChoices)
                      _Pill(
                        key: ValueKey('speed-$choice'),
                        label: rateLabel(choice),
                        selected: rate == choice,
                        onTap: () => playback.setRate(choice),
                      ),
                  ],
                ),
              ),
              ValueListenableBuilder<List<String>>(
                valueListenable: playback.qualities,
                builder: (context, qualities, _) {
                  // Nothing to choose between: one rendition, or a stream
                  // whose renditions are not known.
                  if (qualities.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 22.s),
                      Text(
                        AppStrings.videoQuality,
                        style: AppStyles.heading(15, letterSpacing: -0.2),
                      ),
                      SizedBox(height: 10.s),
                      ValueListenableBuilder<String>(
                        valueListenable: playback.quality,
                        builder: (context, current, _) => Wrap(
                          spacing: 8.s,
                          runSpacing: 8.s,
                          children: [
                            for (final q in qualities)
                              _Pill(
                                key: ValueKey('quality-$q'),
                                label: q,
                                selected: q == current,
                                onTap: () => playback.setQuality(q),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.s, vertical: 10.s),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : AppColors.neutral800,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppStyles.label(
            13,
            color: selected ? Colors.black : AppColors.textPrimary,
            weight: AppStyles.semiBold,
          ),
        ),
      ),
    );
  }
}
