import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/library/repo/viewer_records_repo.dart'
    show longAge;
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The prayer requests sent during a broadcast, so the broadcaster can pray
/// for them on air.
///
/// Until 2026-10-26 the studio reported `metrics.prayers.count` and nothing
/// readable, so the number on the end-stream card was all there was.
///
/// Two things shape this sheet:
///
/// - **There is no `isAnonymous`.** The whole point of the list is to pray
///   for a *named* person, and the platform has no anonymous submission. A
///   missing name is failed hydration, not a choice, so it falls back
///   neutrally rather than being labelled anonymous.
/// - **The count arrives by socket, the bodies do not.**
///   `livestream.metrics_updated` carries `prayers.count` to the studio room
///   in realtime; treat it as a nudge and re-fetch the first page when the
///   count exceeds what is held. Prayer text stays on an authorised
///   request/response rather than a fan-out room.
Future<void> showLivePrayersSheet(
  BuildContext context, {
  required String mediaId,
  LivestreamRepo? repo,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => _LivePrayersSheet(mediaId: mediaId, repo: repo),
);

class _LivePrayersSheet extends StatefulWidget {
  const _LivePrayersSheet({required this.mediaId, this.repo});

  final String mediaId;
  final LivestreamRepo? repo;

  @override
  State<_LivePrayersSheet> createState() => _LivePrayersSheetState();
}

class _LivePrayersSheetState extends State<_LivePrayersSheet> {
  late final _repo = widget.repo ?? LivestreamRepo();

  List<LivePrayer> _rows = const [];
  int _total = 0;
  String? _cursor;
  bool _loading = true;
  bool _failed = false;
  bool _loadingMore = false;

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
      final page = await _repo.prayers(widget.mediaId);
      if (!mounted) return;
      setState(() {
        _rows = page.items;
        _total = page.total;
        _cursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      // Do not fall back to the creator inbox on a refusal: it is authorised
      // for owner/admin/editor and will refuse a streamer for a different
      // reason.
      logger.w('Live prayers failed', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.prayers(widget.mediaId, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...page.items];
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      logger.w('Live prayers page failed', error: e);
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.base2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.s)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 10.s),
            Center(
              child: Container(
                width: 36.s,
                height: 4.s,
                decoration: BoxDecoration(
                  color: AppColors.neutral700,
                  borderRadius: BorderRadius.circular(999.s),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.s, 14.s, 16.s, 10.s),
              child: Row(
                children: [
                  Text(
                    AppStrings.livePrayersTitle,
                    style: AppStyles.label(16, weight: AppStyles.bold),
                  ),
                  const Spacer(),
                  if (_total > 0)
                    Text(
                      AppStrings.livePrayersCount(_total),
                      style: AppStyles.label(12, color: AppColors.neutral400),
                    ),
                ],
              ),
            ),
            Expanded(child: _body(controller)),
          ],
        ),
      ),
    );
  }

  Widget _body(ScrollController controller) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandPrimary),
      );
    }
    if (_failed) return ErrorStateView(onRetry: _load);
    if (_rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.s),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedHandPrayer,
              color: AppColors.neutral500,
              size: 32.s,
            ),
            SizedBox(height: 12.s),
            Text(
              AppStrings.livePrayersEmpty,
              style: AppStyles.label(14, weight: AppStyles.bold),
            ),
            SizedBox(height: 6.s),
            Text(
              AppStrings.livePrayersEmptyBody,
              textAlign: TextAlign.center,
              style: AppStyles.label(12, color: AppColors.neutral500),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical &&
            n.metrics.extentAfter < 300 &&
            _cursor != null) {
          unawaited(_loadMore());
        }
        return false;
      },
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 24.s),
        children: [
          for (final prayer in _rows) _PrayerCard(prayer: prayer),
          if (_loadingMore)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20.s),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.brandPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.prayer});

  final LivePrayer prayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('live-prayer-${prayer.id}'),
      margin: EdgeInsets.only(bottom: 10.s),
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(10.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  // Absent, not anonymous: hydration is best-effort.
                  prayer.requesterName.isEmpty
                      ? AppStrings.livePrayersAnonymous
                      : prayer.requesterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.label(13, weight: AppStyles.bold),
                ),
              ),
              SizedBox(width: 8.s),
              Text(
                longAge(prayer.createdAt),
                style: AppStyles.label(11, color: AppColors.neutral500),
              ),
            ],
          ),
          SizedBox(height: 8.s),
          Text(
            prayer.body,
            style: AppStyles.label(
              13,
              color: AppColors.neutral300,
              lineHeight: 19 / 13,
            ),
          ),
        ],
      ),
    );
  }
}
