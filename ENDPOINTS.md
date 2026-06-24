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

## 7. JOIN A LIVESTREAM

We will come back to this later
