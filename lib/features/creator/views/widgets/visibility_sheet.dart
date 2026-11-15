import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// "Who can see it" — the three values `visibility` takes, and no more.
///
/// The API refuses anything outside `public`, `unlisted` and `private`, so
/// this is a closed list rather than a text field. It reads the same as the
/// go-live sheet because it is the same kind of question: one choice, three
/// options, each with a line saying what it means.
///
/// **Unlisted is the one with a catch.** Making already-published media
/// unlisted through `PATCH /v1/media/{id}` returns no share token — only
/// publish mints one, and each publish of unlisted media mints a *new* one
/// that stops older links working. So the phone can set the value but
/// cannot hand over the link, and the screen says so afterwards rather
/// than pretending it has one.
class VisibilitySheet extends StatefulWidget {
  const VisibilitySheet({
    super.key,
    required this.current,
    required this.onChoose,
  });

  /// What is selected when the sheet opens, or **null when the row never
  /// said** — then nothing is preselected and Done waits for a choice,
  /// rather than offering a value the client only guessed at.
  final MediaVisibility? current;

  final ValueChanged<MediaVisibility> onChoose;

  /// Returns the choice, or null if the sheet was dismissed.
  static Future<MediaVisibility?> show(
    BuildContext context, {
    required MediaVisibility? current,
  }) => showModalBottomSheet<MediaVisibility>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => VisibilitySheet(
      current: current,
      onChoose: (choice) => Navigator.pop(sheetContext, choice),
    ),
  );

  /// The word for a value, wherever one is shown outside this sheet.
  static String label(MediaVisibility visibility) => switch (visibility) {
    MediaVisibility.public => AppStrings.visibilityPublic,
    MediaVisibility.unlisted => AppStrings.visibilityUnlisted,
    MediaVisibility.private => AppStrings.visibilityPrivate,
  };

  static String _body(MediaVisibility visibility) => switch (visibility) {
    MediaVisibility.public => AppStrings.visibilityPublicBody,
    MediaVisibility.unlisted => AppStrings.visibilityUnlistedBody,
    MediaVisibility.private => AppStrings.visibilityPrivateBody,
  };

  @override
  State<VisibilitySheet> createState() => _VisibilitySheetState();
}

class _VisibilitySheetState extends State<VisibilitySheet> {
  late MediaVisibility? _chosen = widget.current;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16.s,
      MediaQuery.paddingOf(context).top + 40.s,
      16.s,
      MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.base2,
                borderRadius: BorderRadius.circular(16.s),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18.s, 20.s, 18.s, 20.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(context),
                    SizedBox(height: 16.s),
                    Divider(color: AppColors.neutral800, height: 1.s),
                    SizedBox(height: 16.s),
                    for (final value in MediaVisibility.values) ...[
                      _Option(
                        optionKey: ValueKey('visibility-${value.slug}'),
                        title: VisibilitySheet.label(value),
                        body: VisibilitySheet._body(value),
                        selected: _chosen == value,
                        onTap: () => setState(() => _chosen = value),
                      ),
                      SizedBox(height: 10.s),
                    ],
                    SizedBox(height: 12.s),
                    PrimaryButton(
                      key: const ValueKey('visibility-confirm'),
                      label: AppStrings.newMediaDone,
                      height: 52.s,
                      enabled: _chosen != null,
                      onPressed: () => widget.onChoose(_chosen!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 14.s),
          GestureDetector(
            key: const ValueKey('visibility-cancel'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: EdgeInsets.only(bottom: 20.s),
              child: Text(
                AppStrings.goLiveCancel,
                textAlign: TextAlign.center,
                style: AppStyles.label(13, color: AppColors.neutral300),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          AppStrings.newMediaVisibilityLabel,
          style: AppStyles.heading(20, letterSpacing: -0.5),
        ),
      ),
      GestureDetector(
        key: const ValueKey('visibility-close'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: EdgeInsets.only(left: 12.s),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            color: AppColors.textPrimary,
            size: 20.s,
          ),
        ),
      ),
    ],
  );
}

class _Option extends StatelessWidget {
  const _Option({
    required this.optionKey,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final Key optionKey;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: optionKey,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(14.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.s),
        border: Border.all(
          color: selected ? AppColors.brandPrimary : AppColors.neutral800,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppStyles.label(14, weight: AppStyles.bold)),
                SizedBox(height: 4.s),
                Text(
                  body,
                  style: AppStyles.body(
                    13,
                    color: AppColors.neutral400,
                    lineHeight: 17 / 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.s),
          _Radio(on: selected),
        ],
      ),
    ),
  );
}

class _Radio extends StatelessWidget {
  const _Radio({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 20.s,
    height: 20.s,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.textPrimary, width: 1.6.s),
    ),
    child: on
        ? Container(
            width: 10.s,
            height: 10.s,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textPrimary,
            ),
          )
        : null,
  );
}
