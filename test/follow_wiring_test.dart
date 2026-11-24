import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `Name(...)` constructor call in [source], with its arguments.
List<String> _callsTo(String name, String source) {
  final calls = <String>[];
  final word = RegExp(r'[A-Za-z0-9_]');
  final needle = '$name(';
  var i = source.indexOf(needle);
  while (i >= 0) {
    if (i == 0 || !word.hasMatch(source[i - 1])) {
      var depth = 0;
      var j = i + name.length;
      while (j < source.length) {
        if (source[j] == '(') depth++;
        if (source[j] == ')') {
          depth--;
          if (depth == 0) {
            j++;
            break;
          }
        }
        j++;
      }
      calls.add(source.substring(i, j));
    }
    i = source.indexOf(needle, i + 1);
  }
  return calls;
}

/// Call sites of [name] under lib/, keyed by file — the declaration itself
/// (which names `super.key`) left out.
Map<String, List<String>> _sitesOf(String name) {
  final found = <String, List<String>>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final calls = _callsTo(
      name,
      entity.readAsStringSync(),
    ).where((c) => !c.contains('super.key')).toList();
    if (calls.isNotEmpty) found[entity.path] = calls;
  }
  return found;
}

void main() {
  /// A control that is always drawn has to always be wired. These widgets
  /// draw their Follow button and their overflow unconditionally, so a call
  /// site that leaves the callback off ships a button that does nothing —
  /// which is exactly what `content_detail_screen` did for every blog, post
  /// and event detail page.
  group('every Follow button drawn is a Follow button wired', () {
    test('DetailCreatorRow is given a follow handler everywhere', () {
      final sites = _sitesOf('DetailCreatorRow');
      expect(sites, isNotEmpty, reason: 'the row moved or was renamed');
      sites.forEach((path, calls) {
        for (final call in calls) {
          expect(
            call.contains('onFollow:'),
            isTrue,
            reason:
                '$path draws DetailCreatorRow with no onFollow, so its '
                'Follow button is inert',
          );
        }
      });
    });

    test('and an overflow handler, since it draws one too', () {
      _sitesOf('DetailCreatorRow').forEach((path, calls) {
        for (final call in calls) {
          expect(
            call.contains('onMore:'),
            isTrue,
            reason: '$path leaves the row\'s "…" with nothing behind it',
          );
        }
      });
    });

    test('and the logo it has room for', () {
      _sitesOf('DetailCreatorRow').forEach((path, calls) {
        for (final call in calls) {
          expect(
            call.contains('avatarUrl:'),
            isTrue,
            reason: '$path draws the creator with no picture',
          );
        }
      });
    });

    test('the channel header reads its own keys', () {
      // The header resolves both itself from `profile`, so the guard is on
      // the header rather than on its call sites.
      final source = File(
        'lib/features/creator/views/widgets/creator_profile_parts.dart',
      ).readAsStringSync();
      expect(source, contains('AssetUrlResolver.resolve(profile.avatarKey)'));
      expect(source, contains('AssetUrlResolver.resolve(profile.bannerKey)'));
      // The claim this replaced.
      expect(source, isNot(contains('has no resolvable URL')));
    });
  });

  group('a follow made anywhere is a follow everywhere', () {
    /// `EngagementStore` is what every surface reads for follow state. A
    /// screen that writes the follow route directly has to tell the store,
    /// or the feed, Explore and search keep offering Follow for a ministry
    /// the reader has just followed.
    const writesDirectly = {
      'lib/features/home/views/home_feed_screen.dart': 'setFollowing(',
      'lib/features/subscriptions/views/manage_following_screen.dart':
          '_repo.follow(',
    };

    writesDirectly.forEach((path, write) {
      test('${path.split('/').last} adopts what it wrote', () {
        final source = File(path).readAsStringSync();
        expect(source, contains(write), reason: 'the write moved');
        expect(
          source,
          contains('adoptFollowing('),
          reason:
              '$path posts a follow without telling EngagementStore, so '
              'every other surface stays stale for the rest of the session',
        );
      });
    });

    test('unfollowing from the list already did, and still does', () {
      final source = File(
        'lib/features/subscriptions/views/manage_following_screen.dart',
      ).readAsStringSync();
      // Two adopts, not one: following a suggestion used to be the half
      // that was missing.
      expect(_callsTo('adoptFollowing', source).length, 2);
    });
  });

  group(
    'a follow is never posted without an account, or without a baseline',
    () {
      /// `toggleFollow` flips whatever the store currently holds, and
      /// `isFollowing` is what the control draws. Both take the same optional
      /// `fallback` — the row's own flag, for a creator the store has never
      /// seen — and the two have to agree about it.
      ///
      /// Explore is why this is a test. Its card read the store *with* the
      /// row's flag while its toggle passed none, so a ministry the row said
      /// was followed read as unfollowed to the write: the tick stayed, a
      /// second follow went out, and there was no way to unfollow from that
      /// rail at all. Reading and writing from the store alone is fine — the
      /// swipe feed does exactly that, and seeds it — so long as neither side
      /// claims a baseline the other ignores.
      test('a follow control reads and writes the same baseline', () {
        final offenders = <String>[];
        for (final entity in Directory('lib').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = entity.readAsStringSync();
          final writes = _callsTo('toggleFollow', source);
          if (writes.isEmpty) continue;
          final reads = _callsTo('isFollowing', source);
          final readsBaseline = reads.any((c) => c.contains('fallback:'));
          final writesBaseline = writes.every((c) => c.contains('fallback:'));
          if (readsBaseline && !writesBaseline) {
            offenders.add(
              '${entity.path}: the control reads the row own follow flag but '
              'the toggle does not, so the two disagree',
            );
          }
        }
        expect(offenders, isEmpty);
      });

      test('and Explore seeds the rail it draws', () {
        // Belt as well as braces: the cards read the store, so it has to be
        // told what the rows said before anyone taps one.
        final source = File(
          'lib/features/explore/views/explore_screen.dart',
        ).readAsStringSync();
        expect(source, contains('seedFollowing('));
      });

      test('and every screen that offers one gates it on a session', () {
        // A signed-out tap otherwise flips the control, posts a 401 and
        // rolls back, with nothing on screen to explain any of it.
        const offerFollow = {
          'lib/features/discovery/views/media_detail_screen.dart',
          'lib/features/discovery/views/content_detail_screen.dart',
          'lib/features/creator/views/creator_profile_screen.dart',
          'lib/features/explore/views/explore_screen.dart',
          'lib/features/home/views/home_feed_screen.dart',
        };
        for (final path in offerFollow) {
          final source = File(path).readAsStringSync();
          expect(
            source,
            contains("_requireAccount('follow creators')"),
            reason: '$path offers Follow without asking for a session first',
          );
        }
      });
    },
  );
}
