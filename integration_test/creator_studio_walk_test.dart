import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/features/auth/repo/auth_repo.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/creator/views/go_live_setup_screen.dart';
import 'package:test_app/features/creator/views/new_article_screen.dart';
import 'package:test_app/features/creator/views/new_event_screen.dart';
import 'package:test_app/features/creator/views/new_media_screen.dart';
import 'package:test_app/features/creator/views/studio_shell.dart';
import 'package:test_app/features/creator/views/widgets/go_live_sheet.dart';
import 'package:test_app/features/creator/views/widgets/studio_sheets.dart';
import 'package:test_app/shared/components/primary_button.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_theme.dart';
import 'package:test_app/utils/helpers/local_storage.dart';

/// Walks the creator studio on a device against the real staging API.
///
/// The widget tests build each screen in isolation; this is what proves the
/// tabs, the Create sheet and the routes between them actually join up, with
/// a real channel behind them.
///
///   `flutter test integration_test/creator_studio_walk_test.dart -d DEVICE`
///
/// It registers a throwaway staging account per run. Those accumulate; clean
/// them up when you are done.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  var chosen = false;

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await setupLocator();
  });

  /// A signed-in creator with a real channel behind them.
  Future<void> signInWithChannel() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'gt.studio.$stamp@mail.com';
    await getIt<AuthRepo>().register(
      firstName: 'Pastor',
      lastName: 'James',
      email: email,
      password: 'ProbePass123!',
    );
    await getIt<AuthRepo>().login(email: email, password: 'ProbePass123!');
    await LocalStorage.remove(LocalStorage.creatorIdKey);
    await CreatorRepo().saveCreatorProfile(
      handle: 'studio$stamp',
      displayName: 'Grace Chapel',
      type: 'individual',
      categorySlugs: const ['sermons'],
    );
  }

  /// These tests share one binding, so a previous test's pushed routes can
  /// still be in the overlay when the next one pumps — the tap then lands
  /// on a route that is on its way out. Clearing the tree first and letting
  /// it settle tears them down deterministically.
  Future<void> clearTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> pumpStudio(WidgetTester tester) async {
    await clearTree(tester);
    await tester.pumpWidget(
      SizingBuilder(
        baseSize: const Size(390, 844),
        respectSystemFontScale: false,
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const StudioShell(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 10));
  }

  testWidgets('the Content tab opens New video from + Create', (tester) async {
    await signInWithChannel();
    await pumpStudio(tester);

    await tester.tap(find.byKey(const ValueKey('studio-tab-1')));
    await tester.pumpAndSettle(const Duration(seconds: 10));

    await tester.tap(find.byKey(const ValueKey('content-create')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('create-video')));
    await tester.pumpAndSettle();

    expect(find.byType(NewMediaScreen), findsOneWidget);
    expect(find.text(AppStrings.newVideoSubtitle), findsOneWidget);

    // Nothing can be published before a file, a thumbnail and the two
    // required lines are there.
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('media-publish')))
          .enabled,
      isFalse,
    );
  });

  testWidgets('+ Create opens New audio, with audio\'s own terms', (
    tester,
  ) async {
    await signInWithChannel();
    await pumpStudio(tester);

    await tester.tap(find.byKey(const ValueKey('studio-tab-1')));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await tester.tap(find.byKey(const ValueKey('content-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-audio')));
    await tester.pumpAndSettle();

    expect(find.byType(NewMediaScreen), findsOneWidget);
    expect(find.text(AppStrings.newAudioTitle), findsOneWidget);
    // 1 GB and MP3/M4A/WAV, not the video frame's copy that the design
    // repeats here.
    expect(find.text(AppStrings.newAudioPickHint), findsOneWidget);
    expect(find.text(AppStrings.newVideoPickHint), findsNothing);
  });

  testWidgets('+ Create opens New event, which uploads nothing', (
    tester,
  ) async {
    await signInWithChannel();
    await pumpStudio(tester);

    await tester.tap(find.byKey(const ValueKey('studio-tab-1')));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await tester.tap(find.byKey(const ValueKey('content-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-event')));
    await tester.pumpAndSettle();

    expect(find.byType(NewEventScreen), findsOneWidget);
    expect(find.text(AppStrings.newEventTitle), findsOneWidget);
    // An event is filed, not uploaded: there is no file to select.
    expect(find.byKey(const ValueKey('media-select')), findsNothing);
    // And nothing can be published until the API would take it.
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('event-publish')))
          .enabled,
      isFalse,
    );
  });

  testWidgets('+ Create opens New article, which writes rather than uploads', (
    tester,
  ) async {
    await signInWithChannel();
    await pumpStudio(tester);

    await tester.tap(find.byKey(const ValueKey('studio-tab-1')));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await tester.tap(find.byKey(const ValueKey('content-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-blog')));
    await tester.pumpAndSettle();

    expect(find.byType(NewArticleScreen), findsOneWidget);
    expect(find.text(AppStrings.newArticleTitle), findsOneWidget);
    // Markdown, not a file: a toolbar rather than a picker.
    expect(find.byKey(const ValueKey('article-tool-bold')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-select')), findsNothing);
  });

  testWidgets('+ Create opens Go Live, which opens no picker', (tester) async {
    await signInWithChannel();
    await pumpStudio(tester);

    await tester.tap(find.byKey(const ValueKey('studio-tab-1')));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await tester.tap(find.byKey(const ValueKey('content-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-livestream')));
    await tester.pumpAndSettle();

    expect(find.byType(GoLiveSetupScreen), findsOneWidget);
    expect(find.text(AppStrings.goLiveStart), findsOneWidget);
    // Nothing is uploaded to go live, and the camera is not opened until
    // the next screen.
    expect(find.byKey(const ValueKey('media-select')), findsNothing);
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('live-start')))
          .enabled,
      isFalse,
    );
  });

  testWidgets('Go live is offered separately from a video upload', (
    tester,
  ) async {
    await signInWithChannel();
    await pumpStudio(tester);

    await tester.tap(find.byKey(const ValueKey('studio-tab-1')));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await tester.tap(find.byKey(const ValueKey('content-create')));
    await tester.pumpAndSettle();

    // Two different things, two different rows — and only one of them is
    // an upload.
    expect(find.byKey(const ValueKey('create-video')), findsOneWidget);
    expect(find.byKey(const ValueKey('create-livestream')), findsOneWidget);
    expect(find.text(CreateKind.livestream.title), findsOneWidget);
    expect(find.text(CreateKind.video.title), findsOneWidget);
    // Audio is a third thing again: same upload route as video, different
    // ceiling and containers.
    expect(find.byKey(const ValueKey('create-audio')), findsOneWidget);
  });

  testWidgets('the Studio tab opens New video from Quick upload', (
    tester,
  ) async {
    await signInWithChannel();
    await pumpStudio(tester);

    await tester.tap(find.text(AppStrings.studioQuickUpload));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-video')));
    await tester.pumpAndSettle();

    expect(find.byType(NewMediaScreen), findsOneWidget);
  });

  testWidgets('the schedule sheet will not take a moment already gone', (
    tester,
  ) async {
    await clearTree(tester);
    await tester.pumpWidget(
      SizingBuilder(
        baseSize: const Size(390, 844),
        respectSystemFontScale: false,
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            body: GoLiveSheet(
              onChoose: (_) => chosen = true,
              // What lingering on the sheet past the chosen hour leaves.
              initialAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('go-live-later')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('go-live-confirm')));
    await tester.pumpAndSettle();

    // `POST /v1/media` answers "scheduledAt must be in the future", and by
    // then the whole file has been uploaded — so it is caught here instead.
    expect(find.text(AppStrings.goLivePastMoment), findsOneWidget);
    expect(chosen, isFalse);
  });
}
