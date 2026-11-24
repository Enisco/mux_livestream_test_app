import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/creator_profile_parts.dart';
import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/landing/views/widgets/gtube_nav_bar.dart';
import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/components/app_icons.dart';
import 'package:test_app/shared/components/design_icon.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'helpers/load_app_fonts.dart';

const _cdn = 'https://cdn.example.test';

Future<void> _pump(WidgetTester tester, Widget child, {Size? size}) async {
  tester.view.physicalSize = (size ?? const Size(390, 1400)) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => MaterialApp(
        home: Material(child: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
}

CreatorProfile _profile({String? avatarKey, String? bannerKey}) =>
    CreatorProfile(
      id: 'c1',
      displayName: 'Living Faith',
      handle: 'livingfaith',
      avatarKey: avatarKey,
      bannerKey: bannerKey,
      type: 'organization',
      subscriberCount: 1200,
    );

/// Every `Image.network` on screen, by URL.
List<String> _networkImages(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((i) => i.image)
    .whereType<NetworkImage>()
    .map((p) => p.url)
    .toList();

void main() {
  _navBarTests();
  setUpAll(loadAppFonts);
  setUp(() => dotenv.testLoad(fileInput: 'CDN_BASE_URL=$_cdn'));

  group('an avatar shows the picture, and the initial when it cannot', () {
    testWidgets('no URL draws the initial', (tester) async {
      await _pump(tester, const DetailAvatar(name: 'Living Faith'));

      expect(find.text('L'), findsOneWidget);
      expect(_networkImages(tester), isEmpty);
    });

    testWidgets('a URL draws the picture', (tester) async {
      await _pump(
        tester,
        const DetailAvatar(name: 'Living Faith', avatarUrl: '$_cdn/a.png'),
      );

      expect(_networkImages(tester), ['$_cdn/a.png']);
    });

    testWidgets('and a picture that will not load falls back to the initial', (
      tester,
    ) async {
      // The bug this guards: the picture used to be a `DecorationImage`,
      // which has no error hook, and the initial was dropped whenever a URL
      // was present — so a key that 404s left a blank disc for good.
      await _pump(
        tester,
        const DetailAvatar(name: 'Living Faith', avatarUrl: '$_cdn/gone.png'),
      );
      // A widget test's HttpClient refuses every request, so the image is
      // already in its error state by the time this settles.
      await tester.pumpAndSettle();

      expect(find.text('L'), findsOneWidget);
    });

    testWidgets('an empty URL is treated as none at all', (tester) async {
      await _pump(
        tester,
        const DetailAvatar(name: 'Living Faith', avatarUrl: '   '),
      );

      expect(find.text('L'), findsOneWidget);
      expect(_networkImages(tester), isEmpty);
    });
  });

  group("a channel header draws the channel's own cover and logo", () {
    testWidgets('both keys resolve through the CDN', (tester) async {
      await _pump(
        tester,
        CreatorProfileHeader(
          profile: _profile(
            avatarKey: 'public/avatar/c1/logo.png',
            bannerKey: 'public/banner/c1/cover.jpg',
          ),
          busy: false,
        ),
      );

      // Both used to be dropped: the avatar was never passed a URL, and the
      // banner carried a TODO saying `bannerKey` had none — which stopped
      // being true once the studio's own settings screen resolved it.
      expect(
        _networkImages(tester),
        containsAll([
          '$_cdn/public/avatar/c1/logo.png',
          '$_cdn/public/banner/c1/cover.jpg',
        ]),
      );
    });

    testWidgets('and a channel with neither keeps the brand plate', (
      tester,
    ) async {
      await _pump(
        tester,
        CreatorProfileHeader(profile: _profile(), busy: false),
      );

      expect(_networkImages(tester), isEmpty);
      // The gradient is the backdrop either way, so there is never a hole.
      expect(find.byType(DecoratedBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a build with no CDN configured draws no broken image', (
      tester,
    ) async {
      dotenv.testLoad(fileInput: 'NOTHING=1');
      await _pump(
        tester,
        CreatorProfileHeader(
          profile: _profile(
            avatarKey: 'public/avatar/c1/logo.png',
            bannerKey: 'public/banner/c1/cover.jpg',
          ),
          busy: false,
        ),
      );

      expect(_networkImages(tester), isEmpty);
      expect(find.text('L'), findsOneWidget);
    });
  });

  group('the creator row on a detail screen', () {
    testWidgets('its Follow button reports taps', (tester) async {
      var followed = 0;
      await _pump(
        tester,
        DetailCreatorRow(
          name: 'Living Faith',
          subscribersLabel: '1.2K Subscribers',
          onFollow: () => followed++,
        ),
      );

      await tester.tap(find.text(AppStrings.follow));
      expect(followed, 1);
    });

    testWidgets('and its overflow reports taps', (tester) async {
      var more = 0;
      await _pump(
        tester,
        DetailCreatorRow(
          name: 'Living Faith',
          subscribersLabel: '1.2K Subscribers',
          onMore: () => more++,
        ),
      );

      await tester.tap(find.byType(DesignIcon).last);
      expect(more, 1);
    });

    testWidgets('it says Following once the reader does', (tester) async {
      await _pump(
        tester,
        const DetailCreatorRow(
          name: 'Living Faith',
          subscribersLabel: '1.2K Subscribers',
          following: true,
        ),
      );

      expect(find.text(AppStrings.followingLabel), findsOneWidget);
      expect(find.text(AppStrings.follow), findsNothing);
    });
  });

  group('a Library section promises more only when there is more', () {
    LibrarySection section({
      required int total,
      required int shown,
      String? cursor,
    }) => LibrarySection(
      key: 'videos',
      title: AppStrings.sectionVideos,
      total: total,
      cursor: cursor,
      items: [
        for (var i = 0; i < shown; i++)
          WebFeedItem(
            entityType: 'media',
            entityId: 'm\$i',
            title: 'Row \$i',
            meta: const WebFeedItemMeta(),
          ),
      ],
    );

    testWidgets('a complete section draws no chevron', (tester) async {
      // The chevron used to be drawn on every heading with nothing behind
      // it — a promise of more over a section that was already all there.
      await _pump(
        tester,
        CreatorLibraryTab(
          sections: [section(total: 3, shown: 3)],
          onOpen: (_) {},
          onSeeAll: (_) {},
        ),
      );

      expect(find.byIcon(AppIcons.chevronRight), findsNothing);
    });

    testWidgets('a truncated one does, and reports the tap', (tester) async {
      LibrarySection? asked;
      await _pump(
        tester,
        CreatorLibraryTab(
          sections: [section(total: 40, shown: 16, cursor: 'next')],
          onOpen: (_) {},
          onSeeAll: (s) => asked = s,
        ),
      );

      expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.chevronRight));
      expect(asked?.key, 'videos');
    });

    testWidgets('a full page with no cursor is not a promise of more', (
      tester,
    ) async {
      // `total` is the only thing that knows. A page that happens to be
      // full says nothing about a next one, and the server reports no
      // cursor when there is none.
      await _pump(
        tester,
        CreatorLibraryTab(
          sections: [section(total: 40, shown: 16)],
          onOpen: (_) {},
          onSeeAll: (_) {},
        ),
      );

      expect(find.byIcon(AppIcons.chevronRight), findsNothing);
    });

    testWidgets(
      'the section being fetched shows that, and refuses a second tap',
      (tester) async {
        var taps = 0;
        await _pump(
          tester,
          CreatorLibraryTab(
            sections: [section(total: 40, shown: 16, cursor: 'next')],
            onOpen: (_) {},
            onSeeAll: (_) => taps++,
            expanding: 'videos',
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(AppIcons.chevronRight), findsNothing);
        await tester.tap(find.text(AppStrings.sectionVideos));
        expect(taps, 0);
      },
    );
  });
}

/// The bottom bar's You tab, which had taken an `avatarUrl` all along while
/// its only call site passed none.
void _navBarTests() {
  group('the You tab draws the reader', () {
    testWidgets('its own face when there is one', (tester) async {
      await _pump(
        tester,
        GTubeNavBar(index: 3, onChanged: (_) {}, avatarUrl: '$_cdn/me.png'),
      );
      expect(_networkImages(tester), contains('$_cdn/me.png'));
    });

    testWidgets('and the ring it always drew when there is not', (
      tester,
    ) async {
      await _pump(tester, GTubeNavBar(index: 3, onChanged: (_) {}));
      expect(_networkImages(tester), isEmpty);
    });

    testWidgets('and falls back to the ring when the photo will not load', (
      tester,
    ) async {
      // The bar drew a `DecorationImage`, which has no error hook, and
      // dropped the icon whenever a URL was present — so a stale key left
      // the tab as a bare circle with nothing in it.
      await _pump(
        tester,
        GTubeNavBar(index: 3, onChanged: (_) {}, avatarUrl: '$_cdn/gone.png'),
      );
      // A widget test's HttpClient refuses every request, so the image is
      // already in its error state by the time this settles.
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    test('and the shell passes the key the profile header resolves', () {
      // A source guard because the shell cannot be mounted without the
      // whole locator: it builds four tabs, each with its own repo.
      final source = File(
        'lib/features/landing/views/main_shell.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('AssetUrlResolver.resolve(LocalStorage.cachedAvatarKey)'),
      );
    });
  });
}
