# API recon & JustSend mapping

## 1. Locket private API (`inferred` from binary + `observed` from public repos)

Host: `https://api.locketcamera.com` — all app calls use shape
`{"data": {...}}` and reply `{"result": {"data":..., "errors":[...], "status":200}}`.

### Auth (Google Identity Toolkit / Secure Token)
```
POST https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=<public key>
POST https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken?key=<public key>
POST https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=<public key>
POST https://securetoken.googleapis.com/v1/token?key=<public key>
```
Headers: `Authorization: Bearer <idToken>` (15–60 min TTL), `x-ios-bundle-identifier`,
iOS `User-Agent`; some endpoints require `X-Firebase-AppCheck` (device attestation).

### App endpoints
| Endpoint | Purpose |
|---|---|
| `signInWithPhonePassword` | custom token from phone+password |
| `createAccountWithEmailPassword` | signup |
| `getUserByUsername` / `fetchUserV2` | profile lookup |
| `changeProfileInfo` / `updateEmailAddress` / `sendVerificationCode` | profile |
| `deleteUserAccount` | account deletion |
| `getLatestMomentV2` | feed (`sync_token`, `last_fetch`, `excluded_users`, `should_count_missed_moments`) |
| `reactToMoment` | reaction (any string) |
| `deleteMomentV2` | delete (`delete_globally`) |
| `getMomentViews` | **Gold** — view list |
| `sendChatMessageV2` | chat message / comment |
| `getGroupsState` | groups |

Firestore (project `locket-4252a`):
`GET /v1/projects/locket-4252a/databases/(default)/documents/users/{uid}/friends`
plus subcollections `conversations`, `messages`, `notifications`, `memories`, etc.

Storage:
`https://firebasestorage.googleapis.com/v0/b/locket-img/o`, `.../locket-video/o`,
`.../locket-rollcall/o` — resumable uploads, media < 6 MB for video.

WebSocket: `wss://api.locketcamera.com/wss_v2/chat`, `/wss_v2/groups`, `/wss/chat`.

### Note/overlay presets (from locketlam)
`standard, review, music, location, weather, time, streak, star_sign, poll,
locket_count, colors, color_palette, party_time, good_morning, goodnight, ootd,
miss_you` + many `custom_<int64>` community captions.

### JustSend mapping
`APIClient` mirrors the envelope (`APIEnvelope<T>`), paths, and headers so a
self-hosted backend can be swapped in. `APIClient.config.baseURL` defaults to
`http://localhost:8787`; point at your own service. **JustSend does not ship
Locket credentials, App Check tokens, or entitlement bypasses.**

---

## 2. TikTok effect API (`inferred` from binary, `observed` from public sources)

### In-app private endpoints
```
GET/POST /aweme/v1/search/effect/
GET/POST /aweme/v1/original/effect/list/
GET/POST /aweme/v1/sticker/detail/
GET/POST /aweme/v1/sticker/discover/
GET/POST /aweme/v1/sticker/recommendation/
GET/POST /aweme/v1/sticker/resource/
GET/POST /aweme/v1/sticker/aweme/
GET/POST /aweme/v1/sticker/listcollection/
```
Signing required (X-Argus / X-Ladon / X-Gorgon / X-Khronos + device fingerprint).
Effect assets on `lf*_effectcdn*.tiktokcdn.com`.

### Public/partner options
- Official: TikTok Effect House `https://effecthouse.tiktok.com/api/app/effect_meta`
  (partner terms apply).
- Third-party metadata: `GET https://www.socialcrawl.dev/v1/tiktok/effects?ids=...`
  with `x-api-key` (1 credit / call, 50 ids max). Returns effect name, designer,
  views, `post.ext.video_count`. Match by returned `post.id`.

### JustSend crawler contract
`RustCore/justsend-crawler` implements:
- `manual` adapter (offline, credential-free) — ids → descriptors;
- `socialcrawl` adapter — checkpointed, 1 rps default, stops on 401/403/429;
- Rust-side validation + dedupe (`manifest::parse_catalog`, `merge`);
- output `catalog.json` imported in-app via **Filter Studio → Import catalogue**.

Effect binaries are NOT redistributed. Each descriptor carries `source_effect_id`
for provenance and maps to a native Core Image pass chain.
