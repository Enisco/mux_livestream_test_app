import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// The pieces the New article screen is made of.

/// Write | Preview — the pair at the top of the editor.
class WritePreviewTabs extends StatelessWidget {
  const WritePreviewTabs({
    super.key,
    required this.previewing,
    required this.onChanged,
  });

  final bool previewing;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(4.s),
    decoration: BoxDecoration(
      color: AppColors.fieldBg,
      borderRadius: BorderRadius.circular(999.s),
    ),
    child: Row(
      children: [
        _tab(AppStrings.articleWrite, !previewing, () => onChanged(false)),
        _tab(AppStrings.articlePreview, previewing, () => onChanged(true)),
      ],
    ),
  );

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      key: ValueKey('article-tab-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 38.s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(999.s),
        ),
        child: Text(
          label,
          style: AppStyles.label(
            13,
            weight: AppStyles.bold,
            color: active ? AppColors.base1 : AppColors.neutral200,
          ),
        ),
      ),
    ),
  );
}

/// What the toolbar can write. Each one wraps the selection, or drops a
/// placeholder where the cursor is.
enum MarkdownTool {
  bold('**', '**', AppStrings.articleBoldPlaceholder),
  italic('*', '*', AppStrings.articleItalicPlaceholder),
  heading('## ', '', AppStrings.articleHeadingPlaceholder),
  bullet('- ', '', AppStrings.articleBulletPlaceholder),
  link('[', '](https://)', AppStrings.articleLinkPlaceholder);

  const MarkdownTool(this.before, this.after, this.placeholder);

  final String before;
  final String after;
  final String placeholder;

  /// A heading and a bullet lead their own line rather than wrapping what
  /// is already there.
  bool get isLinePrefix =>
      this == MarkdownTool.heading || this == MarkdownTool.bullet;
}

/// Applies [tool] to [controller]'s current selection, leaving the cursor
/// where the creator can carry on typing.
void applyMarkdownTool(TextEditingController controller, MarkdownTool tool) {
  final text = controller.text;
  final selection = controller.selection;
  final start = selection.start < 0 ? text.length : selection.start;
  final end = selection.end < 0 ? text.length : selection.end;
  final selected = text.substring(start, end);

  if (tool.isLinePrefix) {
    // Go to the head of the line the cursor is on, and open a new one if
    // that line already has something on it.
    final lineStart = text.lastIndexOf('\n', start == 0 ? 0 : start - 1) + 1;
    final onBlankLine = text.substring(lineStart, start).trim().isEmpty;
    final lead = onBlankLine ? tool.before : '\n${tool.before}';
    final insert = selected.isEmpty
        ? '$lead${tool.placeholder}'
        : '$lead$selected';
    final at = onBlankLine ? lineStart : start;

    controller.value = TextEditingValue(
      text: text.replaceRange(at, end, insert),
      selection: TextSelection(
        baseOffset: at + lead.length,
        extentOffset: at + insert.length,
      ),
    );
    return;
  }

  final inner = selected.isEmpty ? tool.placeholder : selected;
  final insert = '${tool.before}$inner${tool.after}';
  controller.value = TextEditingValue(
    text: text.replaceRange(start, end, insert),
    selection: TextSelection(
      baseOffset: start + tool.before.length,
      extentOffset: start + tool.before.length + inner.length,
    ),
  );
}

/// Drops an `![alt](file:{id})` at the cursor, on its own line.
void insertMarkdownImage(
  TextEditingController controller, {
  required String fileId,
  String alt = '',
}) {
  final text = controller.text;
  final at = controller.selection.start < 0
      ? text.length
      : controller.selection.start;
  final lead = at == 0 || text[at - 1] == '\n' ? '' : '\n';
  final insert = '$lead![$alt](file:$fileId)\n';

  controller.value = TextEditingValue(
    text: text.replaceRange(at, at, insert),
    selection: TextSelection.collapsed(offset: at + insert.length),
  );
}

/// B / I / H / list / link / image, and the button that files the article.
class MarkdownToolbar extends StatelessWidget {
  const MarkdownToolbar({
    super.key,
    required this.onTool,
    required this.onImage,
    required this.action,
  });

  final ValueChanged<MarkdownTool> onTool;
  final VoidCallback onImage;

  /// The Publish button, which the design puts on this row.
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final tool in MarkdownTool.values)
        _button(
          key: ValueKey('article-tool-${tool.name}'),
          onTap: () => onTool(tool),
          child: switch (tool) {
            MarkdownTool.bold => Text(
              'B',
              style: AppStyles.label(15, weight: AppStyles.bold),
            ),
            MarkdownTool.italic => Text(
              'I',
              style: AppStyles.label(15).copyWith(fontStyle: FontStyle.italic),
            ),
            MarkdownTool.heading => Text(
              'H',
              style: AppStyles.label(15, weight: AppStyles.bold),
            ),
            MarkdownTool.bullet => HugeIcon(
              icon: HugeIcons.strokeRoundedLeftToRightListBullet,
              color: AppColors.textPrimary,
              size: 18.s,
            ),
            MarkdownTool.link => HugeIcon(
              icon: HugeIcons.strokeRoundedLink02,
              color: AppColors.textPrimary,
              size: 18.s,
            ),
          },
        ),
      _button(
        key: const ValueKey('article-tool-image'),
        onTap: onImage,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedImage02,
          color: AppColors.textPrimary,
          size: 18.s,
        ),
      ),
      const Spacer(),
      action,
    ],
  );

  Widget _button({
    required Key key,
    required VoidCallback onTap,
    required Widget child,
  }) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 32.s,
      height: 34.s,
      alignment: Alignment.center,
      child: child,
    ),
  );
}

/// Asks for the address a `[link]()` should point at.
Future<String?> askForLink(BuildContext context) {
  final controller = TextEditingController(text: 'https://');
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.base2,
      title: Text(
        AppStrings.articleLinkTitle,
        style: AppStyles.label(15, weight: AppStyles.bold),
      ),
      content: TextField(
        key: const ValueKey('article-link-field'),
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
        style: AppStyles.body(13, color: AppColors.neutral50),
        cursorColor: AppColors.textPrimary,
        decoration: InputDecoration(
          hintText: AppStrings.articleLinkHint,
          hintStyle: AppStyles.body(13, color: AppColors.neutral400),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(
            AppStrings.goLiveCancel,
            style: AppStyles.label(13, color: AppColors.neutral300),
          ),
        ),
        TextButton(
          key: const ValueKey('article-link-ok'),
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: Text(
            AppStrings.newMediaDone,
            style: AppStyles.label(
              13,
              weight: AppStyles.bold,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
