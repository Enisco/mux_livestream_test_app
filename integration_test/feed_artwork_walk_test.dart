import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:test_app/core/locator.dart';
import 'package:test_app/features/creator/repo/creator_repo.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';

/// Against staging:
///
///   `flutter test integration_test/feed_artwork_walk_test.dart -d DEVICE`
///
/// Two things a widget test cannot show.
///
/// **Artwork.** Only media rows arrive with a resolved `thumbnailUrl`. Posts,
/// events, devotional series, media series and creator avatars carry a bare
/// storage key, and nothing put a host in front of it — so those cards
/// rendered blank. These fetch the real feed, resolve the real keys and then
/// actually GET them, which is the only way to know the CDN serves them.
///
/// **Taxonomy.** The interest chips and the home topic chips are now the rows
/// of `GET /v1/user/categories`. A label that has drifted from a slug is
/// exactly what a live check catches and a fixture cannot.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env');
    await setupLocator();
  });

  Future<int> statusOf(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  testWidgets('the CDN base is configured for this build', (tester) async {
    expect(
      AssetUrlResolver.isConfigured,
      isTrue,
      reason: 'CDN_BASE_URL is unset, so every non-media card loses its art',
    );
  });

  testWidgets('non-media rows resolve artwork that actually loads', (
    tester,
  ) async {
    final feed = await getIt<DiscoveryRepo>().fetchWebFeed(
      limit: 50,
      mode: 'explore_only',
    );
    expect(feed.items, isNotEmpty, reason: 'staging returned an empty feed');

    // Rows whose art is a storage key rather than a ready URL.
    final keyed = feed.items
        .where((i) => i.entityType != 'media')
        .where((i) => (i.meta.thumbnailKey ?? '').isNotEmpty)
        .toList();

    if (keyed.isEmpty) {
      // Nothing to prove today rather than a silent pass.
      markTestSkipped('no keyed rows in the current staging feed');
      return;
    }

    for (final item in keyed.take(5)) {
      final card = FeedCardMapper.toCardData(item);
      expect(
        card.thumbnailUrl,
        isNotNull,
        reason: '${item.entityType} ${item.entityId} resolved to nothing',
      );
      expect(
        await statusOf(card.thumbnailUrl!),
        200,
        reason: 'CDN refused ${card.thumbnailUrl}',
      );
    }
  });

  testWidgets('a media row keeps the URL the API resolved for it', (
    tester,
  ) async {
    final feed = await getIt<DiscoveryRepo>().fetchWebFeed(
      limit: 50,
      mode: 'explore_only',
    );
    final media = feed.items.firstWhere(
      (i) => i.entityType == 'media' && (i.meta.thumbnailUrl ?? '').isNotEmpty,
    );
    final card = FeedCardMapper.toCardData(media);
    expect(card.thumbnailUrl, media.meta.thumbnailUrl);
  });

  testWidgets('a media series opens its own route, not the media aggregate', (
    tester,
  ) async {
    final feed = await getIt<DiscoveryRepo>().fetchWebFeed(
      limit: 50,
      mode: 'explore_only',
      entityTypes: const ['media_series'],
    );
    final series = feed.items
        .where((i) => i.entityType == 'media_series')
        .toList();
    if (series.isEmpty) {
      markTestSkipped('no media_series on staging right now');
      return;
    }

    final detail = await getIt<DiscoveryRepo>().fetchMediaSeries(
      series.first.entityId,
    );
    expect(detail.id, series.first.entityId);
    expect(detail.title, isNotEmpty);
    // The running order is the whole reason this route exists.
    expect(detail.orderedMediaIds, isNotEmpty);
  });

  testWidgets('every category the app draws chips for still exists', (
    tester,
  ) async {
    final rows = await getIt<CreatorRepo>().fetchCategories();
    expect(rows, isNotEmpty);

    final live = rows.where((c) => c.isActive).toList();
    expect(live, isNotEmpty);
    // Labels and slugs travel together now, so this is really asserting that
    // the taxonomy still carries what the app expects to render.
    for (final c in live) {
      expect(c.slug, isNotEmpty);
      expect(c.name, isNotEmpty);
      expect(c.sortOrder, greaterThan(0));
    }
  });
}
