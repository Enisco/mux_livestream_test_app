import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_app/features/onboarding/views/widgets/category_glyphs.dart';
import 'package:test_app/models/creator_models/creator_models.dart';

/// The onboarding chips are the API's taxonomy.
///
/// They used to be the design's own eleven labels. Only six mapped onto a
/// real category, so four chips sent nothing when picked and four categories
/// — `prayer`, `live-services`, `testimonies`, `devotionals` — could not be
/// picked at all. Labels and slugs now come from the same place and cannot
/// drift; the glyph is the one thing the app still supplies, which is what
/// these cover.
///
/// The slug list is `GET /v1/user/categories` on staging, 2026-09-26.
const _taxonomy = <String>[
  'worship',
  'sermons',
  'bible-study',
  'prayer',
  'gospel-music',
  'live-services',
  'testimonies',
  'youth',
  'family',
  'devotionals',
];

void main() {
  test('every category in the taxonomy has a glyph of its own', () {
    final missing = _taxonomy.where((s) => !CategoryGlyphs.hasGlyph(s));
    expect(
      missing,
      isEmpty,
      reason:
          'These would fall back to the globe. Add a glyph, or accept the '
          'fallback deliberately by adding the slug here.',
    );
  });

  testWidgets('each one parses and draws', (tester) async {
    for (final slug in _taxonomy) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: CategoryGlyphs.forSlug(slug))),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'glyph for $slug');
    }
  });

  testWidgets('a category this build has never heard of still gets a chip', (
    tester,
  ) async {
    // The taxonomy is the backend's to grow. A new slug must appear as a
    // chip rather than vanish because the app has no picture for it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: CategoryGlyphs.forSlug('brand-new-topic')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(CategoryGlyphs.hasGlyph('brand-new-topic'), isFalse);
  });

  test('a retired category is parsed as inactive so chips can drop it', () {
    final retired = ContentCategory.fromJson(const {
      'slug': 'old-topic',
      'name': 'Old topic',
      'sortOrder': 11,
      'isActive': false,
    });
    expect(retired.isActive, isFalse);
    expect(retired.sortOrder, 11);
  });

  test('a category row carries the order the API means it to appear in', () {
    final rows =
        [
            const {'slug': 'b', 'name': 'B', 'sortOrder': 2},
            const {'slug': 'a', 'name': 'A', 'sortOrder': 1},
          ].map(ContentCategory.fromJson).toList()
          ..sort((x, y) => x.sortOrder.compareTo(y.sortOrder));
    expect(rows.map((c) => c.slug), ['a', 'b']);
  });
}
