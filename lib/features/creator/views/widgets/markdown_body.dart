import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sizing/sizing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/models/creator_models/post_draft_models.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// Renders the markdown the article editor produces.
///
/// Deliberately narrow: it covers exactly what the toolbar can write —
/// headings, **bold**, *italic*, bullet and numbered lists, `[links]()`
/// and `![images](file:id)` — plus blank-line paragraphs. Anything else a
/// creator types renders as the plain text it is, rather than disappearing.
///
/// It is not a GFM engine. The guide says web clients render post bodies as
/// GFM with raw HTML disabled; when the viewer's article screen is built,
/// that renderer and this preview should be the same one, or the preview's
/// promise — "this is exactly how readers will see it" — stops being true
/// (OPEN_ISSUES 34).
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
    HeadingBlock(:final level, :final text) => Text.rich(
      _inline(text, AppStyles.heading(level == 1 ? 20 : 17)),
      style: AppStyles.heading(level == 1 ? 20 : 17),
    ),
    BulletBlock(:final items) => Column(
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
                  width: 20.s,
                  child: Text(block.ordered ? '${i + 1}.' : '•', style: _body),
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
      r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|\[([^\]]+)\]\(([^)]+)\)',
    );

    var at = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > at) {
        spans.add(TextSpan(text: text.substring(at, match.start)));
      }
      if (match.group(1) ?? match.group(2) case final bold?) {
        spans.add(
          TextSpan(
            text: bold,
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (match.group(3) ?? match.group(4) case final italic?) {
        spans.add(
          TextSpan(
            text: italic,
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(5) case final label?) {
        final href = match.group(6) ?? '';
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
  const BulletBlock(this.items, {this.ordered = false});

  final List<String> items;
  final bool ordered;
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

/// Splits a body into blocks. Unknown syntax survives as a paragraph.
List<MarkdownBlock> parseMarkdownBlocks(String source) {
  final blocks = <MarkdownBlock>[];
  final paragraph = <String>[];
  var bullets = <String>[];
  var ordered = false;

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(ParagraphBlock(paragraph.join(' ')));
    paragraph.clear();
  }

  void flushBullets() {
    if (bullets.isEmpty) return;
    blocks.add(BulletBlock(List.of(bullets), ordered: ordered));
    bullets = [];
  }

  for (final raw in source.split('\n')) {
    final line = raw.trim();

    if (line.isEmpty) {
      flushParagraph();
      flushBullets();
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
      if (ordered) flushBullets();
      ordered = false;
      bullets.add(match.group(1)!);
      continue;
    }
    if (_orderedPattern.firstMatch(line) case final match?) {
      flushParagraph();
      if (!ordered && bullets.isNotEmpty) flushBullets();
      ordered = true;
      bullets.add(match.group(1)!);
      continue;
    }
    flushBullets();
    paragraph.add(line);
  }

  flushParagraph();
  flushBullets();
  return blocks;
}
