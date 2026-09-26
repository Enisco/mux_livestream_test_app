import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/shared/components/markdown_body.dart';

/// The awkward shapes a hand-written parser gets wrong.
///
/// Tables and fences both consume lines beyond the one being looked at, which
/// is where an index walks off the end or eats the paragraph after it. These
/// pin the boundaries.
void main() {
  group('a table at the edges of a body', () {
    test('one that ends the body does not run off the end', () {
      final blocks = parseMarkdownBlocks('| a | b |\n| --- | --- |\n| 1 | 2 |');
      expect(blocks.single, isA<TableBlock>());
      expect((blocks.single as TableBlock).rows, [
        ['1', '2'],
      ]);
    });

    test('text straight after a table is not swallowed', () {
      final blocks = parseMarkdownBlocks(
        '| a |\n| --- |\n| 1 |\nAfter the table.',
      );
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<TableBlock>());
      expect((blocks[1] as ParagraphBlock).text, 'After the table.');
    });

    test('a row with fewer cells than the header still renders', () {
      final blocks = parseMarkdownBlocks('| a | b | c |\n|---|---|---|\n| 1 |');
      final table = blocks.single as TableBlock;
      expect(table.header, hasLength(3));
      expect(table.rows.single, ['1']);
    });

    test('a header with no rows is still a table', () {
      final blocks = parseMarkdownBlocks('| a | b |\n| --- | --- |');
      expect(blocks.single, isA<TableBlock>());
      expect((blocks.single as TableBlock).rows, isEmpty);
    });
  });

  group('blocks that meet without a blank line between them', () {
    test('a quote followed straight by a list', () {
      final blocks = parseMarkdownBlocks('> quoted\n- item');
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<QuoteBlock>());
      expect(blocks[1], isA<BulletBlock>());
    });

    test('a quote followed straight by a paragraph', () {
      final blocks = parseMarkdownBlocks('> quoted\nplain words');
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<QuoteBlock>());
      expect((blocks[1] as ParagraphBlock).text, 'plain words');
    });

    test('a heading straight after a list', () {
      final blocks = parseMarkdownBlocks('- item\n## Heading');
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<BulletBlock>());
      expect(blocks[1], isA<HeadingBlock>());
    });

    test('a rule between two paragraphs splits them', () {
      final blocks = parseMarkdownBlocks('before\n---\nafter');
      expect(blocks.map((b) => b.runtimeType.toString()), [
        'ParagraphBlock',
        'RuleBlock',
        'ParagraphBlock',
      ]);
    });

    test('a fence straight after a paragraph', () {
      final blocks = parseMarkdownBlocks('words\n```\ncode\n```');
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<ParagraphBlock>());
      expect((blocks[1] as CodeBlock).code, 'code');
    });

    test('text straight after a closing fence is its own paragraph', () {
      final blocks = parseMarkdownBlocks('```\ncode\n```\nafter');
      expect(blocks, hasLength(2));
      expect((blocks[1] as ParagraphBlock).text, 'after');
    });
  });

  group('nothing crashes on degenerate input', () {
    test('an empty body', () {
      expect(parseMarkdownBlocks(''), isEmpty);
    });

    test('only whitespace', () {
      expect(parseMarkdownBlocks('   \n\n  \n'), isEmpty);
    });

    test('a lone pipe', () {
      expect(parseMarkdownBlocks('|'), hasLength(1));
    });

    test('a divider with no header above it', () {
      final blocks = parseMarkdownBlocks('| --- | --- |');
      expect(blocks.single, isA<ParagraphBlock>());
    });

    test('windows line endings', () {
      final blocks = parseMarkdownBlocks('# Title\r\n\r\nBody.');
      expect(blocks[0], isA<HeadingBlock>());
      expect((blocks[1] as ParagraphBlock).text, 'Body.');
    });
  });
}
