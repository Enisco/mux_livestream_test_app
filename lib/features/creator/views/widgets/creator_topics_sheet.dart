import 'package:flutter/material.dart';

import 'package:test_app/models/creator_models/creator_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// What the channel mostly puts out.
///
/// This is the creator's answer, not the viewer's: Settings has a topics sheet
/// too, but that one shapes a feed, while this one labels a channel. They are
/// kept apart so the two lists can diverge, which they already do.
///
/// The rows are the real categories from `GET /v1/creator/categories`; the
/// design's own list stands in only when that call returned nothing, so the
/// sheet is never empty.
class CreatorTopicsSheet extends StatefulWidget {
  const CreatorTopicsSheet({
    super.key,
    this.categories = const [],
    this.selected = const {},
  });

  final List<ContentCategory> categories;

  /// Slugs, matching what `saveCreatorProfile` takes.
  final Set<String> selected;

  /// Returns the chosen slugs, or null if the sheet was dismissed.
  static Future<Set<String>?> show(
    BuildContext context, {
    List<ContentCategory> categories = const [],
    Set<String> selected = const {},
  }) => showModalBottomSheet<Set<String>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) =>
        CreatorTopicsSheet(categories: categories, selected: selected),
  );

  /// What `GET /v1/user/categories` actually returns, verbatim, for when
  /// that call fails.
  ///
  /// These are not the design's nine labels. Slugging those the obvious way
  /// produced `preaching`, `marriage-family` and the rest, every one of
  /// which the API refuses — *"Unsupported categories: preaching"* — so an
  /// onboarding that fell back would have been rejected on save.
  static const fallback = <(String, String)>[
    ('worship', 'Worship'),
    ('sermons', 'Sermons'),
    ('bible-study', 'Bible Study'),
    ('prayer', 'Prayer'),
    ('gospel-music', 'Gospel Music'),
    ('live-services', 'Live Services'),
    ('testimonies', 'Testimonies'),
    ('youth', 'Youth'),
    ('family', 'Family'),
    ('devotionals', 'Devotionals'),
  ];

  static List<ContentCategory> get _fallbackCategories => [
    for (final (slug, name) in fallback)
      ContentCategory(slug: slug, name: name),
  ];

  @override
  State<CreatorTopicsSheet> createState() => _CreatorTopicsSheetState();
}

class _CreatorTopicsSheetState extends State<CreatorTopicsSheet> {
  late final Set<String> _chosen = {...widget.selected};
  late final List<ContentCategory> _rows = widget.categories.isEmpty
      ? CreatorTopicsSheet._fallbackCategories
      : widget.categories;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 60),
      decoration: const BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.neutral700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.creatorTopicsTitle,
                      style: AppStyles.heading(17, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.creatorTopicsSubtitle,
                      style: AppStyles.body(
                        12,
                        color: AppColors.neutral400,
                        lineHeight: 16 / 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.creatorTopicsLabel,
                          style: AppStyles.label(
                            12,
                            weight: AppStyles.bold,
                            color: AppColors.neutral400,
                            lineHeight: 16 / 12,
                          ),
                        ),
                        Text(
                          '${_chosen.length}/'
                          '${AppStrings.creatorCategoryMax}',
                          style: AppStyles.label(
                            12,
                            weight: AppStyles.bold,
                            color:
                                _chosen.length >= AppStrings.creatorCategoryMax
                                ? AppColors.brandPrimary
                                : AppColors.neutral500,
                            lineHeight: 16 / 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  children: [
                    for (final category in _rows)
                      _TopicRow(
                        topic: category.name,
                        on: _chosen.contains(category.slug),
                        // The server refuses the whole request over eight, so
                        // the ninth is refused here instead of being sent.
                        onChanged: (value) {
                          if (value &&
                              _chosen.length >= AppStrings.creatorCategoryMax) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppStrings.creatorCategoryTooMany,
                                  style: AppStyles.body(13),
                                ),
                                backgroundColor: AppColors.neutral800,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            value
                                ? _chosen.add(category.slug)
                                : _chosen.remove(category.slug);
                          });
                        },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context, {..._chosen}),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neutral700),
                    ),
                    child: Text(
                      AppStrings.creatorTopicsDone,
                      style: AppStyles.button(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.on,
    required this.onChanged,
  });

  final String topic;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('topic-$topic'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!on),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                topic,
                style: AppStyles.label(13, weight: AppStyles.bold),
              ),
            ),
            const SizedBox(width: 12),
            _Switch(on: on),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 22,
      padding: const EdgeInsets.all(2),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? AppColors.brandPrimary : AppColors.neutral200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? Colors.white : AppColors.neutral500,
        ),
        child: Icon(
          on ? Icons.check : Icons.close,
          size: 12,
          color: on ? AppColors.brandPrimary : Colors.white,
        ),
      ),
    );
  }
}
