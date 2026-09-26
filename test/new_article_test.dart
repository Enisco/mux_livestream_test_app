import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/post_repo.dart';
import 'package:test_app/features/creator/views/new_article_screen.dart';
import 'package:test_app/shared/components/markdown_body.dart';
import 'package:test_app/features/creator/views/widgets/new_article_parts.dart';
import 'package:test_app/models/creator_models/post_draft_models.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

class _FakeApi implements ApiService {
  _FakeApi({this.body, this.error});

  Map<String, dynamic>? body;
  DioException? error;

  final List<String> paths = [];
  final Map<String, Map<String, dynamic>> sent = {};

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    paths.add(path);
    if (data is Map<String, dynamic>) sent[path] = data;
    if (error != null) throw error!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (body ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) async {
    paths.add(path);
    if (data is Map<String, dynamic>) sent[path] = data;
    if (error != null) throw error!;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: (body ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

DioException _refusal(List<String> errors) => DioException(
  requestOptions: RequestOptions(path: '/v1/content/posts'),
  response: Response(
    requestOptions: RequestOptions(path: '/v1/content/posts'),
    statusCode: 400,
    data: {'success': false, 'data': null, 'error': errors},
  ),
);

Future<void> _pumpScreen(WidgetTester tester, {Size? size}) async {
  final api = _FakeApi(
    body: const {
      'data': {'id': 'p1'},
    },
  );
  final view = size ?? const Size(390, 1600);
  tester.view.physicalSize = view * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: NewArticleScreen(creatorId: 'c1', posts: PostRepo(api)),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpWidget(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 900),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: size.width, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  group('what the API will take', () {
    test('a headline is required even to save a draft', () {
      // "title must be longer than or equal to 1 characters" — the design
      // calls the headline optional.
      expect(const PostDraft(title: '  ').publishBlock, PostPublishBlock.title);
      expect(
        const PostDraft(title: 'Why we still gather').publishBlock,
        PostPublishBlock.body,
      );
      expect(
        const PostDraft(
          title: 'Why we still gather',
          body: 'Words.',
        ).publishBlock,
        isNull,
      );
    });

    test('the body carries no field create refuses', () {
      final body = const PostDraft(
        title: 'Why we still gather',
        body: 'Words.',
        coverThumbnailFileId: 'f1',
      ).toJson('c1');

      expect(body['title'], 'Why we still gather');
      expect(body['coverThumbnailFileId'], 'f1');
      // Create answers "property scheduledAt should not exist"; it goes on
      // with a PATCH instead.
      expect(body.containsKey('scheduledAt'), isFalse);
    });

    test('read time counts words, not the image tokens between them', () {
      final words = List.filled(400, 'word').join(' ');
      expect(PostDraft(title: 'T', body: words).readMinutes, 2);
      expect(
        const PostDraft(
          title: 'T',
          body: '![a](file:123) ![b](file:456)',
        ).readMinutes,
        1,
      );
    });
  });

  group('the repo', () {
    test('scheduling is a PATCH, not part of create', () async {
      final api = _FakeApi(
        body: const {
          'data': {'id': 'p1'},
        },
      );
      final repo = PostRepo(api);

      await repo.create(
        creatorId: 'c1',
        draft: const PostDraft(title: 'T', body: 'B'),
      );
      await repo.schedule(postId: 'p1', at: DateTime.utc(2026, 10, 5, 18));

      expect(
        api.sent['/v1/content/posts']!.containsKey('scheduledAt'),
        isFalse,
      );
      expect(api.sent['/v1/content/posts/p1'], {
        'scheduledAt': '2026-10-05T18:00:00.000Z',
      });
    });

    test('publishing sends nothing', () async {
      final api = _FakeApi(body: const {'data': {}});
      await PostRepo(api).publish('p1');
      expect(api.sent['/v1/content/posts/p1/publish'], isEmpty);
    });

    test('each refusal is named', () async {
      for (final (sentence, failure) in [
        ('Add post content before publishing this post', PostFailure.needsBody),
        (
          'title must be longer than or equal to 1 characters',
          PostFailure.needsTitle,
        ),
        ('scheduledAt must be in the future', PostFailure.scheduleInPast),
      ]) {
        final api = _FakeApi(error: _refusal([sentence]));
        await expectLater(
          PostRepo(api).create(
            creatorId: 'c1',
            draft: const PostDraft(title: 'T'),
          ),
          throwsA(
            isA<PostException>().having((e) => e.failure, sentence, failure),
          ),
        );
      }
    });

    test('an unresolvable embed leaves the words alone', () async {
      final api = _FakeApi(error: _refusal(['nope']));
      expect(
        await PostRepo(api).resolveEmbeds(creatorId: 'c1', body: 'x'),
        isEmpty,
      );
    });
  });

  group('the markdown the toolbar writes', () {
    test('bold wraps a selection and keeps it selected', () {
      final controller = TextEditingController(text: 'prayer can sit down')
        ..selection = const TextSelection(baseOffset: 0, extentOffset: 6);

      applyMarkdownTool(controller, MarkdownTool.bold);

      expect(controller.text, '**prayer** can sit down');
      expect(
        controller.text.substring(
          controller.selection.start,
          controller.selection.end,
        ),
        'prayer',
      );
    });

    test('with nothing selected it drops a placeholder', () {
      final controller = TextEditingController()
        ..selection = const TextSelection.collapsed(offset: 0);

      applyMarkdownTool(controller, MarkdownTool.italic);

      expect(controller.text, '*${AppStrings.articleItalicPlaceholder}*');
    });

    test('a heading opens its own line rather than wrapping mid-sentence', () {
      final controller = TextEditingController(text: 'People ask why.')
        ..selection = const TextSelection.collapsed(offset: 15);

      applyMarkdownTool(controller, MarkdownTool.heading);

      expect(
        controller.text,
        'People ask why.\n## ${AppStrings.articleHeadingPlaceholder}',
      );
    });

    test('an image lands on a line of its own', () {
      final controller = TextEditingController(text: 'Before.')
        ..selection = const TextSelection.collapsed(offset: 7);

      insertMarkdownImage(controller, fileId: 'f1', alt: 'Draw near');

      expect(controller.text, 'Before.\n![Draw near](file:f1)\n');
    });
  });

  group('rendering it back', () {
    test('blocks come apart the way they were written', () {
      final blocks = parseMarkdownBlocks(
        'Every year our church sets aside twenty-one days.\n'
        '\n'
        "## It isn't hunger, it's focus\n"
        '\n'
        '![Draw near](file:abc)\n'
        '\n'
        '- Week one: meals until sunset\n'
        '- Week two: screens after nine\n',
      );

      expect(blocks, hasLength(4));
      expect(blocks[0], isA<ParagraphBlock>());
      expect(blocks[1], isA<HeadingBlock>());
      expect((blocks[1] as HeadingBlock).level, 2);
      expect(blocks[2], isA<ImageBlock>());
      expect((blocks[2] as ImageBlock).fileId, 'abc');
      expect((blocks[3] as BulletBlock).items, hasLength(2));
    });

    test('raw HTML is left as the text it is, because GFM disables it', () {
      final blocks = parseMarkdownBlocks('<script>alert(1)</script>');
      expect(blocks.single, isA<ParagraphBlock>());
      expect((blocks.single as ParagraphBlock).text, contains('<script>'));
    });

    testWidgets('bold, headings and lists all reach the screen', (
      tester,
    ) async {
      await _pumpWidget(
        tester,
        const MarkdownBody(
          source:
              'Fasting clears the table so **prayer can sit down**.\n'
              '\n'
              '## It is focus\n'
              '\n'
              '- Week one\n',
        ),
      );

      expect(find.textContaining('prayer can sit down'), findsOneWidget);
      expect(find.textContaining('It is focus'), findsOneWidget);
      expect(find.textContaining('Week one'), findsOneWidget);
      // The syntax itself is gone.
      expect(find.textContaining('**', findRichText: true), findsNothing);
    });

    testWidgets('an unconfirmed picture shows its alt, not a broken image', (
      tester,
    ) async {
      await _pumpWidget(
        tester,
        const MarkdownBody(source: '![Draw near](file:abc)'),
      );

      // Until a saved post names it the API answers `not_uploaded`.
      expect(find.text('Draw near'), findsOneWidget);
    });
  });

  group('the screen', () {
    testWidgets('it opens on Write, with Publish shut', (tester) async {
      await _pumpScreen(tester);

      expect(find.text(AppStrings.newArticleTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('article-body')), findsOneWidget);
      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const ValueKey('article-publish')),
            )
            .enabled,
        isFalse,
      );
    });

    testWidgets('a headline alone is not enough to publish', (tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('article-title')),
        'Why we still gather',
      );
      await tester.pump();
      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const ValueKey('article-publish')),
            )
            .enabled,
        isFalse,
      );

      await tester.enterText(
        find.byKey(const ValueKey('article-body')),
        'Every year our church sets aside twenty-one days.',
      );
      await tester.pump();
      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(const ValueKey('article-publish')),
            )
            .enabled,
        isTrue,
      );
    });

    testWidgets('Preview renders the words rather than the markdown', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.byKey(const ValueKey('article-title')),
        'Why we still gather',
      );
      await tester.enterText(
        find.byKey(const ValueKey('article-body')),
        'Fasting clears the table so **prayer can sit down**.',
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('article-tab-${AppStrings.articlePreview}')),
      );
      await tester.pump();

      expect(find.text(AppStrings.articlePreviewNote), findsOneWidget);
      expect(find.textContaining('prayer can sit down'), findsOneWidget);
      // The editor's toolbar is put away while previewing.
      expect(find.byKey(const ValueKey('article-tool-bold')), findsNothing);
    });

    testWidgets('the preview claims no figures the post has not earned', (
      tester,
    ) async {
      await _pumpScreen(tester);
      await tester.enterText(
        find.byKey(const ValueKey('article-body')),
        List.filled(400, 'word').join(' '),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('article-tab-${AppStrings.articlePreview}')),
      );
      await tester.pump();

      // The design shows "12.9K Opens · 2 min read · 6 hours ago"; a post
      // that does not exist has no opens and no age.
      expect(find.textContaining('2 min read'), findsOneWidget);
      expect(find.textContaining('Opens'), findsNothing);
      expect(find.textContaining(AppStrings.articleDraftBadge), findsOneWidget);
    });

    testWidgets('nothing overflows on a narrow phone', (tester) async {
      await _pumpScreen(tester, size: const Size(320, 1600));
      expect(tester.takeException(), isNull);
    });
  });
}
