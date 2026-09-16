import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/data/records_dummy_data.dart';
import 'package:test_app/models/library_models/library_models.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Prayer requests and testimonies: two lists of things the reader sent to a
/// ministry, and what became of each.
///
/// They share a card — avatar, author, a status pill, a body, a footer — and
/// differ in what the pill means and what the footer says. Neither is wired;
/// see [RecordsDummyData].

void _report(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppStyles.body(13)),
      backgroundColor: AppColors.neutral800,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// What the reader has asked a ministry to pray about.
class PrayerRequestsScreen extends StatefulWidget {
  const PrayerRequestsScreen({super.key});

  @override
  State<PrayerRequestsScreen> createState() => _PrayerRequestsScreenState();
}

class _PrayerRequestsScreenState extends State<PrayerRequestsScreen> {
  String _filter = AppStrings.prayerFilterAll;
  final _deleted = <String>{};

  /// The chips mix two axes — three statuses and one content kind — so each
  /// one says which axis it narrows.
  static const _statusFor = <String, PrayerStatus>{
    AppStrings.prayerFilterOpen: PrayerStatus.open,
    AppStrings.prayerFilterPrayedFor: PrayerStatus.prayedFor,
    AppStrings.prayerFilterClosed: PrayerStatus.closed,
  };

  bool _keeps(PrayerRequest p) {
    if (_deleted.contains(p.id)) return false;
    if (_filter == AppStrings.prayerFilterAudio) {
      return p.aboutKind == PrayerAbout.audio;
    }
    final wanted = _statusFor[_filter];
    return wanted == null || p.status == wanted;
  }

  List<PrayerRequest> get _matches =>
      RecordsDummyData.prayers.where(_keeps).toList(growable: false);

  void _openActions(PrayerRequest request) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LibraryActionSheet(
        actions: [
          // Once a ministry has prayed or closed it, there is nothing left
          // to edit.
          LibraryAction(
            label: AppStrings.prayerActionEdit,
            icon: HugeIcons.strokeRoundedEdit02,
            enabled: request.status == PrayerStatus.open,
          ),
          LibraryAction(
            label: AppStrings.prayerActionPrayAgain,
            icon: HugeIcons.strokeRoundedHandPrayer,
          ),
          LibraryAction(
            label: AppStrings.prayerActionGoToContent,
            icon: HugeIcons.strokeRoundedLinkSquare01,
            enabled: !request.aboutIsGeneral,
          ),
          LibraryAction(
            label: AppStrings.prayerActionDelete,
            icon: HugeIcons.strokeRoundedDelete02,
            destructive: true,
          ),
        ],
        onSelected: (label) {
          Navigator.pop(sheetContext);
          if (label == AppStrings.prayerActionDelete) {
            setState(() => _deleted.add(request.id));
          } else {
            _report(context, '$label is not built yet');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryHeader(
            title: AppStrings.prayerTitle,
            actionLabel: AppStrings.myEventsSort,
            actionIcon: HugeIcons.strokeRoundedSorting05,
            onAction: () => _report(context, 'Sorting is not built yet'),
            bottom: LibraryFilterChips(
              labels: const [
                AppStrings.prayerFilterAll,
                AppStrings.prayerFilterOpen,
                AppStrings.prayerFilterAudio,
                AppStrings.prayerFilterPrayedFor,
                AppStrings.prayerFilterClosed,
              ],
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? const SingleChildScrollView(
                    child: LibraryEmptyState(
                      icon: HugeIcons.strokeRoundedHandPrayer,
                      title: AppStrings.prayerEmptyTitle,
                      body: AppStrings.prayerEmptyBody,
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.s, 12.s, 16.s, 40.s),
                    itemCount: matches.length,
                    itemBuilder: (context, i) => _PrayerCard(
                      request: matches[i],
                      onMore: () => _openActions(matches[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.request, required this.onMore});

  final PrayerRequest request;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final (label, tint) = switch (request.status) {
      PrayerStatus.open => (AppStrings.prayerStatusOpen, AppColors.statusOpen),
      PrayerStatus.prayedFor => (
        AppStrings.prayerStatusPrayedFor,
        AppColors.statusDone,
      ),
      PrayerStatus.closed => (
        AppStrings.prayerStatusClosed,
        AppColors.statusClosed,
      ),
    };

    return _RecordCard(
      moreKey: ValueKey('more-${request.id}'),
      author: request.author,
      authorVerified: request.authorVerified,
      subtitle: request.aboutIsGeneral
          ? AppStrings.prayerGeneral
          : '${AppStrings.prayerAboutPrefix} ${request.about}',
      subtitleIcon: switch (request.aboutKind) {
        PrayerAbout.general => HugeIcons.strokeRoundedBuilding06,
        PrayerAbout.audio => HugeIcons.strokeRoundedHeadphones,
        PrayerAbout.video => HugeIcons.strokeRoundedVideo01,
        PrayerAbout.blog => HugeIcons.strokeRoundedBookOpen01,
      },
      statusLabel: label,
      statusTint: tint,
      statusIcon: switch (request.status) {
        PrayerStatus.open => HugeIcons.strokeRoundedClock01,
        PrayerStatus.prayedFor => null,
        PrayerStatus.closed => HugeIcons.strokeRoundedCheckmarkCircle02,
      },
      body: request.body,
      footer: Text(
        '${AppStrings.prayerSharedPrefix} ${request.sharedAgo}',
        style: AppStyles.label(
          12,
          color: AppColors.neutral500,
          lineHeight: 16 / 12,
        ),
      ),
      onMore: onMore,
    );
  }
}

/// What the reader has told a ministry God has done, and whether it is live.
class TestimoniesScreen extends StatefulWidget {
  const TestimoniesScreen({super.key});

  @override
  State<TestimoniesScreen> createState() => _TestimoniesScreenState();
}

class _TestimoniesScreenState extends State<TestimoniesScreen> {
  final _removed = <String>{};

  List<Testimony> get _matches => RecordsDummyData.testimonies
      .where((t) => !_removed.contains(t.id))
      .toList(growable: false);

  void _openActions(Testimony testimony) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LibraryActionSheet(
        actions: [
          LibraryAction(
            label: AppStrings.testimonyActionView,
            icon: HugeIcons.strokeRoundedView,
            enabled: testimony.status == TestimonyStatus.approved,
          ),
          LibraryAction(
            label: AppStrings.testimonyActionRemove,
            icon: HugeIcons.strokeRoundedDelete02,
            destructive: true,
          ),
        ],
        onSelected: (label) {
          Navigator.pop(sheetContext);
          if (label == AppStrings.testimonyActionRemove) {
            setState(() => _removed.add(testimony.id));
          } else {
            _report(context, '$label is not built yet');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LibraryHeader(
            title: AppStrings.testimoniesTitle,
            actionLabel: AppStrings.myEventsSort,
            actionIcon: HugeIcons.strokeRoundedSorting05,
            onAction: () => _report(context, 'Sorting is not built yet'),
          ),
          Expanded(
            child: matches.isEmpty
                ? const SingleChildScrollView(
                    child: LibraryEmptyState(
                      icon: HugeIcons.strokeRoundedMessage01,
                      title: AppStrings.testimoniesEmptyTitle,
                      body: AppStrings.testimoniesEmptyBody,
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.s, 12.s, 16.s, 40.s),
                    itemCount: matches.length,
                    itemBuilder: (context, i) => _TestimonyCard(
                      testimony: matches[i],
                      onMore: () => _openActions(matches[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TestimonyCard extends StatelessWidget {
  const _TestimonyCard({required this.testimony, required this.onMore});

  final Testimony testimony;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final (label, tint) = switch (testimony.status) {
      TestimonyStatus.pending => (
        AppStrings.testimonyPending,
        AppColors.statusOpen,
      ),
      TestimonyStatus.approved => (
        AppStrings.testimonyApproved,
        AppColors.statusDone,
      ),
      TestimonyStatus.rejected => (
        AppStrings.testimonyRejected,
        AppColors.destructive,
      ),
    };

    return _RecordCard(
      moreKey: ValueKey('more-${testimony.id}'),
      author: testimony.author,
      authorVerified: testimony.authorVerified,
      subtitle:
          '${AppStrings.testimoniesSubmittedPrefix} ${testimony.submittedAgo}',
      statusLabel: label,
      statusTint: tint,
      statusIcon: switch (testimony.status) {
        TestimonyStatus.pending => HugeIcons.strokeRoundedClock01,
        TestimonyStatus.approved => HugeIcons.strokeRoundedCheckmarkCircle02,
        TestimonyStatus.rejected => HugeIcons.strokeRoundedCancelCircle,
      },
      tags: testimony.tags,
      body: testimony.body,
      footer: _TestimonyFooter(testimony: testimony),
      onMore: onMore,
    );
  }
}

/// What happened to a testimony, in the words its status calls for.
class _TestimonyFooter extends StatelessWidget {
  const _TestimonyFooter({required this.testimony});

  final Testimony testimony;

  @override
  Widget build(BuildContext context) {
    if (testimony.status == TestimonyStatus.approved) {
      return Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedView,
            color: AppColors.statusDone,
            size: 14.s,
          ),
          SizedBox(width: 6.s),
          Flexible(
            child: Text(
              '${AppStrings.testimonyLivePrefix} ${testimony.wall}'
              '${AppStrings.testimonyLiveSuffix}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.label(
                12,
                weight: AppStyles.bold,
                color: AppColors.statusDone,
                lineHeight: 16 / 12,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedInformationCircle,
          color: AppColors.neutral500,
          size: 14.s,
        ),
        SizedBox(width: 6.s),
        Expanded(
          child: Text(
            testimony.status == TestimonyStatus.pending
                ? AppStrings.testimonyPendingNote
                : AppStrings.testimonyRejectedNote,
            style: AppStyles.label(
              12,
              color: AppColors.neutral500,
              lineHeight: 16 / 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// The card both records are drawn on.
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.moreKey,
    required this.author,
    required this.authorVerified,
    required this.subtitle,
    required this.statusLabel,
    required this.statusTint,
    required this.body,
    required this.footer,
    required this.onMore,
    this.subtitleIcon,
    this.statusIcon,
    this.tags = const [],
  });

  final Key moreKey;
  final String author;
  final bool authorVerified;
  final String subtitle;
  final List<List<dynamic>>? subtitleIcon;
  final String statusLabel;
  final Color statusTint;
  final List<List<dynamic>>? statusIcon;
  final List<String> tags;
  final String body;
  final Widget footer;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.s),
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12.s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(size: 32.s),
              SizedBox(width: 10.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.label(13, weight: AppStyles.bold),
                          ),
                        ),
                        if (authorVerified) ...[
                          SizedBox(width: 4.s),
                          DesignIcon(
                            AppAssets.iconFeedVerified,
                            width: 14.s,
                            height: 14.s,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.s),
                    Row(
                      children: [
                        if (subtitleIcon case final glyph?) ...[
                          HugeIcon(
                            icon: glyph,
                            color: AppColors.neutral500,
                            size: 12.s,
                          ),
                          SizedBox(width: 4.s),
                        ],
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.label(
                              12,
                              color: AppColors.neutral500,
                              lineHeight: 16 / 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.s),
              _StatusPill(
                label: statusLabel,
                tint: statusTint,
                icon: statusIcon,
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            SizedBox(height: 10.s),
            Wrap(
              spacing: 10.s,
              runSpacing: 6.s,
              children: [
                for (final tag in tags)
                  Text(
                    tag,
                    style: AppStyles.label(
                      12,
                      color: AppColors.brandPrimary,
                      lineHeight: 16 / 12,
                    ),
                  ),
              ],
            ),
          ],
          SizedBox(height: 10.s),
          Text(
            body,
            style: AppStyles.label(
              12,
              color: AppColors.neutral300,
              lineHeight: 18 / 12,
            ),
          ),
          SizedBox(height: 12.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: footer),
              SizedBox(width: 10.s),
              GestureDetector(
                key: moreKey,
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: Padding(
                  padding: EdgeInsets.all(4.s),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreHorizontal,
                    color: AppColors.neutral400,
                    size: 18.s,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tint, this.icon});

  final String label;
  final Color tint;
  final List<List<dynamic>>? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 4.s),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final glyph?) ...[
            HugeIcon(icon: glyph, color: tint, size: 12.s),
            SizedBox(width: 4.s),
          ],
          Text(
            label,
            style: AppStyles.label(
              11,
              weight: AppStyles.bold,
              color: tint,
              lineHeight: 14 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// A placeholder ring; creator avatars are not resolved anywhere yet.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.buttonSecondaryActive,
        border: Border.all(color: AppColors.purple400, width: size / 20),
      ),
      child: Icon(Icons.person, size: size * 0.6, color: AppColors.neutral400),
    );
  }
}
