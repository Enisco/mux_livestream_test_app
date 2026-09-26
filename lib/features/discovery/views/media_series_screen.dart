import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sizing/sizing.dart';

import 'package:test_app/core/logger.dart';
import 'package:test_app/features/discovery/repo/discovery_repo.dart';
import 'package:test_app/features/discovery/views/media_detail_screen.dart';
import 'package:test_app/features/discovery/views/widgets/detail_sections.dart';
import 'package:test_app/features/home/data/feed_card_mapper.dart';
import 'package:test_app/models/analytics_models/analytics_models.dart';
import 'package:test_app/models/discovery_models/content_detail.dart';
import 'package:test_app/models/discovery_models/media_detail.dart';
import 'package:test_app/models/discovery_models/web_feed_item.dart';
import 'package:test_app/shared/components/content_list_row.dart';
import 'package:test_app/shared/components/error_state_view.dart';
import 'package:test_app/shared/services/asset_url_resolver.dart';
import 'package:test_app/utils/app_constants/app_colors.dart';
import 'package:test_app/utils/app_constants/app_strings.dart';
import 'package:test_app/utils/app_constants/app_styles.dart';

/// A media series — a run of videos and tracks the creator put in order.
///
/// Tapping one of these used to open [MediaDetailScreen], which asks the
/// media aggregate for the series id. A series is not a media, so
/// `/v1/discovery/media/{id}/detail` answers **404** and the reader got an
/// error page instead of the series.
///
/// `GET /v1/public/media/series/{id}` is the route that knows about them. It
/// gives the title, description, cover key and `orderedMediaIds` — the
/// running order — but nothing about the items themselves, so each row's
/// title and still come from that media's own detail. Series are short, so
/// they are fetched together rather than one screen at a time.
class MediaSeriesScreen extends StatefulWidget {
  const MediaSeriesScreen({
    super.key,
    required this.seriesId,
    this.fallbackTitle = '',
    this.source = AnalyticsSource.unknown,
  });

  final String seriesId;

  /// What the feed row called it, shown until the real one arrives.
  final String fallbackTitle;

  final String source;

  @override
  State<MediaSeriesScreen> createState() => _MediaSeriesScreenState();
}

class _MediaSeriesScreenState extends State<MediaSeriesScreen> {
  final _repo = GetIt.instance<DiscoveryRepo>();

  MediaSeriesDetail? _series;
  List<MediaInfo?> _episodes = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final series = await _repo.fetchMediaSeries(widget.seriesId);
      // One row that cannot be read must not cost the whole series, so each
      // lookup answers null for itself rather than throwing.
      final episodes = await Future.wait(
        series.orderedMediaIds.map((id) async {
          try {
            final detail = await _repo.fetchMediaDetail(
              id,
              includeSuggestions: false,
            );
            return detail.media;
          } catch (e) {
            logger.w('Series episode $id could not be read', error: e);
            return null;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _series = series;
        _episodes = episodes;
        _loading = false;
      });
    } catch (e) {
      logger.w('Series ${widget.seriesId} could not be read', error: e);
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// Opens an episode. [MediaDetailScreen] fetches everything it needs from
  /// the id, so a row only has to carry enough to render before that lands.
  void _openEpisode(MediaInfo media) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaDetailScreen(
          item: WebFeedItem.fromJson({
            'entityType': 'media',
            'entityId': media.id,
            'title': media.title,
            'meta': {'mediaType': media.type},
            'facets': {'mediaType': media.type},
          }),
          source: widget.source,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    return Scaffold(
      backgroundColor: AppColors.base1,
      appBar: AppBar(
        backgroundColor: AppColors.base1,
        title: Text(
          series?.title.isNotEmpty ?? false
              ? series!.title
              : (widget.fallbackTitle.isEmpty
                    ? AppStrings.seriesTitle
                    : widget.fallbackTitle),
          style: AppStyles.heading(17),
        ),
      ),
      body: switch ((_loading, _failed)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (_, true) => ErrorStateView(onRetry: _load),
        _ => _content(series!),
      },
    );
  }

  Widget _content(MediaSeriesDetail series) {
    final count = FeedCardMapper.seriesCount(
      series.videoCount,
      series.musicCount,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(16.s, 8.s, 16.s, 32.s),
      children: [
        if (AssetUrlResolver.resolve(series.coverThumbnailKey)
            case final cover?) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12.s),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: AppColors.neutral800),
              ),
            ),
          ),
          SizedBox(height: 16.s),
        ],
        Text(series.title, style: AppStyles.heading(20)),
        if (count != null) ...[
          SizedBox(height: 6.s),
          Text(count, style: AppStyles.body(13, color: AppColors.neutral400)),
        ],
        if (series.description.trim().isNotEmpty) ...[
          SizedBox(height: 16.s),
          DetailDescriptionCard(body: series.description),
        ],
        SizedBox(height: 20.s),
        DetailSectionHeading(AppStrings.inThisSeries),
        SizedBox(height: 12.s),
        if (_episodes.isEmpty)
          Text(
            AppStrings.seriesEmpty,
            style: AppStyles.body(13, color: AppColors.neutral400),
          ),
        for (final (index, media) in _episodes.indexed)
          if (media != null)
            Padding(
              padding: EdgeInsets.only(bottom: 12.s),
              child: ContentListRow(
                title: media.title.isEmpty
                    ? AppStrings.seriesEpisode(index + 1)
                    : media.title,
                creatorName: AppStrings.seriesEpisode(index + 1),
                meta: FeedCardMapper.duration(null),
                onTap: () => _openEpisode(media),
              ),
            ),
      ],
    );
  }
}
