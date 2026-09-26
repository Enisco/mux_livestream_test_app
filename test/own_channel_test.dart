import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/creator/views/widgets/creator_profile_parts.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/features/home/views/widgets/feed_card.dart';
import 'package:test_app/models/creator_models/creator_profile.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/services/viewer_identity.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/helpers/local_storage.dart';
import 'helpers/load_app_fonts.dart';

/// Your own channel, seen from the viewer side.
///
/// Reported from the app: opening "Food for Thought" — the reader's own
/// ministry — from the You tab showed the public profile offering **Follow**,
/// **Give Now** and **Subscribe/follow**. You cannot follow or give to
/// yourself, and the API refuses both, so those were dead ends dressed as
/// invitations.
///
/// Ownership is answered in one place, from two sources: `isOwnedByViewer`
/// where discovery sends it, and the cached creator id for the routes that do
/// not — `GET /v1/creator/handle/{handle}` being the one behind the screen
/// that was wrong.
const _mine = 'c-mine';
const _theirs = 'c-theirs';

CreatorProfile _profile(String id) => CreatorProfile.fromJson({
  'data': {
    'creator': {
      'id': id,
      'displayName': 'Food for Thought',
      'handle': 'foodforthought',
      'bio': 'A Christian channel.',
      'subscriberCount': 0,
    },
  },
});

Future<void> _pumpHeader(
  WidgetTester tester,
  CreatorProfile profile, {
  VoidCallback? onOpenStudio,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      respectSystemFontScale: false,
      builder: (context) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CreatorProfileHeader(
              profile: profile,
              busy: false,
              onFollow: () {},
              onGive: () {},
              onOpenStudio: onOpenStudio,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setString(LocalStorage.creatorIdKey, _mine);
  });

  group('knowing whose channel it is', () {
    test('the cached channel is mine', () {
      expect(ViewerIdentity.owns(_mine), isTrue);
      expect(ViewerIdentity.owns(_theirs), isFalse);
    });

    test("the API's flag wins, because a team member's id is not cached", () {
      // Someone who belongs to an organisation's channel without it being
      // the one cached against their account.
      expect(ViewerIdentity.owns(_theirs, flaggedByApi: true), isTrue);
    });

    test('a reader with no channel owns nothing', () async {
      await LocalStorage.remove(LocalStorage.creatorIdKey);
      expect(ViewerIdentity.owns(_mine), isFalse);
      expect(ViewerIdentity.owns(null), isFalse);
      expect(ViewerIdentity.owns(''), isFalse);
    });

    test('an unreadable store answers "not mine" rather than throwing', () {
      // Mapping a feed row happens in plenty of places that never init
      // LocalStorage, and whose row it is never justifies an exception.
      expect(() => ViewerIdentity.owns(_mine), returnsNormally);
    });
  });

  group('the profile header', () {
    testWidgets('someone else is offered Follow and Give Now', (tester) async {
      await _pumpHeader(tester, _profile(_theirs));
      expect(find.text(AppStrings.follow), findsOneWidget);
      expect(find.text(AppStrings.giveNow), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-open-own-studio')),
        findsNothing,
      );
    });

    testWidgets('my own channel is offered neither', (tester) async {
      await _pumpHeader(tester, _profile(_mine));
      expect(find.text(AppStrings.follow), findsNothing);
      expect(find.text(AppStrings.unfollow), findsNothing);
      expect(find.text(AppStrings.giveNow), findsNothing);
    });

    testWidgets('it offers the studio instead, and it works', (tester) async {
      var opened = false;
      await _pumpHeader(
        tester,
        _profile(_mine),
        onOpenStudio: () => opened = true,
      );
      expect(
        find.byKey(const ValueKey('profile-open-own-studio')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('profile-open-own-studio')));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });
  });

  group('an empty tab on my own channel', () {
    testWidgets("does not invite me to subscribe to myself", (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          respectSystemFontScale: false,
          builder: (context) => const MaterialApp(
            home: Scaffold(
              body: CreatorTabEmptyState(tab: CreatorTab.latest, owned: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.subscribeFollow), findsNothing);
      expect(find.byKey(const ValueKey('tab-empty-action')), findsNothing);
      // The empty state itself still reads.
      expect(find.text(CreatorTab.latest.emptyTitle), findsOneWidget);
    });

    testWidgets('but still invites me on somebody else\'s', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SizingBuilder(
          baseSize: const Size(390, 844),
          respectSystemFontScale: false,
          builder: (context) => const MaterialApp(
            home: Scaffold(body: CreatorTabEmptyState(tab: CreatorTab.latest)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tab-empty-action')), findsOneWidget);
    });
  });

  group('feed rows know whose they are', () {
    WebFeedItem item(
      String entityType, {
      bool flagged = false,
      String? creatorId,
    }) => WebFeedItem.fromJson({
      'entityType': entityType,
      'entityId': entityType == 'creator' ? (creatorId ?? _mine) : 'e1',
      'title': 'A title',
      'meta': <String, dynamic>{},
      'facets': <String, dynamic>{},
      'isOwnedByViewer': flagged,
      if (entityType != 'creator')
        'creator': {
          'creatorId': creatorId ?? _mine,
          'displayName': 'Food for Thought',
          'handle': 'foodforthought',
        },
    });

    test('my own post is mine', () {
      expect(FeedCardMapper.toCardData(item('media')).mine, isTrue);
    });

    test("somebody else's is not", () {
      expect(
        FeedCardMapper.toCardData(item('media', creatorId: _theirs)).mine,
        isFalse,
      );
    });

    test('a channel row uses its own id, not a nested creator', () {
      // A `creator` row has no nested creator object — its identity is the
      // row itself, which is exactly what the old mapping got wrong before.
      final card = FeedCardMapper.toCardData(item('creator'));
      expect(card.kind, FeedCardKind.channel);
      expect(card.mine, isTrue);
    });

    test("and the API's flag is honoured on a row I do not have cached", () {
      final card = FeedCardMapper.toCardData(
        item('media', creatorId: _theirs, flagged: true),
      );
      expect(card.mine, isTrue);
    });
  });
}
