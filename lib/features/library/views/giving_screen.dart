import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/data/giving_dummy_data.dart';
import 'package:test_app/models/library_models/giving_models.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/shared/components/library_parts.dart';
import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What the reader has given, a year at a time.
///
/// A summary card over a worship backdrop, then the year's gifts grouped by
/// month, each with the document it produced. Nothing is wired — see
/// [GivingDummyData].
class GivingScreen extends StatefulWidget {
  const GivingScreen({super.key});

  @override
  State<GivingScreen> createState() => _GivingScreenState();
}

class _GivingScreenState extends State<GivingScreen> {
  int _year = GivingDummyData.years.first;

  GivingSummary get _summary =>
      GivingDummyData.summaries[_year] ??
      GivingSummary(year: _year, total: '', gifts: 0, ministries: 0);

  List<GivingMonth> get _months => GivingDummyData.months[_year] ?? const [];

  void _report(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppStyles.body(13)),
        backgroundColor: AppColors.neutral800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickYear() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LibraryActionSheet(
        actions: [
          for (final year in GivingDummyData.years)
            LibraryAction(
              label: '$year',
              icon: HugeIcons.strokeRoundedCalendar03,
              enabled: year != _year,
            ),
        ],
        onSelected: (label) => Navigator.pop(sheetContext, int.tryParse(label)),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _year = picked);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final months = _months;

    return Scaffold(
      backgroundColor: AppColors.base1,
      body: ListView(
        padding: EdgeInsets.only(bottom: 40.s),
        children: [
          _SummaryCard(summary: summary, onPickYear: _pickYear),
          if (summary.isEmpty)
            LibraryEmptyState(
              icon: HugeIcons.strokeRoundedGift,
              title: AppStrings.givingEmptyTitle,
              body: AppStrings.givingEmptyBody,
            )
          else ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _report(
                '${AppStrings.givingDownloadStatement} is not built yet',
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.s, 16.s, 16.s, 8.s),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedFile02,
                      color: AppColors.linkBlue,
                      size: 15.s,
                    ),
                    SizedBox(width: 8.s),
                    Text(
                      AppStrings.givingDownloadStatement,
                      style: AppStyles.label(
                        13,
                        color: AppColors.linkBlue,
                        lineHeight: 18 / 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final month in months) ...[
              LibraryGroupLabel(label: month.label, caps: true),
              for (final gift in month.gifts)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.s),
                  child: _GiftRow(
                    gift: gift,
                    onDocument: () =>
                        _report('${gift.document.label}s are not built yet'),
                  ),
                ),
              SizedBox(height: 14.s),
            ],
          ],
        ],
      ),
    );
  }
}

/// The card over the backdrop: the year's total and how it was made up.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.onPickYear});

  final GivingSummary summary;
  final VoidCallback onPickYear;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    // The card takes its height from its own text rather than a figure typed
    // in here, which would go wrong the moment a font or a total changed.
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(AppAssets.worshipBg, fit: BoxFit.cover),
        ),
        // Enough to read white text over the crowd, not enough to lose it.
        const Positioned.fill(child: ColoredBox(color: Color(0xB3000000))),
        Padding(
          padding: EdgeInsets.fromLTRB(20.s, top + 10.s, 20.s, 12.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GTubeBackButton(size: 24, box: 24),
              SizedBox(height: 10.s),
              Row(
                children: [
                  Text(
                    AppStrings.givingGivenThisYear,
                    style: AppStyles.label(
                      12,
                      color: AppColors.neutral200,
                      lineHeight: 16 / 12,
                    ),
                  ),
                  SizedBox(width: 6.s),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPickYear,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${summary.year}',
                          style: AppStyles.label(
                            12,
                            weight: AppStyles.bold,
                            color: AppColors.brandPrimary,
                            lineHeight: 16 / 12,
                          ),
                        ),
                        SizedBox(width: 2.s),
                        Icon(
                          AppIcons.chevronDown,
                          size: 14.s,
                          color: AppColors.brandPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.s),
              Text(
                summary.total,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppStyles.display(30, lineHeight: 38 / 30),
              ),
              if (summary.converted.isNotEmpty) ...[
                SizedBox(height: 2.s),
                Text(
                  '≈ ${summary.converted} ${AppStrings.givingTotalSuffix}',
                  style: AppStyles.label(
                    11,
                    color: AppColors.neutral400,
                    lineHeight: 14 / 11,
                  ),
                ),
              ],
              SizedBox(height: 14.s),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedGift,
                      color: AppColors.neutral300,
                      size: 13.s,
                    ),
                    SizedBox(width: 6.s),
                    Text(
                      summary.isEmpty
                          ? '0 ${AppStrings.givingGiftsSuffix}'
                          : '${summary.gifts} '
                                '${AppStrings.givingGiftsSuffix} · '
                                '${AppStrings.givingAcrossPrefix} '
                                '${summary.ministries} '
                                '${AppStrings.givingMinistriesSuffix}',
                      style: AppStyles.label(
                        11,
                        color: AppColors.neutral300,
                        lineHeight: 14 / 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One gift: who it went to, what it was for, what it cost, and its paperwork.
class _GiftRow extends StatelessWidget {
  const _GiftRow({required this.gift, required this.onDocument});

  final Gift gift;
  final VoidCallback onDocument;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.s),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.neutral900)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(size: 28.s),
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
                            gift.ministry,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.label(13, weight: AppStyles.bold),
                          ),
                        ),
                        if (gift.ministryVerified) ...[
                          SizedBox(width: 4.s),
                          DesignIcon(
                            AppAssets.iconFeedVerified,
                            width: 13.s,
                            height: 13.s,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3.s),
                    Text(
                      '${gift.fund} · ${gift.date}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.label(
                        12,
                        color: AppColors.neutral500,
                        lineHeight: 16 / 12,
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
                    gift.amount,
                    style: AppStyles.label(13, weight: AppStyles.bold),
                  ),
                  if (gift.converted.isNotEmpty) ...[
                    SizedBox(height: 3.s),
                    Text(
                      gift.converted,
                      style: AppStyles.label(
                        11,
                        color: AppColors.neutral500,
                        lineHeight: 14 / 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 8.s),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              key: ValueKey('doc-${gift.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onDocument,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedFile02,
                    color: AppColors.linkBlue,
                    size: 13.s,
                  ),
                  SizedBox(width: 6.s),
                  Text(
                    gift.document.label,
                    style: AppStyles.label(
                      12,
                      color: AppColors.linkBlue,
                      lineHeight: 16 / 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A placeholder ring; ministry avatars are not resolved anywhere yet.
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
