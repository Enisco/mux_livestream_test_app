import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Renders the small slice of markdown that post and devotional bodies use.
///
/// Content bodies come back as markdown source. Dumping it raw shows `##` and
/// `**` on screen, and a full markdown package is more dependency than these
/// bodies justify — headings, bullets, numbered steps, quotes and bold spans
/// cover what the editor produces.
class MarkdownBody extends StatelessWidget {
  const MarkdownBody({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _blocks(source).toList(),
    );
  }

  Iterable<Widget> _blocks(String raw) sync* {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final paragraph = <String>[];

    Widget? flush() {
      if (paragraph.isEmpty) return null;
      final text = paragraph.join(' ').trim();
      paragraph.clear();
      if (text.isEmpty) return null;
      return Padding(
        padding: EdgeInsets.only(bottom: 14.s),
        child: _RichLine(text: text, style: _bodyStyle),
      );
    }

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        final block = flush();
        if (block != null) yield block;
        continue;
      }

      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        final block = flush();
        if (block != null) yield block;
        final level = heading.group(1)!.length;
        yield Padding(
          padding: EdgeInsets.only(top: 6.s, bottom: 8.s),
          child: Text(
            heading.group(2)!,
            style: AppStyles.heading(switch (level) {
              1 => 18,
              2 => 16,
              _ => 14,
            }, lineHeight: 1.35),
          ),
        );
        continue;
      }

      final quote = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
      if (quote != null) {
        final block = flush();
        if (block != null) yield block;
        yield Container(
          margin: EdgeInsets.only(bottom: 14.s),
          padding: EdgeInsets.only(left: 12.s),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.brandPrimary, width: 2.s),
            ),
          ),
          child: _RichLine(
            text: quote.group(1)!,
            style: _bodyStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        continue;
      }

      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
      final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null || numbered != null) {
        final block = flush();
        if (block != null) yield block;
        yield Padding(
          padding: EdgeInsets.only(bottom: 8.s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22.s,
                child: Text(
                  numbered != null ? '${numbered.group(1)}.' : '•',
                  style: _bodyStyle.copyWith(color: AppColors.brandPrimary),
                ),
              ),
              Expanded(
                child: _RichLine(
                  text: (bullet ?? numbered)!.group(bullet != null ? 1 : 2)!,
                  style: _bodyStyle,
                ),
              ),
            ],
          ),
        );
        continue;
      }

      paragraph.add(trimmed);
    }

    final tail = flush();
    if (tail != null) yield tail;
  }

  static TextStyle get _bodyStyle =>
      AppStyles.body(14, color: AppColors.neutral300, lineHeight: 22 / 14);
}

/// Handles `**bold**` and `*italic*` inside a line.
class _RichLine extends StatelessWidget {
  const _RichLine({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    var index = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: const TextStyle(color: AppColors.brandPrimary),
          ),
        );
      }
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
