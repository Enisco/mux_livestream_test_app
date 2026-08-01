# Client Media Integration Guide

Last verified: 2026-07-02

This guide explains how web and mobile clients should integrate GospelTube media playback, detail pages, feeds, thumbnails, previews, suggestions, and analytics through the API gateway.

For the complete creator studio, scheduling, viewer playback, realtime state, presence, and replay contract for livestreams, see [Client Livestream Integration Guide](./client-livestream-integration.md).

All routes below are gateway routes under `/v1`. Gateway JSON responses are wrapped as:

```json
{
  "success": true,
  "data": {}
}
```

On errors, clients should expect:

```json
{
  "success": false,
  "error": "Message or validation errors"
}
```

## Core Rules

- Prefer the media detail aggregate for content detail pages: `GET /v1/discovery/media/:id/detail`.
- Prefer `playback.playbackUrl` from the detail or playback-info response. Do not build Mux stream URLs for regular video/music playback.
- Treat `playbackUrl`, `thumbnailUrl`, and `preview.url` as short-lived signed URLs. Refresh the detail/playback-info response when playback or images expire/fail.
- Public and anonymous clients can read public media. Unlisted media requires `shareToken`. Private media requires authenticated access and ownership/admin permissions.
- For anonymous livestream playback, always send a stable per-session `clientSessionId` so the backend can issue and track a signed live playback session.
- Feed image and preview URLs may be gateway proxy URLs such as `/v1/public/media/:id/assets/thumbnail`; use them directly as image sources.
- The vertical feed is mobile-only and media-only. Do not use it for desktop web layouts, posts, events, creators, or mixed content feeds.
- Include `mediaType` (`video`, `music`, or `livestream`) on media analytics beacons whenever the client knows it.
- Emit primary-card `click` analytics on the source surface. For a promoted unit, also emit `promotion_click` with its signed attribution before navigation. Never synthesize a paid impression or click from the destination detail screen.

## Route Summary

| Use case | Method | Route | Auth |
| --- | --- | --- | --- |
| Media detail aggregate | `GET` | `/v1/discovery/media/:id/detail` | Optional |
| Public media detail aggregate | `GET` | `/v1/public/media/:id/detail` | Optional |
| Authenticated playback info | `GET` | `/v1/media/:id/playback-info` | Required |
| Public playback info | `GET` | `/v1/public/media/:id/playback-info` | Optional |
| Public signed thumbnail/preview proxy | `GET` | `/v1/public/media/:id/assets/:kind` | Optional |
| Web/mixed discovery feed | `POST` | `/v1/discovery/web-feed` | Optional |
| Content detail suggestions | `POST` | `/v1/discovery/content-suggestions` | Optional |
| Mobile vertical feed | `POST` | `/v1/discovery/vertical-feed` | Optional |
| Anonymous analytics batch | `POST` | `/v1/analytics/beacons` | Optional |
| Authenticated analytics batch | `POST` | `/v1/analytics/beacons/auth` | Required |
| Livestream presence socket | Socket.IO | namespace `/live` on the API gateway origin | Optional |

`kind` for media assets is either `thumbnail` or `preview`.

## Media Detail Flow

Use this flow for video, music, and livestream detail pages on web and mobile.

1. Create or reuse a client analytics session ID.
   - Web currently stores a UUID in `sessionStorage` under `gt_analytics_session_id`.
   - Mobile should generate a UUID for each app/session and reuse it for analytics events.

2. Create or reuse a `clientSessionId`.
   - Required for anonymous livestream playback.
   - Recommended for all public detail calls so live support works consistently.
   - Must match `[A-Za-z0-9_-]{8,128}`.

3. Request the detail aggregate.

```http
GET /v1/discovery/media/6a300fcd3ac339f88a7a16f7/detail?clientSessionId=session_12345678&includeSuggestions=true&suggestionsLimit=10
```

For unlisted links, include the share token:

```http
GET /v1/discovery/media/:id/detail?shareToken=abc123def456&clientSessionId=session_12345678
```

Promotion attribution belongs to the served placement. Use it to emit source-surface promotion events before navigation; do not put the signed delivery token in destination URLs or reconstruct paid events from route state. Do not mint, decode, or modify `promotionDeliveryId` on the client.

4. Render from `data`.

Important fields:

```ts
type MediaDetailData = {
  media: Media;
  playback: {
    mediaId: string;
    mediaType: "video" | "music" | "livestream";
    playbackId: string;
    playbackUrl: string;
    playbackToken?: string | null;
    playbackTokenExpiresAt?: string | null;
    thumbnailUrl?: string | null;
    imageExpiresAt?: string | null;
    durationSeconds?: number | null;
    availableResolutions: string[];
    defaultResolution: string;
    canSelectResolution: boolean;
    preview: {
      kind: "mux_animated_image";
      format: "webp";
      url: string;
      startSeconds: number;
      endSeconds: number;
    } | null;
  } | null;
  creator: {
    creatorId: string;
    displayName: string;
    handle: string;
    avatarKey?: string | null;
    isFollowing?: boolean;
    isOwnedByViewer?: boolean;
    isVerified: boolean;
  } | null;
  viewer: {
    interactionTypes: string[];
    isFollowingCreator: boolean;
    isOwnedByViewer: boolean;
  } | null;
  suggestions: {
    items: WebFeedItem[];
    nextCursor: string | null;
  } | null;
};
```

5. If `playback` is `null`, show a normal unavailable/loading state. This usually means playback is not ready, not accessible, or the media does not currently have a playable Mux asset.

## Playback

### Web

- Use HLS.js for browsers that need Media Source Extensions.
- Use native HLS by assigning `video.src = playback.playbackUrl` where supported, especially Safari.
- Always use the returned `playback.playbackUrl`. It already includes the signed token when one is required.
- Do not persist the URL as permanent state. It can expire.

Resolution selector behavior:

- Show `Auto` plus the entries in `playback.availableResolutions`.
- Only show manual quality options when `playback.canSelectResolution` is true.
- Match labels like `240p`, `360p`, `480p`, `720p`, `1080p` to HLS levels by height.
- Use HLS auto-level mode when `Auto` is selected.
- Music returns `["audio-only"]` and should not show a video resolution picker.

### Mobile

- Use the platform HLS player with `playback.playbackUrl`.
- The mobile player should use adaptive streaming by default.
- If exposing manual resolution selection, map `availableResolutions` to the player's track groups and keep `Auto` as the default.
- For anonymous livestreams, pass `clientSessionId` to detail/playback-info. Without it, public live playback may not receive a usable signed live playback URL.

### Playback-Info Refresh

If the client already has media metadata and only needs a fresh signed playback URL:

```http
GET /v1/public/media/:id/playback-info?clientSessionId=session_12345678
GET /v1/media/:id/playback-info
```

Use the public route for anonymous/public access, and the authenticated route when the user is signed in. Include `shareToken` for unlisted media.

The response data shape is the same `playback` object returned by the media detail aggregate.

### Livestream Token Route

Most clients should still prefer detail/playback-info. If a livestream client calls the token route directly, the response is only token components:

```http
GET /v1/public/live/streams/:id/playback-token?clientSessionId=session_12345678
GET /v1/media/live/streams/:id/playback-token
```

Response data:

```json
{
  "token": "jwt",
  "expiresAt": "2026-07-01T12:00:00.000Z",
  "playbackId": "mux_playback_id"
}
```

In this special case the client must build:

```text
https://stream.mux.com/{playbackId}.m3u8?token={token}
```

### Livestream Presence, Status, And Viewer Count

Use the API gateway Socket.IO namespace `/live` while a livestream detail screen/player is active. The socket is optional-auth: authenticated web clients should connect with credentials so the gateway can read the normal auth cookie, while anonymous clients can connect without a token.

Subscribe while the viewer is actively watching a live stream. Include `creatorId` when the detail payload has it so analytics samples can be creator-scoped immediately:

```ts
socket.emit("live.subscribe_stream", { creatorId, streamId }, (ack) => {
  // ack: { ok: true, room: "stream:{streamId}", viewerCount: number }
});
```

Unsubscribe when the viewer leaves the stream, and also unsubscribe locally after a terminal status:

```ts
socket.emit("live.unsubscribe_stream", { streamId });
```

Listen for viewer-count snapshots:

```ts
socket.on("livestream.viewer_count", (payload) => {
  // payload: { streamId: string, viewerCount: number }
});
```

Listen for stream status changes:

```ts
socket.on("livestream.status_changed", (payload) => {
  // payload: {
  //   streamId: string;
  //   creatorId: string;
  //   status: "idle" | "connecting" | "live" | "reconnecting" | "ended" | "errored";
  //   startedAt?: string | null;
  //   endedAt?: string | null;
  // }
});
```

Use `viewerCount` for "Watching" labels on livestream detail/player UI. Until the socket ack or event arrives, clients may show the existing feed/detail fallback count.

The gateway records livestream concurrent-viewer analytics from subscribe, unsubscribe, and disconnect viewer-count changes. Clients should not emit a separate concurrent-viewer beacon.

Use `status` as the canonical live runtime state for an open player:

- `connecting`: show a waiting/loading live UI while the creator is starting the stream.
- `live`: show the live player and live-edge controls.
- `reconnecting`: keep the player available, show a reconnecting UI, and resume automatically when new segments arrive.
- `idle`: stop treating the page as live. This usually means the creator started a session but the encoder never connected.
- `ended`: stop treating the page as live. This is emitted after a live/reconnecting session reaches Mux idle or after the platform intentionally ends the stream.
- `errored`: stop treating the page as live and show an error state if the backend emits an explicit creator/platform failure.

For `idle`, `ended`, and `errored`, unsubscribe from `live.subscribe_stream`, hide live viewer-count UI, and refetch the detail payload so search/detail state catches up.

## Thumbnails And Previews

Media detail playback may include:

- `playback.thumbnailUrl`: signed thumbnail image URL.
- `playback.preview.url`: signed animated preview URL.
- `media.thumbnailKey`: manually uploaded thumbnail key.

Feed and suggestion items may include asset fields inside `item.meta`:

- `thumbnailUrl`
- `previewUrl`
- `thumbnailKey`
- `thumbnailSource`

Client behavior:

- Prefer `thumbnailUrl` when present.
- If only `thumbnailKey` is present, resolve it through the normal file/image helper used by the app.
- For video previews, use `previewUrl` when present.
- If no video thumbnail is available, use the default media image provided by the designer.
- For music with no cover image, use the default music cover image.
- Do not construct raw Mux image URLs from playback IDs.

The public asset proxy route redirects to a signed Mux image URL:

```http
GET /v1/public/media/:id/assets/thumbnail
GET /v1/public/media/:id/assets/preview
```

These proxy URLs are only generated for public, published, Mux-auto video thumbnails/previews. Manual thumbnails keep their file-backed key instead.

## Suggestions

Media detail can return suggestions inline when `includeSuggestions` is not false:

```http
GET /v1/discovery/media/:id/detail?includeSuggestions=true&suggestionsLimit=10
```

To paginate or reload the right rail/mobile related list separately:

```http
POST /v1/discovery/content-suggestions
Content-Type: application/json

{
  "targetType": "media",
  "targetId": "6a300fcd3ac339f88a7a16f7",
  "limit": 10,
  "cursor": null,
  "excludeEntityIds": ["6a300fcd3ac339f88a7a16f7"],
  "sort": "popular"
}
```

Supported suggestion sorts are `popular` and `recent`. `trending` is not supported for suggestions.

Suggestion priority:

1. Same media type as the current media, when the anchor media type is known.
2. Same creator.
3. Broader explore results.

Suggestions can include media and other content entities, unless `entityTypes` is passed. If no suggestions are returned, clients should hide the suggestions section.

Topic behavior:

- Pass `categorySlugs` to bias suggestions toward selected topics.
- For authenticated users, pass `useViewerCategoryPrefs: true` when no explicit `categorySlugs` are selected and personalization is desired.
- Detail suggestions automatically use the current media as the anchor and exclude the current media ID.

## Web And Mixed Feeds

Use `POST /v1/discovery/web-feed` for the home-style feed and other mixed content surfaces.

Despite the route name, this is the general mixed discovery feed contract. It supports media, posts, events, devotional content, series, and creators depending on `entityTypes`.

Example:

```http
POST /v1/discovery/web-feed
Content-Type: application/json

{
  "limit": 20,
  "mode": "mixed",
  "sort": "recent",
  "categorySlugs": ["sermons"],
  "useViewerCategoryPrefs": false,
  "excludeEntityIds": []
}
```

Request fields:

| Field | Notes |
| --- | --- |
| `limit` | 1 to 50. Defaults to 20. |
| `cursor` | Return `nextCursor` from the previous page. |
| `mode` | `mixed`, `following_only`, or `explore_only`. |
| `sort` | `recent`, `popular`, or `trending`. |
| `entityTypes` | Optional filter. Omit for the default mixed feed. |
| `categorySlugs` | Topic filter/boost. |
| `useViewerCategoryPrefs` | Uses saved viewer topics for authenticated users when `categorySlugs` is empty. |
| `liveOnly` | Media-only live filter. |
| `excludeEntityIds` | IDs or `entityType:id` keys to exclude. |

Important constraints:

- `following_only` requires authentication.
- `liveOnly` can only be used with media results.
- `trending` is media-only; do not request non-media entity types with `sort: "trending"`.

Response:

```ts
type WebFeedResponse = {
  items: WebFeedItem[];
  nextCursor: string | null;
};
```

Each item includes `entityType`, `entityId`, `title`, `creator`, `engagementTargetType`, `facets`, `meta`, and optional event date fields. Media cards should read thumbnail/preview fields from `meta`.

Promoted web/mixed feed items may include these fields in `meta`:

```ts
type PromotedWebFeedMeta = {
  isPromoted?: boolean;
  promotionCampaignId?: string;
  promotionPlacement?: "catalogue" | "vertical_feed";
  promotionDeliveryId?: string;
};
```

For promoted feed items, retain these values only long enough to emit the source-placement analytics events. Do not append signed promotion attribution to the destination URL or attach it to organic items.

### Card clicks and promoted clicks

Emit click events from the card/tile/row that the user actually activated, immediately before navigation:

1. Send `click` for every primary content navigation. Use the card target, creator, and actual source (`home_feed`, `suggested_content`, `creator_channel`, etc.). This event is non-billable and feeds CTR/funnel analytics.
2. If and only if that card is a promoted placement with server-issued attribution, also send `promotion_click` with `promotionCampaignId`, `promotionPlacement`, and the unmodified `promotionDeliveryId`.
3. Flush both in the same keepalive-capable batch before navigation. Do not require the impression dwell threshold; a fast click remains a click and does not become an impression.

Do not count context-menu, like, bookmark, follow, RSVP, preview-hover, or other secondary controls as content clicks. Destination detail/channel pages may send their normal organic `impression`, playback, and reading events, but must never emit a catch-up `promoted_qualified_impression` or `promotion_click`. The backend validates and deduplicates the paid click; never fabricate or alter a delivery token.

## Devotional Detail And Progress

Devotional series and entry detail pages use content-service public routes through the gateway:

```http
GET /v1/public/content/devotionals/series/:seriesId
GET /v1/public/content/devotionals/entries/:entryId
POST /v1/public/content/devotionals/entries/:entryId/progress
```

Series and entry reads accept optional auth. Authenticated series responses include `viewerProgress` so clients can render completed days, the current in-progress day, and the next unfinished entry. Authenticated entry reads mark the opened entry as `in_progress` without downgrading a completed entry.

Entry detail returns `entry`, `series`, `seriesEntries`, `navigation`, and optional `viewerProgress`. Use `navigation.previousEntryId` / `navigation.nextEntryId` for previous/next buttons, and call the progress endpoint when the viewer marks a day complete:

```json
{
  "status": "completed"
}
```

Send devotional analytics as content beacons:

- Series detail: `contentType: "devotional_series"` and `contentId: seriesId`.
- Entry detail: `contentType: "devotional_entry"` and `contentId: entryId`.
- When the viewer marks an entry complete, send `completion` for the entry. If that entry completes the final published day in the series, also send `completion` for the series.
- Promoted devotional cards follow the same source-surface `click` + `promotion_click` rule above. The devotional detail page emits only its normal organic/detail analytics.

## Mobile Vertical Feed

Use `POST /v1/discovery/vertical-feed` only for mobile vertical media experiences.

This feed is:

- Mobile-only.
- Media-only.
- Designed for full-screen swipe/vertical playback.
- Not a replacement for the web/mixed home feed.
- Not for posts, events, creators, devotionals, or mixed content.

Example:

```http
POST /v1/discovery/vertical-feed
Content-Type: application/json

{
  "limit": 15,
  "mode": "mixed",
  "excludeMediaIds": [],
  "cursor": null,
  "anchorMediaId": "6a300fcd3ac339f88a7a16f7",
  "includeServerContinueWatching": true
}
```

Request fields:

| Field | Notes |
| --- | --- |
| `limit` | 10 to 20. Defaults to 15. |
| `cursor` | Return `nextCursor` from the previous page. |
| `mode` | `mixed`, `following_only`, or `explore_only`. |
| `excludeMediaIds` | Media IDs already rendered client-side. |
| `anchorMediaId` | Current media anchor for related vertical results. |
| `anchorCreatorId` | Creator anchor if no media anchor is available. |
| `prioritizeMediaIds` | Client-local continue list; server validates visibility then prepends. |
| `includeServerContinueWatching` | Authenticated users can prepend analytics-backed continue-watching items. |

Response:

```ts
type VerticalFeedResponse = {
  items: Array<{
    mediaId: string;
    creatorId: string;
    title: string;
    type: "video" | "music" | "livestream";
    visibility: "public" | "unlisted" | "private";
    status: string;
    isLiveNow: boolean;
    thumbnailUrl?: string | null;
    previewUrl?: string | null;
    durationSeconds?: number | null;
    isPromoted?: boolean;
    promotionCampaignId?: string;
    promotionPlacement?: "vertical_feed";
    promotionDeliveryId?: string;
  }>;
  nextCursor: string | null;
};
```

Playback from vertical feed:

1. Render the tile from feed metadata.
2. When the item becomes active, request detail or playback-info for that media ID.
3. Play `playback.playbackUrl`.
4. Do not play directly from feed `muxPlaybackId`/`muxLivePlaybackId` fields.

Promoted vertical items:

- If `isPromoted` is true, retain `promotionCampaignId`, `promotionPlacement`, and `promotionDeliveryId`.
- Send `promoted_qualified_impression` only after the client-side visibility/dwell threshold is met.
- Include the promotion fields in the analytics beacon so the server can validate the delivery token.
- On primary tile navigation, send the non-billable `click` plus the verified `promotion_click` before navigating, even if the impression threshold has not completed.

## Analytics Beacons

Clients should send analytics for playback and promoted feed impressions.

Routes:

```http
POST /v1/analytics/beacons
POST /v1/analytics/beacons/auth
```

Batch payload:

```json
{
  "events": [
    {
      "eventId": "3e1c0d4d-8c52-4b2f-83d6-bbfba6a2f0de",
      "mediaId": "6a300fcd3ac339f88a7a16f7",
      "mediaType": "video",
      "creatorId": "6a2423ae0e90471cdcb3af5d",
      "eventType": "view_started",
      "occurredAt": "2026-07-01T12:00:00.000Z",
      "positionSeconds": 0,
      "source": "home_feed",
      "identity": {
        "sessionId": "2bc84f6e-003b-4d7d-ae1f-2b56ce8c7932"
      },
      "client": {
        "platform": "ios",
        "appVersion": "1.0.0",
        "deviceType": "phone",
        "networkType": "wifi"
      }
    }
  ]
}
```

Playback event guidance:

| Event | When to send |
| --- | --- |
| `view_started` | First successful play for a media item. |
| `play` | Resume after the first start. |
| `pause` | User pauses; include `positionSeconds` and any accumulated `watchDurationSeconds`. |
| `seek` | User seeks; include the new `positionSeconds`. |
| `progress` | Periodically during playback, around every 10 seconds of position movement. |
| `view_ended` | Playback session ends because the user leaves, closes the player, navigates away, or a livestream reaches a terminal status; include final `positionSeconds` / `watchDurationSeconds` and flush immediately. |
| `completion` | VOD playback reaches the actual end; flush immediately. Do not use this for livestream session close. |

Implementation notes:

- `eventId` should be a UUID and unique per event.
- `identity.sessionId` is required.
- Web anonymous beacons use the `gt_anon_viewer` cookie server-side; mobile can send `anonymousViewerId` when no cookie exists.
- Authenticated clients should call `/v1/analytics/beacons/auth`.
- Use `source` values such as `creator_channel`, `home_feed`, `suggested_content`, `search`, `share_link`, `notification`, `external`, or `unknown`.
- Flush progress, `view_ended`, and `completion` with keepalive or equivalent when the page/app is backgrounded.
- For promoted items, `promoted_qualified_impression` requires `promotionCampaignId`, `promotionPlacement`, and `promotionDeliveryId`.
- Primary content navigation emits `click`; a promoted source unit additionally emits `promotion_click` with those same required promotion fields.

## Engagement, Comments, And Auth Nudges

Media detail returns `viewer.interactionTypes` for authenticated viewers. Use it to initialize like/dislike/bookmark UI.

Engagement and comments are not owned by media-service, but media clients normally need these routes:

- `POST /v1/engagement/interactions`
- `POST /v1/engagement/interactions/me/batch`
- `GET /v1/public/engagement/comments`
- `GET /v1/public/engagement/comments/:commentId/replies`
- `POST /v1/engagement/comments`
- `PATCH /v1/engagement/comments/:commentId` to edit the signed-in viewer's own comment.
- `POST /v1/engagement/comments/:commentId/vote`
- `DELETE /v1/engagement/comments/:commentId`
- `POST /v1/engagement/reports`

Public users can read public comments but must sign in before liking, disliking, bookmarking, commenting, replying, reporting, following, or giving.

## Creator Upload And Publish Flow

Use this section only for creator/admin clients that upload media.

1. Request a source upload URL.

```http
POST /v1/media/request-upload
Content-Type: application/json

{
  "creatorId": "6a2423ae0e90471cdcb3af5d",
  "mediaType": "video",
  "filename": "sunday-message.mp4",
  "mimeType": "video/mp4",
  "size": 104857600,
  "uploadTarget": "web"
}
```

2. Upload the file directly to `data.uploadUrl` using the returned method and headers.

3. Optional: request a thumbnail upload URL.

```http
POST /v1/media/thumbnail/upload-url
Content-Type: application/json

{
  "creatorId": "6a2423ae0e90471cdcb3af5d",
  "filename": "thumbnail.jpg",
  "mimeType": "image/jpeg",
  "size": 512000
}
```

4. Create the media row.

```http
POST /v1/media
Content-Type: application/json

{
  "creatorId": "6a2423ae0e90471cdcb3af5d",
  "type": "video",
  "title": "Sunday Message",
  "description": "A teaching on faith and hope.",
  "categorySlugs": ["sermons"],
  "visibility": "private",
  "sourceUploadId": "upload_123",
  "thumbnailFileId": "6a300fcd3ac339f88a7a16f8"
}
```

5. Publish when processing is ready.

```http
POST /v1/media/:id/publish
Content-Type: application/json

{
  "visibility": "public"
}
```

Allowed source constraints:

- Video max size: 5 GB.
- Music max size: 1 GB.
- Music MIME types: `audio/mpeg`, `audio/mp4`, `audio/wav`, `audio/x-wav`, `audio/webm`.
- Video MIME types include `video/mp4`, `video/webm`, `video/quicktime`, and `video/x-m4v`. iOS upload targets exclude `video/webm`.
- Thumbnail MIME types: `image/jpeg`, `image/png`, `image/webp`.

## Practical Client Checklist

- Generate a session ID for analytics.
- Generate a `clientSessionId` for playback/detail requests.
- Load detail from `/v1/discovery/media/:id/detail`.
- Render `media`, `creator`, `viewer`, and `suggestions`.
- Play `playback.playbackUrl`.
- Use HLS adaptive streaming by default.
- Build quality controls from `availableResolutions`.
- Use returned thumbnail/preview URLs or file-backed thumbnail keys.
- Send playback analytics events.
- Include `mediaType` on media analytics beacons.
- Hide suggestions when no items are returned.
- Use `/v1/discovery/web-feed` for mixed/home feeds.
- Emit source-attributed `click` and, for promoted units, `promotion_click` before navigation.
- Use `/v1/discovery/vertical-feed` only for mobile media-only vertical playback.
- For vertical feed active items, fetch detail/playback-info before playing.
- Emit paid promotion events only from the actual promoted placement with valid server-issued attribution; destination pages never synthesize them.
