import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/features/library/data/playlist_dummy_data.dart';
import 'package:test_app/features/library/views/playlist_add_screen.dart';
import 'package:test_app/features/library/views/playlist_detail_screen.dart';
import 'package:test_app/features/library/views/playlist_form_screen.dart';
import 'package:test_app/features/library/views/playlists_screen.dart';
import 'helpers/load_app_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SizingBuilder(
      baseSize: const Size(390, 844),
      builder: (context) => MaterialApp(home: child),
    ),
  );
  await tester.pump();
}

/// Tall enough that the lazy lists build every row at once.
const _tall = Size(390, 3200);

void main() {
  setUpAll(loadAppFonts);

  group('the playlist list', () {
    testWidgets('names every playlist and what is in it', (tester) async {
      await _pump(tester, const PlaylistsScreen(), size: _tall);

      expect(find.text('Playlists'), findsOneWidget);
      expect(find.text('New playlist'), findsOneWidget);
      for (final playlist in PlaylistDummyData.playlists) {
        expect(find.text(playlist.name), findsOneWidget, reason: playlist.name);
      }
      expect(find.text('4 items · Updated 2h ago'), findsNWidgets(3));
      expect(find.text('0 items · Updated just now'), findsOneWidget);
    });

    testWidgets('an empty playlist gets no count badge', (tester) async {
      await _pump(tester, const PlaylistsScreen(), size: _tall);

      // Three filled playlists carry "4 Videos"; the empty one carries none.
      expect(find.text('4 Videos'), findsNWidgets(3));
    });

    testWidgets('search narrows to the matching playlist', (tester) async {
      await _pump(tester, const PlaylistsScreen(), size: _tall);

      await tester.enterText(find.byType(TextField), 'mum');
      await tester.pump();

      expect(find.text('For Mum'), findsOneWidget);
      expect(find.text('Sunday Worship'), findsNothing);
    });

    testWidgets('a query matching nothing says so', (tester) async {
      await _pump(tester, const PlaylistsScreen(), size: _tall);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();

      expect(find.text('Nothing matched'), findsOneWidget);
    });

    testWidgets('the row overflow renames the playlist in place', (
      tester,
    ) async {
      await _pump(tester, const PlaylistsScreen(), size: _tall);

      await tester.tap(find.byKey(const ValueKey('row-more-pl2')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('action-Edit playlist detail')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'For Mum and Dad');
      await tester.pump();
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(find.text('For Mum and Dad'), findsOneWidget);
      expect(find.text('For Mum'), findsNothing);
    });

    testWidgets('the row overflow deletes behind a confirmation', (
      tester,
    ) async {
      await _pump(tester, const PlaylistsScreen(), size: _tall);

      await tester.tap(find.byKey(const ValueKey('row-more-pl2')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('action-Delete this playlist')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('For Mum'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('row-more-pl2')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('action-Delete this playlist')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      expect(find.text('For Mum'), findsNothing);
      expect(find.text('Sunday Worship'), findsOneWidget);
    });

    testWidgets('creating one puts it at the top of the list', (tester) async {
      await _pump(tester, const PlaylistsScreen(), size: _tall);

      await tester.tap(find.text('New playlist'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Road trip');
      await tester.pump();
      await tester.tap(find.text('Create new playlist'));
      await tester.pumpAndSettle();

      expect(find.text('Road trip'), findsOneWidget);
      expect(find.text('0 items · Updated just now'), findsNWidgets(2));
    });
  });

  group('the form', () {
    testWidgets('will not submit an empty name', (tester) async {
      await _pump(tester, const PlaylistFormScreen());

      final before = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Create new playlist'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(before.opacity, lessThan(1));

      await tester.tap(find.text('Create new playlist'));
      await tester.pumpAndSettle();
      // Still on the form: nothing was handed back.
      expect(find.text('New playlist'), findsOneWidget);
    });

    testWidgets('visibility is one choice, not two', (tester) async {
      await _pump(tester, const PlaylistFormScreen());

      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);

      await tester.tap(find.text('Public'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing arrives with the name already in it', (tester) async {
      await _pump(
        tester,
        PlaylistFormScreen(existing: PlaylistDummyData.playlists.first),
      );

      expect(find.text('Edit playlist'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Sunday Worship',
      );
    });
  });

  group('the detail screen', () {
    testWidgets('lists the items and what plays next', (tester) async {
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: PlaylistDummyData.playlists.first),
        size: _tall,
      );

      expect(find.text('Sunday Worship'), findsWidgets);
      expect(find.text('4 Items · 3h 24m'), findsOneWidget);
      expect(find.text('Recommended for you'), findsOneWidget);
      expect(find.text('Edit Cover Photo'), findsOneWidget);
    });

    testWidgets('an empty one says so and still recommends', (tester) async {
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: PlaylistDummyData.playlists.last),
        size: _tall,
      );

      expect(find.text('This playlist is empty'), findsOneWidget);
      expect(find.text('0 items'), findsOneWidget);
      expect(find.text('Recommended for you'), findsOneWidget);
    });

    testWidgets('the overflow offers Play all only when there is one', (
      tester,
    ) async {
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: PlaylistDummyData.playlists.last),
        size: _tall,
      );

      await tester.tap(find.byKey(const ValueKey('playlist-more')));
      await tester.pumpAndSettle();
      // The sheet's own rows; the empty playlist cannot play.
      final playAll = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('Play all'), matching: find.byType(Opacity))
            .first,
      );
      expect(playAll.opacity, lessThan(1));
      expect(find.text('Delete this playlist'), findsOneWidget);
    });

    testWidgets('deleting asks first, then hands the deletion back', (
      tester,
    ) async {
      PlaylistOutcome? outcome;
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              outcome = await Navigator.push<PlaylistOutcome>(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(
                    playlist: PlaylistDummyData.playlists.first,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
        size: _tall,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('playlist-more')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'action-Delete this '
            'playlist',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('will be removed from your'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(outcome, isNull, reason: 'cancel leaves the playlist alone');

      await tester.tap(find.byKey(const ValueKey('playlist-more')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'action-Delete this '
            'playlist',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      expect(outcome?.deleted, isTrue);
    });
  });

  group('a row inside a playlist', () {
    testWidgets('the overflow asks before taking an item out', (tester) async {
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: PlaylistDummyData.playlists.first),
        size: _tall,
      );

      expect(find.text('Romans, chapter'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('more-pi3')));
      await tester.pumpAndSettle();

      // A bare tap on the overflow must not delete anything by itself.
      expect(find.text('Remove from playlist'), findsOneWidget);
      expect(find.byKey(const ValueKey('item-pi3')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('action-Remove from playlist')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('item-pi3')), findsNothing);
    });

    testWidgets('a recommended row offers to join the playlist', (
      tester,
    ) async {
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: PlaylistDummyData.playlists.first),
        size: _tall,
      );

      await tester.tap(find.byKey(const ValueKey('more-pr1')));
      await tester.pumpAndSettle();

      expect(find.text('Add to this playlist'), findsOneWidget);
      expect(find.text('Remove from playlist'), findsNothing);
    });
  });

  group('adding content', () {
    testWidgets('says which playlist it is adding to', (tester) async {
      await _pump(
        tester,
        const PlaylistAddScreen(playlistName: 'Encouragement'),
        size: _tall,
      );

      expect(find.text('Recommended contents'), findsOneWidget);
      expect(
        find.textContaining('Encouragement', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('rows already in the playlist cannot be added again', (
      tester,
    ) async {
      await _pump(
        tester,
        const PlaylistAddScreen(playlistName: 'Encouragement'),
        size: _tall,
      );

      // Two of the four are already in; the other two offer Add.
      expect(find.byKey(const ValueKey('added')), findsNWidgets(2));
      expect(find.text('Add'), findsNWidgets(2));
    });

    testWidgets('picking a row turns it into an added one', (tester) async {
      await _pump(
        tester,
        const PlaylistAddScreen(playlistName: 'Encouragement'),
        size: _tall,
      );

      await tester.tap(find.text('Add').first);
      await tester.pump();

      expect(find.byKey(const ValueKey('added')), findsNWidgets(3));
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('nothing picked means nothing to submit', (tester) async {
      await _pump(
        tester,
        const PlaylistAddScreen(playlistName: 'Encouragement'),
        size: _tall,
      );

      final button = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Add selection'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(button.opacity, lessThan(1));
    });
  });

  group('nothing overflows', () {
    testWidgets('the list on a narrow phone', (tester) async {
      await _pump(tester, const PlaylistsScreen(), size: const Size(320, 3200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the detail screen on a narrow phone', (tester) async {
      await _pump(
        tester,
        PlaylistDetailScreen(playlist: PlaylistDummyData.playlists.first),
        size: const Size(320, 3200),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the form on a short phone', (tester) async {
      await _pump(
        tester,
        const PlaylistFormScreen(),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
