# GTUBE API INTEGRATION (MINIMAL FUNCTIONS FOR NOW)

Base URL = https://api.staging.gospeltube.tv

## 1. REGISTER

ENDPOINT = {{baseUrl}}/v1/auth/register

Payload body:
{
"firstName": "Gtube",
"lastName": "Test01",
"email": "gtubeapp+test01@gmail.com",
"phone": "+123456777899",
"password": "testtest",
"gender": "male",
"countryCode": "NG"
}

Response:
{
"success": true,
"data": {
"id": "6a3b6c59490012da62c724e3",
"email": "gtubeapp+test01@gmail.com",
"firstName": "Gtube",
"lastName": "Test01",
"phone": "+123456777899",
"gender": "male",
"countryCode": "NG",
"role": "user",
"status": "active",
"avatarFileId": null,
"avatarKey": null,
"viewerPreferenceCategorySlugs": [],
"viewerPreferencesCompletedAt": null,
"suspendedAt": null,
"deletedAt": null,
"updatedAt": "2026-06-24T05:34:17.045Z",
"createdAt": "2026-06-24T05:34:17.045Z"
}
}

## 2. LOGIN

ENDPOINT = {{baseUrl}}/v1/auth/login

Payload body:
{
"email": "gtubeapp+test01@gmail.com",
"password": "testtest",
"rememberDevice": true,
"clientType": "native"
}

Response:
{
"success": true,
"data": {
"type": "LOGGED_IN",
"user": {
"id": "6a3b6c59490012da62c724e3",
"email": "gtubeapp+test01@gmail.com",
"firstName": "Gtube",
"lastName": "Test01",
"phone": "+123456777899",
"gender": "male",
"countryCode": "NG",
"role": "user",
"status": "active",
"avatarFileId": null,
"avatarKey": null,
"viewerPreferenceCategorySlugs": [],
"viewerPreferencesCompletedAt": null,
"suspendedAt": null,
"deletedAt": null,
"updatedAt": "2026-06-24T05:34:17.045Z",
"createdAt": "2026-06-24T05:34:17.045Z"
},
"session": {
"id": "6a3b6cfa490012da62c724e7",
"userId": "6a3b6c59490012da62c724e3",
"familyId": "6a3b6cfa490012da62c724e7",
"expiresAt": "2026-07-08T05:36:58.734Z",
"createdAt": "2026-06-24T05:36:58.735Z",
"lastUsedAt": "2026-06-24T05:36:58.734Z",
"revokedAt": null,
"userAgent": "PostmanRuntime/7.54.0",
"ip": "::ffff:100.64.0.17"
},
"accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI2YTNiNmM1OTQ5MDAxMmRhNjJjNzI0ZTMiLCJlbWFpbCI6Imd0dWJlYXBwK3Rlc3QwMUBnbWFpbC5jb20iLCJyb2xlIjoidXNlciIsImlhdCI6MTc4MjI3OTQxOCwiZXhwIjoxNzgyMjgwMzE4fQ.u3jFzR3GcoWeTGRsJvzxKDL6rSyrPLZ1TRrH-IXqtV0",
"refreshToken": "\_cuNMuj4UTST.5CxcOxHu9mniz276XtiXp5BCHG6rtYBYtANPnuYrkT0"
}
}

Note: Save the user data in the local storage as well so the user's name can be showd in the home screen.
The access and refresh tokens will be fetched from local storage to authenticate requests and refresh sessions henceforth.

## 3. REFRESH SESSION

ENDPOINT = {{baseUrl}}/v1/auth/sessions/refresh

Payload body:
{
"refreshToken": "{{refreshToken}}"
}

Response:
{
"success": true,
"data": {
"user": {
"id": "6a3b6c59490012da62c724e3",
"email": "gtubeapp+test01@gmail.com",
"firstName": "Gtube",
"lastName": "Test01",
"phone": "+123456777899",
"gender": "male",
"countryCode": "NG",
"role": "user",
"status": "active",
"avatarFileId": null,
"avatarKey": null,
"viewerPreferenceCategorySlugs": [],
"viewerPreferencesCompletedAt": null,
"suspendedAt": null,
"deletedAt": null,
"updatedAt": "2026-06-24T05:34:17.045Z",
"createdAt": "2026-06-24T05:34:17.045Z"
},
"accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI2YTNiNmM1OTQ5MDAxMmRhNjJjNzI0ZTMiLCJlbWFpbCI6Imd0dWJlYXBwK3Rlc3QwMUBnbWFpbC5jb20iLCJyb2xlIjoidXNlciIsImlhdCI6MTc4MjI3OTc4NCwiZXhwIjoxNzgyMjgwNjg0fQ.Ry46qyGBvb3kktVprz71OADgAtpUdPUEwyip8rZiExQ",
"refreshToken": "KhZCHE4pXDnF.OSvFsPTPyhEavCjOZ6piBq2V1PV8CKK3nhb_Y0XUcww"
}
}

Note: Save these new tokens to replace the previous ones. If this refresh token request fails, show the user an error snackbar and route them to the login screen automatically.

## 4. ONBOARD CREATOR

To create a Creator Channel for a new user immediately their registration is complete.

ENDPOINT = {{baseUrl}}/v1/creator/onboard

- Auth token protected.

Payload body:
{
"type": "individual",
"handle": "tester01",
"displayName": "Tester01",
"bio": "Tester01 channel"
}

Note: "handle" must always be in lowercase

Response:
{
"success": true,
"data": {
"id": "6a3b712623c1d85baf05cdc0",
"type": "individual",
"handle": "tester01",
"displayName": "Tester01",
"bio": "Tester01 channel",
"avatarFileId": null,
"avatarKey": null,
"bannerFileId": null,
"bannerKey": null,
"ownerUserId": "6a3b6c59490012da62c724e3",
"status": "active",
"platformSaas": null,
"verifiedAt": null,
"createdAt": "2026-06-24T05:54:46.261Z",
"updatedAt": "2026-06-24T05:54:46.261Z"
}
}

Important Note: The "id": "6a3b712623c1d85baf05cdc0" returned in the response above is the user's "creatorId" and must be saved locally too, because it will be used to retrieve the user's livestream provision profile henceforth

## 5. PROVISION LIVESTREAM PROFILE

ENDPOINT = POST {{baseUrl}}/v1/media/live/creator/6a3b712623c1d85baf05cdc0/provision

- Auth token protected.
- The "6a3b712623c1d85baf05cdc0" is the saved creatorId.
- This endpoint can be called every time the user returns to the app evennthough it's idempotent, which means it will never change. but this is to ensure safety in case the user logs out and logs in again or logs in on a fresh device.

Payload body: Nil

Response:
{
"success": true,
"data": {
"id": "6a3b71273ac339f88a7a1704",
"creatorId": "6a3b712623c1d85baf05cdc0",
"muxLiveStreamId": "xBN6DcZFlcr5xgS2xBR7sd011axQKwCvk01zREnCkT52g",
"muxLivePlaybackId": "qM3O7iuFa5EVLan8psU34egaWC1X1TmjC00LWIP9qN1c",
"streamKeyRef": "68c65962-de26-96cd-1c00-be812a1513fa",
"rtmpIngestUrl": "rtmps://global-live.mux.com:443/app",
"createdAt": "2026-06-24T05:54:47.797Z",
"updatedAt": "2026-06-24T05:54:47.797Z"
}
}

Important notes:

- Save the "creatorId", "muxLivePlaybackId", "muxLiveStreamId", "rtmpIngestUrl", and "streamKeyRef" in the local storage.
- The "rtmpIngestUrl" and "streamKeyRef" are the credentials that will be used to start a livestream from this device. These are already implemented from the backend and we just need to stream using the rtmpIngestUrl and the streamKeyRef, just as it would have been if we are using an external streaming platform like OBS or Restream, etc.
- Whenever a user (creator) decides to "Go Live", call the endpoint below when their livestream is started successfully and is ON, the endpoint below allows other users on our platform to be able to see and join the livestream.

## 6. START A LIVESTREAM

To start a new livestream and inform the system so other users can see it and be able to join.

ENDPOINT = POST {{baseUrl}}/v1/media/live/creator/6a3b712623c1d85baf05cdc0/start

- Auth token protected.
- The "6a3b712623c1d85baf05cdc0" is the saved creatorId.

Payload body: Nil

Response:
{
"success": true,
"data": {
"id": "6a3b76723ac339f88a7a1707",
"creatorId": "6a3b712623c1d85baf05cdc0",
"type": "livestream",
"title": "Live Stream",
"description": null,
"categorySlugs": [],
"visibility": "public",
"status": "ready",
"isLiveNow": false,
"thumbnailFileId": null,
"thumbnailKey": null,
"thumbnailSource": null,
"muxAssetId": null,
"muxPlaybackId": null,
"muxPublicPlaybackId": null,
"muxLiveStreamId": "xBN6DcZFlcr5xgS2xBR7sd011axQKwCvk01zREnCkT52g",
"muxLivePlaybackId": "qM3O7iuFa5EVLan8psU34egaWC1X1TmjC00LWIP9qN1c",
"streamKeyRef": null,
"sourceLivestreamMediaId": null,
"livestreamRuntimeStatus": "connecting",
"transcriptUrl": null,
"durationSeconds": null,
"availableResolutions": [
"240p",
"360p",
"480p",
"720p",
"1080p"
],
"scheduledAt": null,
"publishedAt": null,
"startedAt": null,
"endedAt": null,
"analyticsViews": 0,
"analyticsWatchSeconds": 0,
"analyticsCompletions": 0,
"engagementLikeCount": 0,
"engagementCommentCount": 0,
"engagementShareCount": 0,
"engagementFavoriteCount": 0,
"createdAt": "2026-06-24T06:17:22.422Z",
"updatedAt": "2026-06-24T06:17:22.422Z"
}
}

## 7. END A LIVESTREAM

To end an active livestream and inform the system so it is no longer shown as live to other users.

ENDPOINT = POST {{baseUrl}}/v1/media/live/streams/{id}/end

- Auth token protected.
- {id} is the "id" field saved from the START A LIVESTREAM response (Step 6) — referred to as "liveMediaId" in the app.
- Call this when the user taps "End Stream" in the app. The app also stops the RTMP connection before calling this.
- If the stream was already ended or never started, the backend may return an error — this is safe to ignore.

Payload body: Nil

Response:
```json
{
  "success": true,
  "data": {
    "id": "6a3b76723ac339f88a7a1707",
    "status": "ended",
    "endedAt": "2026-06-24T07:00:00.000Z"
  }
}
```

## 9. GET CREATOR PROFILE

This endpoint returns the creator profile, the most important here is the creator ID because we will keep using it

ENDPOINT = GET {{baseUrl}}/v1/creator/profile

- Auth token protected.

Response:
{
"success": true,
"data": {
"creator": {
"id": "6a3b712623c1d85baf05cdc0",
"type": "individual",
"handle": "tester01",
"displayName": "Tester01",
"bio": "Tester01 channel",
"categorySlugs": [],
"avatarFileId": null,
"avatarKey": null,
"bannerFileId": null,
"bannerKey": null,
"ownerUserId": "6a3b6c59490012da62c724e3",
"status": "active",
"platformSaas": null,
"verifiedAt": null,
"createdAt": "2026-06-24T05:54:46.261Z",
"updatedAt": "2026-06-24T05:54:46.261Z"
},
"organizationProfile": null,
"leaders": []
}
}

## 10. JOIN A LIVESTREAM

Viewing any live stream (whether as a viewer joining from the home screen, or as the streamer watching their own stream via "Watch Your Stream") requires three steps: check live status, get a signed playback token, build the HLS URL.

The muxLivePlaybackId stored from PROVISION (Step 5) is a SIGNED playback ID and cannot be used directly — it always returns "Not Authorized". A short-lived token must be obtained from the backend first.

---

### Step 1 — Check if the creator is live

ENDPOINT = GET {{baseUrl}}/v1/public/live/creator/{creatorId}/status

- No auth required.
- {creatorId} is the creator's ID saved locally (from onboarding or GET /v1/creator/profile).

Response (live):

```json
{
  "success": true,
  "data": {
    "isLive": true,
    "mediaId": "6a3b76723ac339f88a7a1707"
  }
}
```

Response (not live):

```json
{
  "success": true,
  "data": {
    "isLive": false,
    "mediaId": null
  }
}
```

Notes:

- If isLive is false, do not proceed — show "Stream is not live" to the user.
- Save the returned mediaId — it is required for Step 2.
- For "Watch Your Stream" (streamer watching themselves): skip Step 1. The mediaId is already in the startLivestream response (Step 6) as the top-level "id" field ("6a3b76723ac339f88a7a1707"). Save it locally when Step 6 is called.

---

### Step 2 — Request a signed playback token

ENDPOINT = GET {{baseUrl}}/v1/media/live/streams/{mediaId}/playback-token?clientSessionId={clientSessionId}

- Auth token protected.
- {mediaId} is from Step 1 (or from the saved startLivestream "id" for the streamer's own watch).
- {clientSessionId} is a stable ID for this viewing session.

clientSessionId rules:

- Only letters, numbers, \_ or - are allowed. No spaces or other characters.
- Length must be 8–128 characters.
- Generate once per viewing session (not per token refresh). Store in memory only.
- Suggested format: strip dashes from a UUID v4, e.g. "6a3b6c59490012da62c724e3" (32 chars), or prefix with "sess-" + 12 random alphanumeric chars.

Response:

```json
{
  "success": true,
  "data": {
    "playbackId": "nbYms59lHmO7WFPsPK8QHOAZrPRqbx3yIwoyhwotah4",
    "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresAt": "2026-06-24T08:00:00.000Z"
  }
}
```

---

### Step 3 — Build the HLS URL and open the player

Construct the final URL using playbackId and token from Step 2:

https://stream.mux.com/{playbackId}.m3u8?token={token}

Open this in PlayerScreen.network(networkUrl: url).

Token refresh: monitor expiresAt. If the viewer is still watching when the token approaches expiry, call Step 2 again with the same clientSessionId and update the player URL to avoid playback interruption.

---

### Summary of what to save locally from Step 6 (startLivestream)

From the startLivestream response, save the top-level "id" as "liveMediaId":

- "id": "6a3b76723ac339f88a7a1707" → save as liveMediaId (used in Step 2 for "Watch Your Stream")

This mediaId is also what Step 1 returns when a viewer checks if the creator is live.
