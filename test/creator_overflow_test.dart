import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/repo/event_repo.dart';
import 'package:test_app/features/creator/repo/livestream_repo.dart';
import 'package:test_app/features/creator/repo/media_upload_repo.dart';
import 'package:test_app/features/creator/repo/post_repo.dart';
import 'package:test_app/features/creator/views/go_live_setup_screen.dart';
import 'package:test_app/features/creator/views/new_article_screen.dart';
import 'package:test_app/features/creator/views/new_event_screen.dart';
import 'package:test_app/features/creator/views/new_media_screen.dart';
import 'package:test_app/features/creator/views/studio_content_detail_screen.dart';
import 'package:test_app/features/creator/views/widgets/studio_content_parts.dart';
import 'package:test_app/models/creator_models/studio_content_models.dart';
import 'package:test_app/features/creator/views/widgets/go_live_sheet.dart';
import 'package:test_app/features/creator/views/widgets/live_broadcast_parts.dart';
import 'package:test_app/features/creator/views/widgets/new_media_parts.dart';
import 'package:test_app/models/creator_models/livestream_models.dart';
import 'package:test_app/models/creator_models/media_upload_models.dart';
import 'package:test_app/shared/services/api_service.dart';
import 'helpers/load_app_fonts.dart';

/// Every screen the creator studio gained, drawn at the sizes real phones
/// come in and at the text size readers actually set.
///
/// A `RenderFlex overflowed` is reported as a caught exception rather than a
/// failure, so a screen can look fine in one viewport and be broken in
/// another without anything noticing. These pump each one and insist there
/// was no exception at all.
///
/// The sizes are real: a small Android phone, an iPhone 14/15, and a large
/// phone. 1.3 is roughly iOS "Large"; Android goes further still.
const _sizes = <(String, Size)>[
  ('small phone', Size(320, 568)),
  ('iPhone 14', Size(390, 844)),
  ('large phone', Size(430, 932)),
];

const _textScales = <double>[1.0, 1.3];

class _FakeApi implements ApiService {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    data:
        const {
              'data': {
                'data': [
                  {'slug': 'sermons', 'name': 'Sermons'},
                ],
              },
            }
            as T,
  );

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    data:
        const {
              'data': {'id': 'x'},
            }
            as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Pumps [build] at every size and text scale and insists nothing overflowed.
Future<void> _sweep(
  WidgetTester tester,
  String what,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? after,
  bool keyboard = false,
}) async {
  for (final (name, size) in _sizes) {
    for (final scale in _textScales) {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              // A form with a bottom action bar and the keyboard up is
              // where a column runs out of room.
              viewInsets: keyboard
                  ? EdgeInsets.only(bottom: size.height * 0.45)
                  : EdgeInsets.zero,
            ),
            child: MaterialApp(home: build()),
          ),
        ),
      );
      await tester.pump();
      if (after != null) await after(tester);

      expect(
        tester.takeException(),
        isNull,
        reason:
            '$what at $name (${size.width}x${size.height}), text ×$scale'
            '${keyboard ? ', keyboard up' : ''}',
      );
    }
  }
}

LivestreamStudio _studio({String currency = 'NGN', int gross = 1800000}) =>
    LivestreamStudio.fromJson({
      'session': {
        'livestreamRuntimeStatus': 'live',
        'engagementLikeCount': 512,
      },
      'presence': {'viewerCount': 18400, 'peakViewerCount': 18400},
      'connection': const <String, dynamic>{},
      'metrics': {
        'giving': {
          'settlementTotals': [
            {'currency': currency, 'provisionalGrossMinor': gross},
          ],
        },
        'prayers': {'count': 12},
      },
    });

/// Drags the form until [target] has been built, or gives up.
///
/// `scrollUntilVisible` needs a single Scrollable, and these forms have one
/// per text field as well as the list itself, so this walks the list by
/// hand.
Future<bool> _bringIntoView(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 12; i++) {
    if (target.evaluate().isNotEmpty) return true;
    final list = find.byType(ListView);
    if (list.evaluate().isEmpty) return false;
    await tester.drag(list.first, const Offset(0, -260));
    await tester.pump();
  }
  return target.evaluate().isNotEmpty;
}

/// Brings a field into view before typing: on a small phone the fields at
/// the foot of a form have not been built yet.
Future<void> _typeInto(WidgetTester tester, Key key, String text) async {
  final field = find.byKey(key);
  if (!await _bringIntoView(tester, field)) return;
  await tester.enterText(field, text);
  await tester.pump();
}

/// Walks the whole form, so a row below the fold is laid out too.
Future<void> _scrollThrough(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    final list = find.byType(ListView);
    if (list.evaluate().isEmpty) return;
    await tester.drag(list.first, const Offset(0, -300));
    await tester.pump();
  }
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('New video', (tester) async {
    await _sweep(
      tester,
      'New video',
      () => NewMediaScreen(
        kind: MediaUploadKind.video,
        creatorId: 'c1',
        uploads: MediaUploadRepo(_FakeApi()),
        creators: CreatorRepo(api: _FakeApi()),
      ),
    );
  });

  testWidgets('New audio', (tester) async {
    await _sweep(
      tester,
      'New audio',
      () => NewMediaScreen(
        kind: MediaUploadKind.music,
        creatorId: 'c1',
        uploads: MediaUploadRepo(_FakeApi()),
        creators: CreatorRepo(api: _FakeApi()),
      ),
    );
  });

  testWidgets('New event, in every venue shape', (tester) async {
    for (final type in ['physical', 'virtual', 'hybrid']) {
      await _sweep(
        tester,
        'New event ($type)',
        () => NewEventScreen(
          creatorId: 'c1',
          events: EventRepo(_FakeApi()),
          creators: CreatorRepo(api: _FakeApi()),
        ),
        after: (tester) async {
          // On a small phone the cards start below the fold.
          final card = find.byKey(ValueKey('event-type-$type'));
          if (await _bringIntoView(tester, card)) {
            await tester.tap(card);
            await tester.pump();
          }
          // The form grows as the venue type changes; walk the whole thing.
          await _scrollThrough(tester);
        },
      );
    }
  });

  testWidgets('New article, writing and previewing', (tester) async {
    await _sweep(
      tester,
      'New article',
      () => NewArticleScreen(creatorId: 'c1', posts: PostRepo(_FakeApi())),
      after: (tester) async {
        await _typeInto(
          tester,
          const ValueKey('article-title'),
          'Why we still gather, and why it matters more than ever before',
        );
        await _typeInto(
          tester,
          const ValueKey('article-body'),
          '## A heading that runs on\n\n'
          'Fasting clears the table so **prayer can sit down**.\n\n'
          '- Week one: meals until sunset\n'
          '- Week two: screens after nine\n\n'
          '![Draw near](file:abc)\n',
        );
        await tester.tap(find.text('Preview'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await _scrollThrough(tester);
      },
    );
  });

  testWidgets('Go Live setup', (tester) async {
    await _sweep(
      tester,
      'Go Live setup',
      () => GoLiveSetupScreen(
        creatorId: 'c1',
        live: LivestreamRepo(_FakeApi()),
        uploads: MediaUploadRepo(_FakeApi()),
        creators: CreatorRepo(api: _FakeApi()),
      ),
    );
  });

  testWidgets('every form with the keyboard up', (tester) async {
    await _sweep(
      tester,
      'New video, keyboard',
      () => NewMediaScreen(
        kind: MediaUploadKind.video,
        creatorId: 'c1',
        uploads: MediaUploadRepo(_FakeApi()),
        creators: CreatorRepo(api: _FakeApi()),
      ),
      keyboard: true,
    );
    await _sweep(
      tester,
      'New event, keyboard',
      () => NewEventScreen(
        creatorId: 'c1',
        events: EventRepo(_FakeApi()),
        creators: CreatorRepo(api: _FakeApi()),
      ),
      keyboard: true,
    );
    await _sweep(
      tester,
      'New article, keyboard',
      () => NewArticleScreen(creatorId: 'c1', posts: PostRepo(_FakeApi())),
      keyboard: true,
    );
    await _sweep(
      tester,
      'Go Live setup, keyboard',
      () => GoLiveSetupScreen(
        creatorId: 'c1',
        live: LivestreamRepo(_FakeApi()),
        uploads: MediaUploadRepo(_FakeApi()),
        creators: CreatorRepo(api: _FakeApi()),
      ),
      keyboard: true,
    );
  });

  testWidgets('the go-live sheet with the keyboard up', (tester) async {
    await _sweep(
      tester,
      'go-live sheet, keyboard',
      () => Scaffold(body: GoLiveSheet(onChoose: (_) {})),
      keyboard: true,
    );
  });

  testWidgets('the broadcast stat bar, with a long giving total', (
    tester,
  ) async {
    // The row that overflowed by 140 pixels: a currency code plus a big
    // number beside three other pills and the camera flip.
    await _sweep(
      tester,
      'live stat bar',
      () => Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: LiveStatBar(
            likes: 512,
            viewers: 18400,
            giving: givingLabel(_studio()),
            onFlipCamera: () {},
          ),
        ),
      ),
    );
  });

  testWidgets('the broadcast bottom bar', (tester) async {
    await _sweep(
      tester,
      'live bottom bar',
      () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                LiveRoundButton(
                  buttonKey: const ValueKey('mic'),
                  icon: HugeIcons.strokeRoundedMic01,
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                LiveRoundButton(
                  buttonKey: const ValueKey('chat'),
                  icon: HugeIcons.strokeRoundedMessage01,
                  onTap: () {},
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      formatElapsed(const Duration(hours: 3, minutes: 42)),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 90, height: 42),
              ],
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('the end-of-stream sheet', (tester) async {
    await _sweep(
      tester,
      'end sheet',
      () => Scaffold(
        body: EndLivestreamSheet(
          studio: _studio(),
          replayPolicy: ReplayPolicy.autoPublish,
          onKeep: () {},
          onEnd: () {},
        ),
      ),
    );
  });

  testWidgets('the go-live schedule sheet', (tester) async {
    await _sweep(
      tester,
      'go-live sheet',
      () => Scaffold(body: GoLiveSheet(onChoose: (_) {})),
      after: (tester) async {
        await tester.tap(find.byKey(const ValueKey('go-live-later')));
        await tester.pump();
      },
    );
  });

  testWidgets('the Content rows, in every state they can be in', (
    tester,
  ) async {
    final rows = <String, StudioContentItem>{
      'published video': StudioContentItem.fromMedia(const {
        'id': 'v1',
        'type': 'video',
        'title': 'The Prodigal Returns, and the Father Runs to Meet Him',
        'status': 'published',
        'visibility': 'public',
        'analyticsViews': 5180432,
        'durationSeconds': 9045,
        'publishedAt': '2026-01-01T00:00:00.000Z',
      }),
      'failed upload': StudioContentItem.fromMedia(const {
        'id': 'v2',
        'type': 'video',
        'title': 'A failed upload',
        'status': 'failed',
      }),
      'replay': StudioContentItem.fromMedia(const {
        'id': 'v3',
        'type': 'video',
        'title': 'Friday Night Prayer Replay (2026-09-23)',
        'status': 'published',
        'visibility': 'unlisted',
        'endedAt': '2026-09-23T14:31:00.000Z',
        'sourceLivestreamMediaId': 'ls1',
      }),
      'ended stream': StudioContentItem.fromMedia(const {
        'id': 'ls1',
        'type': 'livestream',
        'title': 'Friday Night Prayer',
        'status': 'published',
        'endedAt': '2026-09-23T14:31:00.000Z',
      }),
      'event': StudioContentItem.fromEvent(const {
        'id': 'e1',
        'title': 'Encounter Conference 2026: Three Evenings of Worship',
        'status': 'published',
        'visibility': 'public',
        'attendingCount': 1240,
        'startAt': '2026-10-10T09:00:00.000Z',
      }),
    };

    for (final entry in rows.entries) {
      await _sweep(
        tester,
        'content row (${entry.key})',
        () => Scaffold(
          body: StudioContentRow(
            item: entry.value,
            onTap: () {},
            onAction: () {},
          ),
        ),
      );
    }
  });

  testWidgets('the content detail screen', (tester) async {
    await _sweep(
      tester,
      'content detail',
      () => StudioContentDetailScreen(
        item: StudioContentItem.fromMedia(const {
          'id': 'v1',
          'type': 'video',
          'title': 'The Prodigal Returns, and the Father Runs to Meet Him',
          'status': 'published',
          'visibility': 'public',
          'analyticsViews': 5180432,
          'engagementLikeCount': 86000,
          'engagementCommentCount': 12400,
          'durationSeconds': 9045,
          'categorySlugs': ['bible-study'],
          'publishedAt': '2026-01-01T00:00:00.000Z',
        }),
      ),
      after: _scrollThrough,
    );
  });

  testWidgets('the success card', (tester) async {
    await _sweep(
      tester,
      'published card',
      () => Scaffold(
        body: PublishedCard(
          title: 'Your video is scheduled',
          body: 'It goes live on Sun, Jun 1, 2026 at 6:00 AM.',
          onDone: () {},
        ),
      ),
    );
  });
}
