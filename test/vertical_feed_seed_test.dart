import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/discovery/views/vertical_feed_screen.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';

/// Swiping into the short-video feed from something already being watched.
void main() {
  group('a seeded open is not the general feed', () {
    test('an anchored media counts as seeded', () {
      expect(const VerticalFeedScreen(anchorMediaId: 'm1').isSeeded, isTrue);
    });

    test("so does a ministry's library", () {
      expect(const VerticalFeedScreen(anchorCreatorId: 'c1').isSeeded, isTrue);
    });

    test('so does a list of what was on screen', () {
      expect(
        const VerticalFeedScreen(prioritizeMediaIds: ['m1']).isSeeded,
        isTrue,
      );
    });

    test(
      'and an unseeded open is the general feed, which may use warm data',
      () {
        expect(const VerticalFeedScreen().isSeeded, isFalse);
      },
    );
  });

  group('the anchor leads', () {
    test('it is moved to the front when the API buries it', () {
      final ordered = VerticalFeedOrdering.anchorFirst(const [
        'a',
        'b',
        'anchor',
        'c',
      ], 'anchor');
      expect(ordered, ['anchor', 'a', 'b', 'c']);
    });

    test('an anchor already leading is left alone', () {
      final ordered = VerticalFeedOrdering.anchorFirst(const [
        'anchor',
        'a',
        'b',
      ], 'anchor');
      expect(ordered, ['anchor', 'a', 'b']);
    });

    test('an anchor the feed did not return changes nothing', () {
      final ordered = VerticalFeedOrdering.anchorFirst(const [
        'a',
        'b',
      ], 'missing');
      expect(ordered, ['a', 'b']);
    });

    test('no anchor changes nothing', () {
      expect(VerticalFeedOrdering.anchorFirst(const ['a', 'b'], null), [
        'a',
        'b',
      ]);
      expect(VerticalFeedOrdering.anchorFirst(const ['a', 'b'], ''), [
        'a',
        'b',
      ]);
    });

    test('the anchor is never duplicated', () {
      final ordered = VerticalFeedOrdering.anchorFirst(const [
        'a',
        'anchor',
        'b',
        'anchor',
      ], 'anchor');
      expect(ordered, ['anchor', 'a', 'b']);
      expect(ordered.where((id) => id == 'anchor'), hasLength(1));
    });
  });

  /// Unwired 2026-11-26. `POST /v1/discovery/vertical-feed` filters by
  /// neither duration nor orientation — its pools are subscriptions,
  /// more-from-this-creator and a broad popularity browse — so the
  /// screen cannot honour a promise of short or upright video. It stays
  /// reachable from a ministry's own library, which promises neither.
  group('what may open the swipe feed', () {
    test('a video page does not offer it', () {
      final source = File(
        'lib/features/discovery/views/media_detail_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        isNot(contains('VerticalFeedScreen')),
        reason:
            'Up next offers a swipe-through again, and what it serves is '
            'ordinary long-form video',
      );
    });

    test('a ministry library still does', () {
      // The entry that was kept: it says nothing about length.
      final source = File(
        'lib/features/creator/views/creator_profile_screen.dart',
      ).readAsStringSync();

      expect(source, contains('VerticalFeedScreen'));
    });

    test('and the heading claims nothing it cannot keep', () {
      expect(AppStrings.swipeFeedTitle.toLowerCase(), isNot(contains('short')));
    });
  });
}
