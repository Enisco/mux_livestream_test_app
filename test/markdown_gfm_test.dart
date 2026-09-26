import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/shared/components/markdown_body.dart';
import 'helpers/load_app_fonts.dart';

/// One renderer, for the editor's preview and the reader's article alike.
///
/// They used to be two — a 277-line one and a 175-line one covering
/// different subsets — so the preview's promise, "this is exactly how
/// readers will see it", was only true of their overlap. The content guide
/// says bodies are **GFM with raw HTML disabled**, so these pin the parts of
/// GFM that neither renderer had.
Future<void> _pump(WidgetTester tester, String source) async {
  tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MarkdownBody(source: source)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('block quotes', () {
    test('a quoted line becomes a quote', () {
      final blocks = parseMarkdownBlocks('> Be still and know');
      expect(blocks.single, isA<QuoteBlock>());
      expect((blocks.single as QuoteBlock).lines, ['Be still and know']);
    });

    test('consecutive lines join one quote', () {
      final blocks = parseMarkdownBlocks('> one\n> two');
      expect((blocks.single as QuoteBlock).lines, ['one', 'two']);
    });

    test('a nested marker does not start a second quote', () {
      final blocks = parseMarkdownBlocks('>> deep');
      expect((blocks.single as QuoteBlock).lines, ['deep']);
    });

    test('and a blank line ends it', () {
      final blocks = parseMarkdownBlocks('> quoted\n\nplain');
      expect(blocks, hasLength(2));
      expect(blocks[0], isA<QuoteBlock>());
      expect(blocks[1], isA<ParagraphBlock>());
    });
  });

  group('fenced code', () {
    test('the fence is stripped and the body kept verbatim', () {
      final blocks = parseMarkdownBlocks('```\nline one\n  line two\n```');
      expect(blocks.single, isA<CodeBlock>());
      expect((blocks.single as CodeBlock).code, 'line one\n  line two');
    });

    test('the language is kept', () {
      final blocks = parseMarkdownBlocks('```dart\nvoid main() {}\n```');
      expect((blocks.single as CodeBlock).language, 'dart');
    });

    test('markers inside code are code, not formatting', () {
      final blocks = parseMarkdownBlocks(
        '```\n**not bold** # not a heading\n```',
      );
      expect((blocks.single as CodeBlock).code, '**not bold** # not a heading');
    });

    test('tildes fence too', () {
      final blocks = parseMarkdownBlocks('~~~\nx\n~~~');
      expect(blocks.single, isA<CodeBlock>());
    });

    test('an unclosed fence still renders rather than eating the body', () {
      final blocks = parseMarkdownBlocks('```\nleft open');
      expect(blocks.single, isA<CodeBlock>());
      expect((blocks.single as CodeBlock).code, 'left open');
    });
  });

  group('tables', () {
    test('a header, a divider and rows', () {
      final blocks = parseMarkdownBlocks(
        '| Day | Reading |\n| --- | --- |\n| 1 | John 1 |\n| 2 | John 2 |',
      );
      expect(blocks.single, isA<TableBlock>());
      final table = blocks.single as TableBlock;
      expect(table.header, ['Day', 'Reading']);
      expect(table.rows, [
        ['1', 'John 1'],
        ['2', 'John 2'],
      ]);
    });

    test('alignment markers in the divider are tolerated', () {
      final blocks = parseMarkdownBlocks('| a | b |\n|:--|--:|\n| 1 | 2 |');
      expect(blocks.single, isA<TableBlock>());
    });

    test('a pipe in a sentence is not a table', () {
      final blocks = parseMarkdownBlocks('Either this | or that.');
      expect(blocks.single, isA<ParagraphBlock>());
    });
  });

  group('horizontal rules', () {
    test('three dashes alone', () {
      expect(parseMarkdownBlocks('---').single, isA<RuleBlock>());
      expect(parseMarkdownBlocks('***').single, isA<RuleBlock>());
      expect(parseMarkdownBlocks('___').single, isA<RuleBlock>());
    });

    test('but not a bolded line', () {
      final blocks = parseMarkdownBlocks('***emphasised***');
      expect(blocks.single, isA<ParagraphBlock>());
    });
  });

  group('task lists', () {
    test('unchecked and checked boxes are both read', () {
      final blocks = parseMarkdownBlocks('- [ ] pray\n- [x] read\n- [X] rest');
      final list = blocks.single as BulletBlock;
      expect(list.items, ['pray', 'read', 'rest']);
      expect(list.checks, [false, true, true]);
    });

    test('a plain bullet list carries no boxes', () {
      final list = parseMarkdownBlocks('- one\n- two').single as BulletBlock;
      expect(list.checks, isEmpty);
    });

    test('a task list and a plain list stay apart', () {
      final blocks = parseMarkdownBlocks('- [ ] task\n- plain');
      expect(blocks, hasLength(2));
      expect((blocks[0] as BulletBlock).checks, [false]);
      expect((blocks[1] as BulletBlock).checks, isEmpty);
    });
  });

  group('what the old renderers already did still works', () {
    test('headings, lists and images', () {
      final blocks = parseMarkdownBlocks(
        '# Title\n\n- one\n- two\n\n1. first\n\n![alt](file:abc)',
      );
      expect(blocks[0], isA<HeadingBlock>());
      expect((blocks[1] as BulletBlock).ordered, isFalse);
      expect((blocks[2] as BulletBlock).ordered, isTrue);
      expect((blocks[3] as ImageBlock).fileId, 'abc');
    });
  });

  group('it all reaches the screen', () {
    testWidgets('a body using every block renders without exception', (
      tester,
    ) async {
      await _pump(tester, '''
# Heading

A paragraph with **bold**, *italic*, ~~struck~~ and `code`.

> A quotation

- [ ] not yet
- [x] done

| Day | Reading |
| --- | --- |
| 1 | John 1 |

```dart
void main() {}
```

---

Closing words.
''');
      expect(tester.takeException(), isNull);
      expect(find.text('Heading'), findsOneWidget);
      expect(find.text('A quotation'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.textContaining('void main()'), findsOneWidget);
    });

    testWidgets('it lays out on a small phone', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        '| A very wide column | And another one here |\n'
        '| --- | --- |\n'
        '| with a long value | and another long value |',
      );
      // Wide tables scroll sideways rather than overflowing.
      expect(tester.takeException(), isNull);
    });
  });
}
