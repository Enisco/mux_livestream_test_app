import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The parts every "things of mine" screen is made of.
///
/// History, Liked, Saved, My events, prayer requests, testimonies and giving
/// are the same skeleton in the design: a blurred bar carrying the title and
/// one action, an optional field to narrow the list, optional filter chips, a
/// count, then groups of rows — and a tinted disc when there is nothing to
/// show. They share these so the seven cannot drift apart.

/// The bar over a library screen. It sits over the list rather than scrolling
/// with it, and blurs what passes underneath, so the action and the field stay
/// reachable the whole way down.
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actionLabel,
    this.actionIcon,
    this.actionTint,
    this.onAction,
    this.controller,
    this.onQueryChanged,
    this.searchHint,
    this.bottom,
  });

  final String title;
  final VoidCallback? onBack;

  /// "Clear all", "Recent", "New playlist" — the one thing this screen offers
  /// besides its rows.
  final String? actionLabel;
  final List<List<dynamic>>? actionIcon;
  final Color? actionTint;
  final VoidCallback? onAction;

  /// Supply both to get a search field; omit for screens that do not narrow.
  final TextEditingController? controller;
  final ValueChanged<String>? onQueryChanged;
  final String? searchHint;

  /// Filter chips, usually, which sit under the field.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final searchable = controller != null && onQueryChanged != null;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3.15, sigmaY: 3.15),
        child: Container(
          color: AppColors.base1.withValues(alpha: 0.73),
          padding: EdgeInsets.fromLTRB(
            20.s,
            MediaQuery.paddingOf(context).top + 10.s,
            20.s,
            searchable || bottom != null ? 20.s : 12.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GTubeBackButton(onTap: onBack, size: 24, box: 24),
                        SizedBox(width: 12.s),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppStyles.label(
                              18,
                              weight: AppStyles.bold,
                              lineHeight: 28 / 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actionLabel case final label?) ...[
                    SizedBox(width: 8.s),
                    _HeaderAction(
                      label: label,
                      icon: actionIcon,
                      tint: actionTint ?? AppColors.neutral400,
                      onTap: onAction,
                    ),
                  ],
                ],
              ),
              if (searchable) ...[
                SizedBox(height: 22.s),
                LibrarySearchField(
                  controller: controller!,
                  onChanged: onQueryChanged!,
                  hint: searchHint ?? '',
                ),
              ],
              if (bottom case final extra?) ...[SizedBox(height: 14.s), extra],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.label,
    required this.tint,
    this.icon,
    this.onTap,
  });

  final String label;
  final Color tint;
  final List<List<dynamic>>? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(8.s),
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
                12,
                weight: AppStyles.black,
                color: tint,
                lineHeight: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rounded field that narrows a library list.
class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34.s,
      padding: EdgeInsets.symmetric(horizontal: 20.s),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(18.s),
        border: Border.all(color: AppColors.neutral900, width: 2.s),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: AppColors.neutral300,
            size: 18.s,
          ),
          SizedBox(width: 5.s),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.brandPrimary,
              style: AppStyles.label(
                12,
                color: AppColors.neutral200,
                lineHeight: 16 / 12,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppStyles.label(
                  12,
                  color: AppColors.neutral300,
                  lineHeight: 16 / 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pill row that narrows a library list to one kind of thing.
class LibraryFilterChips extends StatelessWidget {
  const LibraryFilterChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30.s,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.s),
        itemBuilder: (context, i) {
          final label = labels[i];
          final active = label == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(label),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14.s),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.textPrimary
                    : AppColors.buttonSecondaryActive,
                borderRadius: BorderRadius.circular(999.s),
              ),
              child: Text(
                label,
                style: AppStyles.label(
                  12,
                  weight: AppStyles.bold,
                  color: active ? AppColors.base1 : AppColors.textPrimary,
                  lineHeight: 16 / 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "173 things you've appreciated", "12 contents saved", "10 events".
class LibraryCount extends StatelessWidget {
  const LibraryCount({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 12.s),
      child: Text(
        text,
        style: AppStyles.label(12, color: AppColors.neutral500),
      ),
    );
  }
}

/// A group's heading: "Today", "UPCOMING (2)".
class LibraryGroupLabel extends StatelessWidget {
  const LibraryGroupLabel({super.key, required this.label, this.caps = false});

  final String label;

  /// Events and the settings blocks shout their headings; history does not.
  final bool caps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.s, 0, 16.s, 12.s),
      child: Text(
        label,
        style: caps
            ? AppStyles.label(
                12,
                weight: AppStyles.bold,
                color: AppColors.neutral500,
                lineHeight: 16 / 12,
              )
            : AppStyles.label(14, weight: AppStyles.bold, lineHeight: 20 / 14),
      ),
    );
  }
}

/// Nothing to show — or nothing matching what was typed.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 30.s, vertical: 40.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70.s,
            height: 70.s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandPrimary.withValues(alpha: 0.15),
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                color: AppColors.brandPrimary,
                size: 32.s,
              ),
            ),
          ),
          SizedBox(height: 14.s),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppStyles.heading(20, lineHeight: 28 / 20),
          ),
          SizedBox(height: 10.s),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppStyles.body(
              13,
              color: AppColors.neutral400,
              lineHeight: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of a [LibraryActionSheet].
class LibraryAction {
  const LibraryAction({
    required this.label,
    required this.icon,
    this.enabled = true,
    this.destructive = false,
  });

  final String label;
  final List<List<dynamic>> icon;

  /// A row the record cannot offer right now is shown, but dimmed and dead —
  /// the design keeps the sheet the same shape whatever state it is in.
  final bool enabled;

  final bool destructive;
}

/// The overflow sheet every library screen opens.
class LibraryActionSheet extends StatelessWidget {
  const LibraryActionSheet({
    super.key,
    required this.actions,
    required this.onSelected,
  });

  final List<LibraryAction> actions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12.s),
      padding: EdgeInsets.symmetric(vertical: 8.s),
      decoration: BoxDecoration(
        color: AppColors.base2,
        borderRadius: BorderRadius.circular(16.s),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.s,
              height: 4.s,
              margin: EdgeInsets.only(bottom: 8.s),
              decoration: BoxDecoration(
                color: AppColors.neutral700,
                borderRadius: BorderRadius.circular(2.s),
              ),
            ),
            for (final action in actions)
              Opacity(
                opacity: action.enabled ? 1 : 0.4,
                child: GestureDetector(
                  key: ValueKey('action-${action.label}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: action.enabled ? () => onSelected(action.label) : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.s,
                      vertical: 12.s,
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: action.icon,
                          color: action.destructive
                              ? AppColors.destructive
                              : AppColors.textPrimary,
                          size: 18.s,
                        ),
                        SizedBox(width: 12.s),
                        Text(
                          action.label,
                          style: AppStyles.label(
                            13,
                            color: action.destructive
                                ? AppColors.destructive
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
