# MPLAD SATYA — Flutter client

The mobile client for the MPLAD SATYA risk-intelligence backend. Every screen
reads live data from the API; there is no bundled sample data and no offline
demo mode baked into the app.

## Prerequisites

- Flutter SDK (Dart `^3.10.7`)
- A running SATYA backend (see `../server/README.md`)

## Point the app at a backend

The API base URL is compiled in, never read at runtime, so a shipped build
cannot be redirected after the fact. Targets live in `config/` and are selected
with Flutter's own `--dart-define-from-file`:

```bash
flutter run --dart-define-from-file=config/render.json    # deployed API
flutter run --dart-define-from-file=config/local.json     # emulator -> host
flutter run --dart-define-from-file=config/hotspot.json   # phone -> laptop

flutter build apk --release --dart-define-from-file=config/render.json
```

| Config | Endpoint |
|---|---|
| `render.json` | `https://mplad-satya-hi8x.onrender.com` (the deployed service) |
| `local.json` | `http://10.0.2.2:8000` — the host as seen from the Android emulator |
| `hotspot.json` | a laptop on the demo hotspot; **edit the IP** |

`render.json` is also the compiled-in default, so a plain
`flutter build apk --release` produces a working demo build rather than one
silently aimed at a loopback address that only exists on a developer's machine.

For a phone over USB with no network at all:

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

The first call after launch gets a 75-second budget rather than the usual 30:
an idle Render instance cold-starts in roughly 50 s, and the startup handshake
wakes it while the splash is still up, so the service is warm before an officer
taps anything.

The current endpoint and server status are shown on the login screen and in
Settings, so a phone pointed at the wrong host is obvious immediately.

**Release builds require HTTPS.** `android/app/src/main/res/xml/network_security_config.xml`
denies cleartext, so a signed APK cannot leak a session token or a site photo
over plaintext HTTP. Debug builds override this to allow local addresses.

## Signing in

Authentication is phone + OTP against `POST /auth/otp/request` and
`/auth/otp/verify`. There is no demo bypass.

When the server runs with `SMS_PROVIDER=console` it returns the code in the
response; the app shows it and prefills the field, so the demo does not depend
on a live SMS gateway. Production refuses to boot in that mode, so the code can
never be returned from a real deployment.

A phone number the server does not recognise self-provisions as `citizen`.
Officer roles are pre-provisioned by an admin — verifying an OTP never elevates
a role.

## Data sources — what is real, and what is not

Mocks exist only where a real integration is genuinely unavailable. Where a
free public source exists, the app uses it.

| Source | Status | Notes |
|---|---|---|
| **OpenStreetMap** tiles | Live | Raster tiles via `flutter_map`, attribution rendered per licence |
| **Nominatim** geocoding | Live | Place search on the map. Throttled to 1 req/s and sent with an identifying User-Agent, per their usage policy. Called directly (not via our API) because it carries only the typed text, no MPLADS data |
| **ISRO Bhuvan** satellite | Live code, off by default | `BhuvanAdapter` does a real WMS `GetMap`. Enable with `SATELLITE_ADAPTER=bhuvan`. Every reading is stamped **LIVE** or **FIXTURE**. **A live single-date observation can only ever return `inconclusive`** — see below |
| **Your own uploads** | Live | Full pipeline: sha256, EXIF, GPS trust, face blur, pHash, rescore |
| **CPWD DSR** rates | Real values, no API | CPWD publishes no API. Rates are transcribed with item-level provenance (`CPWD DSR 2024 Vol-I item 16.42`) and shown on the reason that cites them |
| **eSAKSHI** | Adapter, not an independent source | MoSPI publishes no public REST API. The adapter serves the same rows through an external-source interface so the verification pipeline is exercised end to end. **The Official tab says this on screen** — an officer must never think a field was independently corroborated when it was not. Only the adapter's fetch method changes when access is granted |

### What the satellite check can and cannot say

Two claims were removed from this feature because the data does not support them:

- **It does not compute NDBI.** NDBI is `(SWIR − NIR) / (SWIR + NIR)`. Bhuvan's
  public WMS returns a *rendered visual PNG* with no SWIR and no NIR band, so a
  true built-up index cannot be derived from it. What is computed is a
  red-green brightness contrast, named `brightness_index` in the API and
  labelled as "not NDBI" in the UI. It is a weak corroborating hint.
- **It does not detect change.** `observe()` fetches one tile. A road built
  twenty years ago produces the same signal as one built last month, so a
  single-date observation cannot establish that work was carried out. A live
  observation therefore tops out at `inconclusive`; `is_temporal_comparison`
  is `false` and the UI says so. Establishing change needs a before/after pair,
  which the free endpoint does not expose.

Verdict states: `match` · `mismatch` · `inconclusive` · `unavailable`.
A WMS timeout or an undecodable tile is `unavailable` — a service outage, never
a finding about the work. An `inconclusive` reading contributes **zero** points.

### Measured against the live endpoint — 2026-09-10

The live path was exercised end to end, and the result changed the design:

| Check | Result |
|---|---|
| DNS + TLS to `bhuvan-vec2.nrsc.gov.in` | ✅ reachable (Akamai-fronted GeoServer) |
| `GetMap` with the previously hardcoded layer `india3` | ❌ HTTP 200 + OGC `LayerNotDefined` — **the live path had never once worked** |
| `GetMap` with a real layer (`LULC_BUILTUP`) | ⚠️ HTTP 200 `image/png`, but a **flat single-colour tile, byte-identical for Bhopal and Delhi** |

That second row is the dangerous one. A flat red fill scores **+0.996** on the
brightness index, so naively "fixing" the layer name would have made **every
work in India report the same confident built-up signature** — fabricated
evidence, on every screen.

`_is_degenerate_tile()` now rejects any tile with near-zero per-channel spatial
variance, whatever layer is configured, and the observation becomes
`unavailable` with an honest reason. Verified live: Bhopal and Delhi both
return `unavailable / degenerate_tile`, not a measurement.

**Conclusion:** the public `bhuvan-vec2` endpoint serves *thematic vector*
layers, not per-location imagery. Real scenes need a registered ISRO API key,
which this build does not carry. Until one is provisioned, `fixture` remains
the correct default and a live call honestly reports `unavailable`.

```bash
SATELLITE_ADAPTER=bhuvan uvicorn app.main:app   # live; currently -> unavailable
```

Bhuvan is intermittently slow, so the server caps the call at 8 s. Keep
`fixture` for the offline-hotspot contingency.

## What the app talks to

| Screen | Endpoints |
|---|---|
| Login | `/auth/otp/request`, `/auth/otp/verify`, `/auth/me`, `/auth/refresh` |
| Dashboard | `/analytics/overview`, `/analytics/category-risk`, `/analytics/top-risk`, `/me/dashboard`, `/me/verifications` |
| Works | `/works`, `/map/works` |
| Work detail — Risk | `/works/{code}`, `/works/{code}/risk`, `/works/{code}/risk/recompute` |
| Work detail — Sources | `/works/{code}/verification` |
| Work detail — Evidence | `/works/{code}/evidence` |
| Work detail — Official | `/works/{code}/esakshi`, `/works/{code}/esakshi/verify` |
| Work detail — Satellite | `/works/{code}/satellite/observe`, `/works/{code}/satellite/history` |
| Decisions | `/decisions/queue`, `/decisions/summary`, `/fund-releases/{id}/decision` |
| Field | `/me/verifications`, `/verifications/{id}/start`, `/verifications/{id}/submit`, `/works/{code}/evidence` |
| Reports | `/analytics/*`, `/audit/verify` |
| Rulebook | `/admin/rules` |
| Status strip | `/readyz` |

## Offline behaviour

Field verifications and evidence photos go through an on-disk outbox. Offline,
they queue and replay when the connection returns; the server deduplicates on
`client_uuid`, so a replay can never double-count. The pending count in the app
bar is the real queue depth, and Settings lists each queued item.

Reads are not cached — a screen that cannot reach the server says so rather
than showing stale numbers as if they were current.

## Permissions

| Permission | Why |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | API access, online/offline detection |
| `ACCESS_FINE_LOCATION` | Distance to site, GPS-walk measurement, photo GPS consistency |
| `CAMERA` | Site photography |

Location and camera are optional at runtime: the app degrades to manual entry
and reports "location unavailable" rather than assuming a position.

## Tests

```bash
flutter test
```

Covers the parts where being wrong would mislead an officer: risk-band mapping
against the server's thresholds, money parsing (integer paise, never float),
reason points summing to the score, source-status semantics, and the
network-vs-rejection distinction the outbox depends on.
