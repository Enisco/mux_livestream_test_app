import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/post_draft_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Renders a post or devotional body.
///
/// **One renderer, used by both sides.** The editor's preview and the
/// reader's article screen used to have a renderer each — a 277-line one and
/// a 175-line one, covering different subsets — so the preview's promise,
/// "this is exactly how readers will see it", was not true of anything
/// outside their overlap. They are the same code now, which is the only way
/// that promise holds.
///
/// The content guide says bodies are **GFM with raw HTML disabled**, so this
/// covers what GFM actually offers: headings, bold, italic, strikethrough,
/// inline code, links, images, bullet/numbered/task lists, block quotes,
/// fenced code, tables and horizontal rules. Raw HTML is deliberately *not*
/// interpreted — it renders as the text it is, which is what disabling it
/// means.
///
/// `![alt](file:{id})` is this platform's own extension, which no markdown
/// package knows about, and is why the renderer is hand-written.
class MarkdownBody extends StatelessWidget {
  const MarkdownBody({super.key, required this.source, this.embeds = const []});

  final String source;

  /// Resolved `file:{id}` pictures, when the API has confirmed them.
  final List<BodyEmbed> embeds;

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownBlocks(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final block in blocks) ...[
          if (block != blocks.first) SizedBox(height: 10.s),
          _block(context, block),
        ],
      ],
    );
  }

  Widget _block(BuildContext context, MarkdownBlock block) => switch (block) {
    QuoteBlock(:final lines) => Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.s, 8.s, 12.s, 8.s),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.brandPrimary, width: 3.s),
        ),
        color: AppColors.neutral900,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            Text.rich(_inline(line, _quote), style: _quote),
        ],
      ),
    ),
    CodeBlock(:final code) => Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.s),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(8.s),
        border: Border.all(color: AppColors.neutral800),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(code, style: _code),
      ),
    ),
    RuleBlock() => Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: 6.s),
      color: AppColors.neutral800,
    ),
    TableBlock(:final header, :final rows) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: IntrinsicColumnWidth(),
        border: TableBorder.all(color: AppColors.neutral800, width: 1),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.neutral900),
            children: [
              for (final cell in header)
                Padding(
                  padding: EdgeInsets.all(8.s),
                  child: Text.rich(
                    _inline(cell, _tableHead),
                    style: _tableHead,
                  ),
                ),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                for (var i = 0; i < header.length; i++)
                  Padding(
                    padding: EdgeInsets.all(8.s),
                    child: Text.rich(
                      _inline(i < row.length ? row[i] : '', _body),
                      style: _body,
                    ),
                  ),
              ],
            ),
        ],
      ),
    ),
    HeadingBlock(:final level, :final text) => Text.rich(
      _inline(text, AppStyles.heading(level == 1 ? 20 : 17)),
      style: AppStyles.heading(level == 1 ? 20 : 17),
    ),
    BulletBlock(:final items, :final checks) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, item) in items.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: 4.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22.s,
                  child: checks.isNotEmpty
                      // A task list shows its state; GFM's boxes are not
                      // interactive in a rendered document.
                      ? Icon(
                          (i < checks.length && checks[i])
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          size: 15.s,
                          color: (i < checks.length && checks[i])
                              ? AppColors.brandPrimary
                              : AppColors.neutral500,
                        )
                      : Text(block.ordered ? '${i + 1}.' : '•', style: _body),
                ),
                Expanded(child: Text.rich(_inline(item, _body), style: _body)),
              ],
            ),
          ),
      ],
    ),
    ImageBlock(:final fileId, :final alt) => _image(fileId, alt),
    ParagraphBlock(:final text) => Text.rich(
      _inline(text, _body),
      style: _body,
    ),
  };

  static TextStyle get _body =>
      AppStyles.body(14, color: AppColors.neutral200, lineHeight: 22 / 14);

  static TextStyle get _quote => AppStyles.body(
    14,
    color: AppColors.neutral300,
    lineHeight: 22 / 14,
    fontStyle: FontStyle.italic,
  );

  static TextStyle get _code => AppStyles.body(
    12.5,
    family: 'monospace',
    color: AppColors.neutral200,
    lineHeight: 18 / 12.5,
  );

  static TextStyle get _tableHead => AppStyles.label(
    13,
    color: AppColors.textPrimary,
    weight: AppStyles.semiBold,
  );

  Widget _image(String fileId, String alt) {
    final embed = embeds
        .where((e) => e.fileId == fileId && e.available && e.url != null)
        .firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.s),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: embed == null
            // Until a saved post names it, the API answers `not_uploaded`.
            ? Container(
                color: AppColors.brandAltDark,
                alignment: Alignment.center,
                child: Text(
                  alt.isEmpty ? fileId : alt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppStyles.label(12, color: AppColors.neutral500),
                ),
              )
            : Image.network(
                embed.url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AppColors.brandAltDark),
              ),
      ),
    );
  }

  /// **bold**, *italic* and [links](url) inside one line.
  static TextSpan _inline(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final pattern = RegExp(
      r'`([^`]+)`'
      r'|\*\*(.+?)\*\*|__(.+?)__'
      r'|~~(.+?)~~'
      r'|\*(.+?)\*|_(.+?)_'
      r'|\[([^\]]+)\]\(([^)]+)\)',
    );

    var at = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > at) {
        spans.add(TextSpan(text: text.substring(at, match.start)));
      }
      // Inline code first: backticks suspend every other marker inside them.
      if (match.group(1) case final code?) {
        spans.add(
          TextSpan(
            text: code,
            style: base.copyWith(
              fontFamily: 'monospace',
              color: AppColors.brandPrimary,
              backgroundColor: AppColors.neutral900,
            ),
          ),
        );
      } else if (match.group(4) case final struck?) {
        spans.add(
          TextSpan(
            text: struck,
            style: base.copyWith(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (match.group(2) ?? match.group(3) case final bold?) {
        spans.add(
          TextSpan(
            text: bold,
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (match.group(5) ?? match.group(6) case final italic?) {
        spans.add(
          TextSpan(
            text: italic,
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(7) case final label?) {
        final href = match.group(8) ?? '';
        spans.add(
          TextSpan(
            text: label,
            style: base.copyWith(
              color: AppColors.brandPrimary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.brandPrimary,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _open(href),
          ),
        );
      }
      at = match.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));

    return TextSpan(style: base, children: spans);
  }

  static Future<void> _open(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      logger.w('Could not open $href', error: e);
    }
  }
}

/// One piece of a parsed body.
sealed class MarkdownBlock {
  const MarkdownBlock();
}

class ParagraphBlock extends MarkdownBlock {
  const ParagraphBlock(this.text);

  final String text;
}

class HeadingBlock extends MarkdownBlock {
  const HeadingBlock(this.level, this.text);

  /// 1, 2 or 3 — deeper headings read as level 3.
  final int level;
  final String text;
}

class BulletBlock extends MarkdownBlock {
  const BulletBlock(this.items, {this.ordered = false, this.checks = const []});

  final List<String> items;
  final bool ordered;

  /// Non-empty for a GFM task list, one entry per item.
  final List<bool> checks;
}

class QuoteBlock extends MarkdownBlock {
  const QuoteBlock(this.lines);

  final List<String> lines;
}

class CodeBlock extends MarkdownBlock {
  const CodeBlock(this.code, {this.language = ''});

  final String code;
  final String language;
}

class RuleBlock extends MarkdownBlock {
  const RuleBlock();
}

class TableBlock extends MarkdownBlock {
  const TableBlock(this.header, this.rows);

  final List<String> header;
  final List<List<String>> rows;
}

class ImageBlock extends MarkdownBlock {
  const ImageBlock(this.fileId, this.alt);

  final String fileId;
  final String alt;
}

final _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');
final _bulletPattern = RegExp(r'^[-*]\s+(.*)$');
final _orderedPattern = RegExp(r'^\d+\.\s+(.*)$');

/// A whole-line image is its own block; one inside a sentence stays inline
/// text, which is what the design's body shows.
final _imagePattern = RegExp(r'^!\[([^\]]*)\]\(file:([^)]+)\)$');

/// `> quoted`, with the marker optionally repeated for nesting. Depth is not
/// drawn; one rule reads the same and nests are rare in these bodies.
final _quotePattern = RegExp(r'^>+\s?(.*)$');

/// ``` or ~~~, optionally followed by a language.
final _fencePattern = RegExp(r'^(```|~~~)\s*(\w*)\s*$');

/// `---`, `***` or `___` on a line of its own. Guarded against `--- ` under a
/// table header and against a `***bold***` line.
final _rulePattern = RegExp(r'^(-{3,}|\*{3,}|_{3,})$');

/// `- [ ] todo` / `- [x] done`.
final _taskPattern = RegExp(r'^[-*]\s+\[([ xX])\]\s+(.*)$');

/// A table's separator row: `| --- | :--: |`.
final _tableDividerPattern = RegExp(r'^\|?[\s:|-]+\|[\s:|-]*$');

List<String> _cells(String row) {
  var line = row.trim();
  if (line.startsWith('|')) line = line.substring(1);
  if (line.endsWith('|')) line = line.substring(0, line.length - 1);
  return line.split('|').map((c) => c.trim()).toList();
}

/// Splits a body into blocks. Unknown syntax survives as a paragraph.
List<MarkdownBlock> parseMarkdownBlocks(String source) {
  final blocks = <MarkdownBlock>[];
  final paragraph = <String>[];
  var bullets = <String>[];
  var checks = <bool>[];
  var ordered = false;
  var quote = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(ParagraphBlock(paragraph.join(' ')));
    paragraph.clear();
  }

  void flushBullets() {
    if (bullets.isEmpty) return;
    blocks.add(
      BulletBlock(List.of(bullets), ordered: ordered, checks: List.of(checks)),
    );
    bullets = [];
    checks = [];
  }

  void flushQuote() {
    if (quote.isEmpty) return;
    blocks.add(QuoteBlock(List.of(quote)));
    quote = [];
  }

  void flushAll() {
    flushParagraph();
    flushBullets();
    flushQuote();
  }

  final lines = source.replaceAll('\r\n', '\n').split('\n');
  for (var index = 0; index < lines.length; index++) {
    final raw = lines[index];
    final line = raw.trim();

    // A fence swallows everything up to its partner, verbatim — markers
    // inside code are code, not formatting.
    if (_fencePattern.firstMatch(line) case final fence?) {
      flushAll();
      final body = <String>[];
      var closed = false;
      for (index += 1; index < lines.length; index++) {
        if (_fencePattern.hasMatch(lines[index].trim())) {
          closed = true;
          break;
        }
        body.add(lines[index]);
      }
      // An unclosed fence still renders as code; dropping the rest of the
      // body because someone forgot a fence would be worse.
      if (!closed) index = lines.length;
      blocks.add(CodeBlock(body.join('\n'), language: fence.group(2) ?? ''));
      continue;
    }

    // A table is its header, a divider, then rows.
    if (line.contains('|') &&
        index + 1 < lines.length &&
        _tableDividerPattern.hasMatch(lines[index + 1].trim()) &&
        lines[index + 1].contains('-')) {
      flushAll();
      final header = _cells(line);
      final rows = <List<String>>[];
      index += 2;
      while (index < lines.length && lines[index].trim().contains('|')) {
        rows.add(_cells(lines[index]));
        index += 1;
      }
      index -= 1;
      blocks.add(TableBlock(header, rows));
      continue;
    }

    if (line.isEmpty) {
      flushAll();
      continue;
    }

    if (_quotePattern.firstMatch(line) case final match?
        when line.startsWith('>')) {
      flushParagraph();
      flushBullets();
      quote.add(match.group(1)!.trim());
      continue;
    }
    flushQuote();

    if (_rulePattern.hasMatch(line)) {
      flushAll();
      blocks.add(const RuleBlock());
      continue;
    }

    if (_taskPattern.firstMatch(line) case final match?) {
      flushParagraph();
      if (ordered || (bullets.isNotEmpty && checks.isEmpty)) flushBullets();
      ordered = false;
      checks.add(match.group(1)!.toLowerCase() == 'x');
      bullets.add(match.group(2)!);
      continue;
    }
    if (_imagePattern.firstMatch(line) case final match?) {
      flushParagraph();
      flushBullets();
      blocks.add(ImageBlock(match.group(2)!, match.group(1) ?? ''));
      continue;
    }
    if (_headingPattern.firstMatch(line) case final match?) {
      flushParagraph();
      flushBullets();
      blocks.add(
        HeadingBlock(
          match.group(1)!.length.clamp(1, 3),
          match.group(2)!.trim(),
        ),
      );
      continue;
    }
    if (_bulletPattern.firstMatch(line) case final match?) {
      flushParagraph();
      // A plain bullet does not belong to a task list, or to a numbered one.
      if (ordered || checks.isNotEmpty) flushBullets();
      ordered = false;
      bullets.add(match.group(1)!);
      continue;
    }
    if (_orderedPattern.firstMatch(line) case final match?) {
      flushParagraph();
      if ((!ordered && bullets.isNotEmpty) || checks.isNotEmpty) {
        flushBullets();
      }
      ordered = true;
      bullets.add(match.group(1)!);
      continue;
    }
    flushBullets();
    paragraph.add(line);
  }

  flushAll();
  return blocks;
}
