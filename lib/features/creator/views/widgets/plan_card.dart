import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:test_app/utils/app_constants/app_assets.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Static copy for one plan tier. Feature lists are not exposed by the API, so
/// they come from the design
class PlanCopy {
  const PlanCopy({
    required this.title,
    required this.tagline,
    required this.inheritsLine,
    required this.leftFeatures,
    required this.rightFeatures,
    this.highlighted = false,
  });

  final String title;
  final String tagline;
  final String inheritsLine;
  final List<String> leftFeatures;
  final List<String> rightFeatures;

  /// Pro carries the brand border and the "Most popular" badge.
  final bool highlighted;
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.copy,
    required this.selected,
    required this.onTap,
    this.price,
    this.priceSuffix,
    this.customPrice,
    this.mutedInheritsLine = false,
  });

  final PlanCopy copy;
  final bool selected;
  final VoidCallback onTap;

  /// Major-unit amount, e.g. 19. Null while plans are loading.
  final int? price;
  final String? priceSuffix;

  /// Used by Enterprise, which has no numeric price.
  final String? customPrice;

  /// Enterprise renders its "Everything In Pro" line brighter than the others.
  final bool mutedInheritsLine;

  static const _radius = 8.0;
  static const _padding = 20.0;

  @override
  Widget build(BuildContext context) {
    final gap = copy.highlighted ? 14.0 : 12.0;
    return Material(
      color: AppColors.brandSecondary,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: selected ? AppColors.brandPrimary : AppColors.neutral900,
              width: selected ? 1.4 : 2,
            ),
          ),
          padding: const EdgeInsets.all(_padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (copy.highlighted)
                          Row(
                            children: [
                              Text(
                                copy.title,
                                style: AppStyles.heading(
                                  18,
                                  lineHeight: 28 / 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const _MostPopularBadge(),
                            ],
                          )
                        else
                          Text(
                            copy.title,
                            style: AppStyles.heading(18, lineHeight: 28 / 18),
                          ),
                        Text(
                          copy.tagline,
                          style: AppStyles.body(
                            13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: gap),
                  _Price(
                    price: price,
                    suffix: priceSuffix,
                    customPrice: customPrice,
                  ),
                ],
              ),
              SizedBox(height: copy.highlighted ? 18 : 31),
              Text(
                copy.inheritsLine,
                style: mutedInheritsLine
                    ? AppStyles.body(13)
                    : AppStyles.body(13, color: AppColors.neutral400),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _FeatureColumn(copy.leftFeatures)),
                  const SizedBox(width: 10),
                  Expanded(child: _FeatureColumn(copy.rightFeatures)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureColumn extends StatelessWidget {
  const _FeatureColumn(this.features);

  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < features.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(AppAssets.iconCheckGreen, width: 18, height: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  features[i],
                  style: AppStyles.caption(
                    12,
                    color: AppColors.textPrimary,
                    weight: AppStyles.medium,
                    lineHeight: 16 / 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({this.price, this.suffix, this.customPrice});

  final int? price;
  final String? suffix;
  final String? customPrice;

  @override
  Widget build(BuildContext context) {
    if (customPrice != null) {
      return Text(
        customPrice!,
        style: AppStyles.heading(
          20,
          weight: AppStyles.bold,
          lineHeight: 28 / 20,
          letterSpacing: -0.4,
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(AppAssets.iconDollar, width: 20, height: 20),
        Text(
          price?.toString() ?? '—',
          style: AppStyles.heading(
            20,
            weight: AppStyles.bold,
            lineHeight: 28 / 20,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 2),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            suffix ?? AppStrings.perMonth,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
        ),
      ],
    );
  }
}

class _MostPopularBadge extends StatelessWidget {
  const _MostPopularBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.cyan500),
        gradient: const LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [AppColors.cyan500, Color(0x000E0E0E)],
        ),
      ),
      child: Text(
        AppStrings.mostPopular,
        style: AppStyles.overline(
          10,
          color: AppColors.cyan500,
          weight: AppStyles.black,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}
