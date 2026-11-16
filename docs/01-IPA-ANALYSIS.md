# Deep IPA analysis — Locket + TikTok

Scope: static analysis only (bundle inspection, plists, `strings`, embedded
symbol/source paths). No live account, no credential use, no traffic replay
against third-party infrastructure. Confidence labels follow the RATA skill
(`inferred` from binary/config, `observed` from public third-party research).

---

## 1. Inputs

| File | Size | Extracted | Notes |
|---|---:|---:|---|
| `locket.ipa` | 94.5 MB | 138 MB | `Payload/Locket.app`, main binary 55.4 MB (arm64, Swift + ObjC) |
| `tiktok.ipa` | 508.9 MB | 961 MB | `Payload/TikTok.app`, main stub 92 KB, `TikTokCore.framework` 859 MB |

Tooling used: `unzip`, `plutil`, `strings`, `grep`/`jq`, source-path strings.

---

## 2. Locket — feature map

### 2.1 Module inventory (from embedded `/^root/Sources/...swift` paths — 577 files)

| Cluster | Modules |
|---|---|
| Camera | `Camera`, `CameraTheme`, `FilterClient`, `FilterClientLive`, `FilterPurchaseClient`, `MediaPickerClient`, `PhotoLibraryClient`, `AVFoundationHelpers`, `CropFeature`, `ContentClassificationClient`, `CaptureClient` |
| Social core | `AppFeature`, `Friends`, `History`, `MomentViews`, `MomentClient`, `MomentManagerClient`, `MomentUploadClient`, `ReactionsClient`, `ReplyBar`, `StatusClient`, `StatusPromptFeature`, `StreaksFeature`, `CatchUp` |
| Messaging | `Chat`, `ConversationClient`, `MessagingClient`, `ChatWebSocketClient`, `WebSocketHelpers`, `Group*` clients |
| Weekly/Retro | `Rollcall`, `RollcallClient`, `RollcallShared`, `RollcallExportClient`, `TimeTravelFeature`, `TimeTravelClient`, `RewindClient`, `ScrapbookFeature`, `JournalFeature` |
| Monetisation | `Paywall`, `PurchasesClient`, `PurchasesClientLive` (RevenueCat), `RewardedReferralsFeature`, `RewardedReferralClient`, `AdClient`, `AdClientLive`, `AdModerationClient`, Nimbus/Vungle/AdMob SDKs |
| Growth | `Onboarding*`, `Invites`, `InviteLinkClient`, `InviteLinkClientLive`, `InviteSuggestion*`, `DynamicLinkClient`, `AppsFlyerClient`, `SurveyClient` |
| Platform | `WidgetClient*`, `WidgetGroupClient*`, `WidgetCache`, `WidgetBadgeClient`, `LiveActivityClient`, `NotificationHelpers`, `MemoryNotificationsClient`, `UserWidgetSetup` |
| Safety/Settings | `Safety`, `BlockClient`, `AbuseClient`, `SettingsFeature`, `ProfilePictureFeature`, `ExportClient`, `FeedbackGeneratorClient` |
| Third-party | `SpotifySharing`, `SpotifyClient`, `TikTokClient`, `SnapClient`, `SCSDKCreativeKit`, `Firebase*`, `Sentry`, `Amplitude`, GRDB |

### 2.2 Feature bundles (`Locket_*.bundle`, 33 app modules)

`AppFeature, Camera, CatchUp, CelebrityInbox, Chat, ContactsClientLive,
ExportClient, FilterClient, Friends, History, InviteLinkClient(Live),
JournalFeature, MomentViews, Onboarding(+Invites,+ContactPermissions),
Overlays, Paywall, ProfilePicture, RandomModels, RemoteConfigClient,
ReplyBar, RewardedReferralsFeature, Rollcall(+ExportClient,+Shared),
Safety, ScrapbookFeature, SettingsFeature, Share, StatusPromptFeature,
Styleguide(Legacy), TimeTravelFeature(+ExportClient), UserWidgetSetup`

### 2.3 Localisations

`Base, en, es, fr, id, ja, ko, pt-BR, vi` — 9 locales. `.strings` are binary
plists. UI strings enumerate: photo/video sharing, filters ("Couldn't create
filter", "Creating filter...", "Describe look...", "Naming your Look...",
"Create a Look"), generative looks, weekly Rollcall, Streaks, CatchUp,
Statuses, Scrapbook, Journal, widget setup, Friend Fund / referrals,
Locket Gold up-sells, 60s/longer videos ("Longer videos"), no ads in History.

### 2.4 Config (`LocketConfig.plist`)

- API functions: `https://api.locketcamera.com`
- WebSocket: `wss://api.locketcamera.com/wss/chat`, `/wss_v2/groups`
- Storage buckets: `gs://locket-img`, `gs://locket-video`, `gs://locket-rollcall`, `gs://locket-filters`
- Image cache 400 MB / 5 years; thumbnail 1020px @ 0.6 quality
- Chat reactions: 💛 😍 🤣 😭 🤯; quick: 💛 🔥 😂 😍
- `purchases_entitlement = Gold`, `purchases_enabled = true`
- `groups_enabled = true`, max 16; friend limit 20; signup max 10
- Widget frames, Live Activities, overlays, camera theme, ultra-wide camera enabled
- Firebase project `locket-4252a`, public API key embedded (standard for Firebase)

**Interpretation:** the app is TCA-based, Firebase-backed, with a Google-Cloud-
Functions API layer and Firebase Storage media. Filters live in a dedicated GCS
bucket and are purchasable (`FilterPurchaseClient`) — consistent with the
"create a look / generative look" strings.

### 2.5 Permissions & URL schemes

Camera, mic, photos (read + add), contacts, location when-in-use, motion,
media library (Apple Music), ATT, remote notifications, Live Activities.
Schemes: `aw9093dqvzij4mc4` (AppsFlyer), `com.locket.Locket`, Google reversed
client id. Queries Snapchat/Spotify/WhatsApp/Line/Kakao/Messenger/Telegram.

### 2.6 Frameworks

`MolocoSDK, NimbusKit (ads), OMSDK, SCSDKCoreKit/ CreativeKit (Snap),
SpotifyiOS, VungleAdsSDK`. No effect-rendering SDK — camera filters are image
overlays/LUTs served from `locket-filters`, not a full AR engine.

---

## 3. TikTok — filter/effect map

### 3.1 Structure

- Main binary is a 92 KB stub; all logic is in `Frameworks/TikTokCore.framework`
  (859 MB, arm64 Mach-O dylib). 203 resource bundles, 16 frameworks.
- Effect-related bundles: `CKEffectCreator.bundle`, `EffectSDKResources.bundle`,
  `CameraResource_i18n.bundle`, `IESLiveMTVideoGift`, `videovrsr`, `TTFFmpeg`.
- Effect engine: `tiktok_vesdk/tteffect/AmazingEngine` with `GeneralAR`,
  `AISystem`, `AtomConfigurator`, swing/segment APIs — i.e. a full on-device
  AR + beauty engine (not reproducible by simple LUTs).

### 3.2 Effect endpoints found in the binary (`inferred`)

```
/aweme/v1/search/effect/            # effect search
/aweme/v1/original/effect/list/     # creator's own effects
/aweme/v1/original/effects/
/aweme/v1/sticker/detail/           # effect/sticker detail
/aweme/v1/sticker/discover/
/aweme/v1/sticker/recommendation/
/aweme/v1/sticker/resource/         # effect resources
/aweme/v1/sticker/aweme/            # videos using an effect
/aweme/v1/sticker/listcollection/
/notice/effect_use_list
/openCamera/effect
https://effecthouse.tiktok.com/api/app/effect_meta
```

CDN hosts for effect assets: `lf16-effectcdn-sg.tiktokcdn.com`,
`lf16-effectcdn-us.tiktokcdn-us.com`, `lf19-effectcdn-sg.tiktokcdn.com`,
`lf19-effect.tiktokcdn-us.com`, `lf16-effectcdn.byteeffecttos-g.com`.
Paths look like `/obj/ies.fe.effect.alisg/<hash>` and
`/obj/ies-material-resource-us/...`.

API hosts: `api.tiktokv.com`, `api-va.tiktokv.com`, `inapp.tiktokv.com`,
`effecthouse.tiktok.com`, `www.tiktok.com`.

### 3.3 What this means for JustSend

TikTok effects are proprietary binaries with a signed resource format and
device-side engine. A third-party app **cannot** execute them directly. The
honest, working approach implemented here:

1. Crawl **metadata** (id, name, author, preview, usage counts) — see
   `rata-tiktok.yaml` and `RustCore/justsend-crawler`.
2. Map each effect to a **native filter recipe** (Core Image / Metal passes:
   smooth, whiten, contour, LUT, vignette) so the *look* is reproducible.
3. Optionally let users import their own LUT/bundle — no proprietary runtime.

This is documented as an approximation, not a binary-compatible effect player.

---

## 4. Repo recon (public, `observed`)

| Repo | Language | Value |
|---|---|---|
| `leanhminh2104/locketlam` | Python | Most complete private-API client: auth, device fingerprint, moments, friends, chat/WebSocket, filters, rollcall, 60s video notes. Endpoint catalogue in `docs/FEATURES.md`. |
| `jumpogpo/locket-api` | TypeScript | Typed SDK; clean docs of auth flows and envelope shapes (`result.data/errors/status`), moment views (Gold). |
| `Aedotris/locket` | Python | Original research notes: token TTL, `X-Firebase-AppCheck`, exact JSON payloads. |
| `thanhdo1110/Locket-Gold` | Python | Large Gold-focused project (research reference only — do not reuse credentials). |
| `molkex/tiktok-private-api` | Python | TikTok private API modules incl. effect/sticker detail; signing is a hosted service (do not reuse keys). |
| SocialCrawl `/v1/tiktok/effects` | HTTP | Paid-but-credit-based effect metadata by id (up to 50 ids/call). |

Full endpoint table in `docs/02-API-RECON.md`; machine-readable contracts in
`rata.yaml` and `rata-tiktok.yaml`.
