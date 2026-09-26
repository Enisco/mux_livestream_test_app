import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/discovery/views/vertical_feed_screen.dart';

/// Swiping into the short-video feed from something already being watched.
///
/// The feed existed but nothing opened it. The point of the entry points is
/// continuity: opening it from a video has to *start on that video*, and
/// opening it from a ministry's library has to play that ministry. The
/// vertical-feed route treats `anchorMediaId` as a relevance hint, not a
/// position — on staging the anchor came back third — so the screen puts it
/// first itself.
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
}
