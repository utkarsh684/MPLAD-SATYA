<div align="center">

# MPLAD SATYA

### Systematic Audit & Transparent Yardstick Application

**SIH 2026 · PS SIH26102 · Ministry of Statistics & Programme Implementation**

Evidence-based anomaly detection and risk triage for India's MPLAD scheme — ₹2,715 Cr/year across 543 constituencies.

**SATYA provides evidence, not verdicts. Approval remains an administrative action by an authorised officer.**

[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+PostGIS-4169E1?logo=postgresql&logoColor=white)](https://postgresql.org)
[![Tests](https://img.shields.io/badge/Tests-151_passing-brightgreen)]()
[![Endpoints](https://img.shields.io/badge/API-40_endpoints-blue)]()
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

</div>

---

## What SATYA Does

SATYA is an evidence-based audit layer for the MPLAD scheme. It scores every public work 0–100 by cross-checking four verification sources, and surfaces the reasoning to the officer who decides.

**The score is an investigation priority, not a fraud probability.** A work scoring 78 is not "78% likely to be fraudulent" — it means several checks disagreed with the record, and it should be looked at before a work scoring 20.

SATYA never approves, holds or rejects a fund release. It assembles evidence and recommends; the decision recorded against a release belongs to an authorised officer, with their justification, written to a tamper-evident log alongside the score that was on screen at the time.

> Not every source is independent of SATYA, and the app says which. See [Data provenance](#data-provenance--what-is-real-and-what-is-not).

```
eSAKSHI Record + Satellite Imagery + Citizen Reports + Field Measurement
    ↓                  ↓                   ↓                ↓
Cross-verify     Visual imagery     Mismatch cluster    GPS-walk/tape
    ↓                  ↓                   ↓                ↓
              ┌────────────────────────────────────┐
              │     SATYA Risk Engine (33 rules)   │
              │   Additive scoring, per-category   │
              │   caps, Hamilton apportionment     │
              └──────────┬─────────────────────────┘
                         │
              Score 0-100 + ordered reasons
                         │
         ┌───────────────┼───────────────┐
     0-30 GREEN      31-70 YELLOW     71-100 RED
 Eligible for     Send for       Hold for field
   release          review          verification
```


---

## Data provenance — what is real, and what is not

Every figure SATYA shows is traceable to one of these. Nothing is simulated
without being labelled as simulated, in the API **and** on screen.

| Source | State | Independent of SATYA? | Notes |
|---|---|---|---|
| **OpenStreetMap** tiles | 🟢 LIVE | Yes | Raster tiles, attribution rendered per licence |
| **Nominatim** geocoding | 🟢 LIVE | Yes | Place search, throttled to 1 req/s with an identifying User-Agent per their usage policy. Never used for bulk geocoding |
| **Field evidence** | 🔵 LOCAL | n/a — it is our own data | Real uploads: sha256, EXIF, GPS trust, face blur, pHash, near-duplicate search |
| **CPWD DSR 2024** | 🔵 OFFICIAL | Yes | Published schedule of rates, transcribed with item-level references (`CPWD DSR 2024 Vol-I item 16.42`). CPWD publishes no API |
| **ISRO Bhuvan** | 🟢 LIVE *when configured* / 🟠 FIXTURE | Yes | Real WMS `GetMap` under `SATELLITE_ADAPTER=bhuvan`; a deterministic offline fixture otherwise. **Every observation is stamped LIVE or FIXTURE in the UI** |
| **eSAKSHI** | 🟠 DEMO ADAPTER | **No** | MoSPI publishes no public REST API |

### On eSAKSHI

The adapter is shaped like an external source but currently reads the **same
database**. It exercises the comparison pipeline end to end; it does **not**
independently corroborate anything. The Official tab states this on screen, so
no officer can mistake a pipeline check for external confirmation. When MoSPI
grants access, only the adapter's `_fetch` method changes.

We do not claim "connected to the eSAKSHI API", because we are not.

### On satellite — what it can and cannot say

Two claims were deliberately removed from this feature because the data does
not support them:

- **It does not compute NDBI.** NDBI is `(SWIR − NIR) / (SWIR + NIR)`. Bhuvan's
  public WMS returns a *rendered visual PNG* with no SWIR and no NIR band, so a
  true built-up index cannot be derived from it. What is computed is a red–green
  brightness contrast, named `brightness_index` throughout and labelled "not
  NDBI" in the UI. It is a weak corroborating hint, nothing more.
- **It does not detect change.** `observe()` fetches one tile. A road built
  twenty years ago produces the same signal as one built last month, so a
  single-date observation cannot establish that work was carried out. A live
  observation therefore tops out at `inconclusive`, and `is_temporal_comparison`
  is `false`. Establishing change needs a before/after pair, which the free
  endpoint does not expose.

Verdict states: `match` · `mismatch` · `inconclusive` · `unavailable`.
A WMS timeout or an undecodable tile is **`unavailable`** — a service outage,
never a finding about the work. An `inconclusive` reading contributes **zero**
points and can never raise a score.

Most MPLADS works are physically smaller than the sensor can resolve, so
`inconclusive` is the *expected* result, not a failure.

### UNKNOWN is never ZERO

Two values that a naive implementation collapses, and that SATYA keeps apart:

| | Meaning |
|---|---|
| `0` | A measurement was taken and the answer is zero |
| `null` | No measurement was possible |

Enforced in code and pinned by tests:
- `consistency_pct` returns `null` when no source was informative — `0%` would
  claim every source *contradicted* the record.
- Satellite detectability fields stay `null` when not computed, never `0.0`/`1.0`.
- A district with no assessments reports `avg_risk_score: null`, so it is not
  painted green as the safest district on the screen.

---

## Architecture

```mermaid
graph TB
    subgraph Client["Flutter Mobile App"]
        A[Offline-First Sync] --> B[AR Measurement]
        A --> C[Photo Upload + EXIF]
        A --> D[Citizen Reports]
    end

    subgraph API["FastAPI Backend"]
        E[Auth · OTP + JWT]
        F[Works · CRUD + Map]
        G[Risk Engine · 33 Rules]
        H[Evidence Pipeline]
        I[Sync · Pull/Push]
        J[Decisions · Fund Release]
        K[Analytics · 5 endpoints]
    end

    subgraph Services["Core Services"]
        L[pHash · Near-duplicate detection]
        M[EXIF · GPS trust + Face blur]
        N[Anomaly · IsolationForest + Z-score]
        O[Satellite · Bhuvan WMS + detectability]
        P[eSAKSHI · adapter, not independent]
        Q[Audit · SHA-256 hash chain]
    end

    subgraph Data["PostgreSQL 16 + PostGIS"]
        R[(Works · 2000+ rows)]
        S[(Evidence · pHash + bands)]
        T[(Risk Assessments · immutable)]
        U[(Audit Log · append-only)]
    end

    Client -->|HTTPS + JWT| API
    API --> Services
    Services --> Data
    H --> L & M & N
    G --> O & P
    J --> Q
```

---

## Risk Scoring Model

The score is **additive with per-category caps**, not a weighted average. Each reason contributes points, and the displayed reasons sum **exactly** to the gauge number via Hamilton apportionment — explainability is arithmetic you can check, not a SHAP plot you have to trust.

The caps and band thresholds are **expert-assigned priors, published in the rulebook and tunable per district** — not values learned from data, because no labelled MPLADS fraud dataset exists to learn them from. Saying so is the defensible position; calling them "learned" is not.

```mermaid
graph LR
    subgraph Layers["Scoring Layers · Total Cap 100"]
        R["Rule Layer<br/>Cap: 40 pts<br/>12 rules"]
        A["Anomaly Layer<br/>Cap: 25 pts<br/>6 rules"]
        F["Fraud Layer<br/>Cap: 35 pts<br/>8 rules"]
        FI["Field Layer<br/>Cap: 20 pts<br/>4 rules"]
        I["Inefficiency Layer<br/>Cap: 10 pts<br/>3 rules"]
    end

    R --> SC["Score = min(100, Σ capped points)"]
    A --> SC
    F --> SC
    FI --> SC
    I --> SC

    SC --> B1["0-30 · GREEN<br/>Eligible for release"]
    SC --> B2["31-70 · YELLOW<br/>Send for review"]
    SC --> B3["71-100 · RED<br/>Hold for field verification"]

    B1 --> H["👤 Authorised officer decides"]
    B2 --> H
    B3 --> H
```

### Example: Hero Work MP/2026/1142

| # | Reason | Points | Category |
|---|--------|--------|----------|
| 1 | Cost 2.9× CPWD benchmark | 24 | Anomaly |
| 2 | Geo-duplicate 8m from similar work | 18 | Fraud |
| 3 | Photo 95% match with another work | 16 | Fraud |
| 4 | Field measurement 52m vs 100m sanctioned | 15 | Field |
| 5 | Timeline 52 days overdue | 5 | Inefficiency |
| | **Total** | **78** | **HIGH RISK** |

The 33 rules are declarative JSON, evaluated by `simpleeval`. Every assessment stores `engine_version` + `rules_sha256` + `inputs_snapshot` for full reproducibility.

---

## 4-Source Verification Pipeline

```mermaid
flowchart LR
    subgraph Sources["Four Verification Sources"]
        S1["📄 Official Record<br/>eSAKSHI adapter<br/>(not independent)"]
        S2["🛰️ Satellite<br/>Bhuvan WMS · visual"]
        S3["👥 Citizen Reports<br/>Mismatch cluster"]
        S4["📏 Field Measurement<br/>GPS-walk/tape vs sanctioned"]
    end

    S1 --> V["Evidence<br/>Consistency %"]
    S2 --> V
    S3 --> V
    S4 --> V

    V --> D{"Consistency<br/>≥ 70%?"}
    D -->|Yes| G["✅ Sources agree"]
    D -->|No| R["⚠️ Discrepancy<br/>triggers investigation"]
```

**Design principle**: Inconclusive sources (e.g. satellite can't resolve a 3m road at 2.5 m/px) are excluded from both numerator and denominator — "the sensor cannot see this" is not evidence of wrongdoing.

---

## Evidence Upload Pipeline

```mermaid
flowchart TD
    Upload["📸 Photo Upload"] --> EXIF["EXIF Extraction<br/>GPS · Device · Timestamp"]
    EXIF --> Trust["GPS Trust Score<br/>0-100 with flags"]
    Trust --> Blur["Face Blur<br/>OpenCV Haar · DPDP"]
    Blur --> Hash["pHash Compute<br/>64-bit DCT hash"]
    Hash --> Bands["4 × 16-bit Bands<br/>Pigeonhole index"]
    Bands --> Dup{"Near-duplicate<br/>search"}
    Dup -->|Hamming ≤ 3| Flag["🚨 95%+ match flagged"]
    Dup -->|No match| Store["Store · Rescore"]
    Flag --> Store
```

**GPS Trust Flags**: `mock_location_flag`, `gps_offset_{N}m`, `suspiciously_precise_gps`, `no_capture_timestamp`, `no_device_info`

---

## API Surface — 40 Endpoints

| Group | Endpoints | Auth |
|-------|-----------|------|
| **Auth** | OTP request/verify, refresh, logout, me | Public (OTP) |
| **Works** | List, detail, map (GeoJSON bbox), search | JWT |
| **Risk** | Score breakdown, 4-source verification, history, recompute | JWT |
| **Evidence** | Upload (full pipeline), list per work | JWT |
| **eSAKSHI** | Official record, cross-verification | JWT |
| **Satellite** | Trigger observation, history | JWT |
| **Dashboard** | Field counters, priority list, start/submit verification | JWT |
| **Decisions** | Fund release queue, summary (₹ totals), approve/hold | JWT + Role |
| **Citizen** | Nearby works, submit report | JWT |
| **Sync** | Pull (trailing watermark), push (idempotent) | JWT |
| **Analytics** | Overview, category-risk, district, top-risk, rule frequency | JWT |
| **Admin** | Rules (transparent), audit verify, stats, demo reset | Mixed |
| **Ops** | `/healthz` (liveness), `/readyz` (version + PostGIS) | Public |

Full OpenAPI spec at `/docs` when the server is running.

---

## Data Model

```mermaid
erDiagram
    WORKS ||--o{ EVIDENCE : has
    WORKS ||--o{ RISK_ASSESSMENTS : scored_by
    WORKS ||--o{ FUND_RELEASES : releases
    WORKS ||--o{ FIELD_VERIFICATIONS : verified_by
    WORKS ||--o{ CITIZEN_REPORTS : reported_on
    WORKS ||--o{ SATELLITE_OBSERVATIONS : observed_by
    WORKS ||--o{ VERIFICATION_SOURCES : "4 sources"
    RISK_ASSESSMENTS ||--o{ RISK_REASONS : contains
    FUND_RELEASES ||--o{ DECISIONS : decided_by
    USERS ||--o{ FIELD_VERIFICATIONS : conducts
    USERS ||--o{ DECISIONS : makes

    WORKS {
        uuid id PK
        string work_code UK
        string category
        bigint sanctioned_amount_paise
        geography location
        uuid current_assessment_id FK
    }

    RISK_ASSESSMENTS {
        uuid id PK
        int score
        string band
        jsonb inputs_snapshot
        string engine_version
        bool is_current
    }

    EVIDENCE {
        uuid id PK
        bigint phash
        int gps_trust
        int faces_blurred
        string sha256
    }

    AUDIT_LOG {
        bigint seq PK
        string prev_hash
        string hash
        string leaf_hash
    }
```

**Money is integer PAISE everywhere.** ₹15.60 Lakh = `156_000_000`. Never float.

---

## Security Model

See [SECURITY.md](SECURITY.md) for full details.

| Layer | Mechanism |
|-------|-----------|
| Auth | Phone OTP → JWT (30-day, revocable via `token_version`) |
| RBAC | `require_role()` on sensitive routes; citizen can't approve releases |
| Audit | SHA-256 hash chain, append-only trigger + REVOKE on audit_log |
| Privacy | DPDP: face blur on ingest, `reporter_hash` pseudonymisation |
| Uploads | Bytes are sniffed, not trusted: allowlist `{JPEG,PNG,WEBP,HEIC}`, extension and MIME derived from the **detected** format — never the filename |
| Fail-closed | Production refuses to boot with `SMS_PROVIDER=console` or `DEMO_MODE=true` |

---

## Quick Start

```bash
# Clone and setup
git clone https://github.com/utkarsh684/MPLAD-SATYA.git
cd MPLAD-SATYA/server

# Install dependencies
pip install uv
uv sync

# Configure
cp .env.example .env
# Edit .env: DATABASE_URL, JWT_SECRET (≥32 chars)

# Database
docker compose up -d db
alembic upgrade head
python -m app.seed.generate --works 2000 --seed 42

# Run
uvicorn app.main:app --reload --port 8000

# Test
pytest tests/ -q
# 151 passed
```

### Demo Logins

| Phone | Role | Scope |
|-------|------|-------|
| +919000000001 | MoSPI Admin | All districts |
| +919000000002 | District Officer | Bhopal |
| +919000000003 | Field Officer | Bhopal |
| +919000000004 | MP | Bhopal constituency |
| +919000000005 | Citizen | Nearby works |

SMS provider is `console` in dev — the OTP prints to stdout.

---

## Project Structure

```
server/
├── app/
│   ├── main.py              # FastAPI app, lifespan, CORS, error handlers
│   ├── config.py             # Pydantic settings, fail-closed validators
│   ├── db.py                 # SQLAlchemy engine (pool_pre_ping for Neon)
│   ├── models.py             # 16 tables, one file (no circular imports)
│   ├── schemas.py            # Pydantic v2 request/response models
│   ├── deps.py               # current_user, require_role() dependencies
│   ├── security.py           # JWT, OTP hash, phone pseudonymisation
│   ├── errors.py             # Single error envelope
│   ├── serializers.py        # ORM → response conversion
│   ├── satellite.py          # FixtureAdapter + BhuvanAdapter (WMS + detectability)
│   ├── audit.py              # Hash chain: append, verify, canonical JSON
│   ├── routers/
│   │   ├── auth.py           # OTP flow, refresh, logout
│   │   ├── works.py          # List, detail, map, risk, verification
│   │   ├── evidence.py       # Upload pipeline (EXIF→pHash→blur→store)
│   │   ├── esakshi.py        # Official record cross-verification
│   │   ├── satellite.py      # Trigger observation, history
│   │   ├── dashboard.py      # Field officer counters + priority list
│   │   ├── decisions.py      # Fund release queue + approve/hold
│   │   ├── citizen.py        # Nearby works, submit report
│   │   ├── sync.py           # Offline pull/push with idempotency
│   │   ├── analytics.py      # Overview, category-risk, top-risk
│   │   └── admin.py          # Rules, audit verify, demo reset
│   ├── risk/
│   │   ├── engine.py         # Pure scoring function, 33 rules
│   │   ├── rules.json        # Declarative rulebook
│   │   ├── weights.yaml      # Category caps, band thresholds
│   │   ├── facts.py          # DB → facts dict (z-score, IForest, etc.)
│   │   ├── consistency.py    # 4-source verdicts + consistency %
│   │   ├── service.py        # Orchestration: facts → assess → persist
│   │   ├── signals.py        # Reason/AssessmentResult dataclasses
│   │   └── format.py         # Template rendering (₹ lakh/crore, etc.)
│   ├── services/
│   │   ├── phash.py          # 64-bit DCT hash, pigeonhole lookup
│   │   ├── anomaly.py        # IsolationForest + z-score
│   │   ├── exif.py           # EXIF extraction, GPS trust, face blur
│   │   ├── esakshi.py        # eSAKSHI adapter
│   │   ├── storage.py        # Local/R2 file storage
│   │   └── push.py           # FCM HTTP v1 notifications
│   └── seed/
│       ├── generate.py       # Deterministic seeder (--seed 42)
│       └── fixtures/         # Planted cases + CPWD rates
├── alembic/                  # 3 migrations (schema, audit trigger, sync rev)
├── tests/                    # 151 tests, 11 files
├── Dockerfile
├── render.yaml
└── pyproject.toml

src/                              # Flutter client (Android · iOS · Web)
├── lib/
│   ├── core/
│   │   ├── config.dart           # Build-time API endpoint (--dart-define)
│   │   ├── routing/              # go_router + auth redirect guard
│   │   ├── services/             # GPS, geocoding (Nominatim), device id
│   │   └── theme/                # Palette, theme, RiskBand (server bands)
│   ├── data/
│   │   ├── api/                  # HTTP client, JWT refresh, error envelope
│   │   ├── models/               # Mirror server/app/schemas.py exactly
│   │   └── repositories/         # One per domain
│   ├── providers/                # Auth, outbox, server status, theme, locale
│   ├── features/                 # One folder per screen
│   └── widgets/
│       ├── provenance.dart       # SourceState + chips (single vocabulary)
│       ├── profile_menu.dart     # Top-right identity control
│       └── async_view.dart       # Loading / error / empty, one place
├── assets/logo.png
└── test/                         # Model parsing, provenance, null semantics
```


---

## Mobile app (Flutter)

The officer-facing client lives in `src/`. It reads live data from the API on
every screen — there is no bundled sample data and no offline demo mode baked
into the app.

```bash
cd src
flutter pub get

# Android emulator against a local server (10.0.2.2 is the host machine)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Physical phone over USB, no network involved
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://localhost:8000

# Release APK
flutter build apk --release --dart-define=API_BASE_URL=https://<host>
```

The API endpoint is a **build-time constant** — there is no in-app server
picker, and the endpoint plus live server status is shown on the login screen
and in Settings, so a device pointed at the wrong host is obvious immediately.

**Release builds require HTTPS.** `network_security_config.xml` denies cleartext
in release, so a signed APK cannot send a session token or a site photograph
over plaintext HTTP. Debug builds override this for local development.

### Navigation

The bottom bar is **entirely operational** — it answers *"what do I need to
investigate about this work?"*. Identity and configuration live behind the
top-right profile control instead, so they never compete with the working path.

```
Work detail tabs   Risk · Sources · Evidence · Official · Satellite
Profile menu       Profile · Appearance · Settings · Help · About · Sign out
```

### Offline behaviour

Field verifications and evidence photographs go through an on-disk outbox.
Offline they queue and replay when the connection returns; the server
deduplicates on `client_uuid`, so a replay can never double-count. The pending
count beside the profile avatar is the real queue depth.

Reads are **not** cached — a screen that cannot reach the server says so rather
than presenting stale numbers as current.

### Progressive disclosure

An officer should not have to parse a brightness index to learn that satellite
could not resolve an asset. Screens lead with the plain-language answer and fold
the technical working behind *View technical details*:

```
Detectability   BELOW SENSOR LIMIT
Observation     Cannot confirm from a single image
Source          ● FIXTURE · Offline fixture
                Independent of SATYA   Yes

View technical details ▸   brightness contrast, ratio, method, provider
```

---

## Deployment

| Component | Service | Cost |
|-----------|---------|------|
| API | Render Starter | $7/mo |
| Database | Neon PostgreSQL (PostGIS) | Free |
| Photos | Cloudflare R2 (10 GB) | Free |
| **Total** | | **$7/mo** |

```bash
# Deploy
render deploy  # or git push to connected repo

# Pre-deploy runs alembic migrate automatically (render.yaml)
# Health check: GET /healthz
```

---

## Testing

### Backend — 151 tests

```bash
cd server
pytest -q                                # All 151
ruff check .                             # Lint

pytest tests/test_risk_engine.py         # Golden hero = 78 · band boundaries
pytest tests/test_upload_security.py     # Stored-XSS / file-type rejection
pytest tests/test_provenance_semantics.py# UNKNOWN is never ZERO
pytest tests/test_satellite.py           # Detectability, LIVE vs FIXTURE, failure states
pytest tests/test_rbac.py                # Every route auth'd or explicitly public
pytest tests/test_audit_canonical.py     # Pinned digests, tamper detection
pytest tests/test_phash.py               # Pigeonhole, signed roundtrip
```

### Mobile

```bash
cd src && flutter analyze && flutter test
```

**Key invariants tested:**
- Hero work `MP/2026/1142` scores exactly **78** with 5 specific reasons — CI
  fails before a judge sees a drift
- Reason points always sum to the score (Hamilton apportionment, 400 random works)
- Band boundaries exact at `0·1·30·31·70·71·99·100`
- Every rule is reachable — no dead rules
- Every route is authenticated or explicitly public
- Audit chain detects a single-bit tamper
- pHash signed↔unsigned roundtrip (2000 random hashes)
- **An inconclusive satellite reading adds zero points**
- **A single-pass observation can never return `match`**
- **A WMS outage is `unavailable`, never a finding about the work**
- **`consistency_pct` is `null`, not `0`, when no source was informative**
- **HTML/SVG/PDF/ELF uploads are rejected; the stored extension comes from
  sniffed bytes, never the filename**


---

## Known limitations

Stated plainly, because a limitation a judge discovers is worth far less than
one you declared first.

| Limitation | Status |
|---|---|
| **eSAKSHI is not an independent source** | No public REST API exists. The adapter reads our own database and the UI says so. Pipeline is ready; the integration is not |
| **Satellite cannot confirm most MPLADS works** | Cartosat resolves ~2.5 m; a ward drain is ~1 m. `inconclusive` is the expected verdict and adds zero points |
| **Satellite cannot detect change** | Single-date imagery only. Establishing that work happened needs a before/after pair the free WMS does not expose |
| **`brightness_index` is not a remote-sensing index** | It is a red–green contrast over a rendered visual tile, used only as a weak hint |
| **No labelled fraud dataset** | Thresholds are expert priors, not learned parameters. Precision/recall against real outcomes is unmeasured |
| **Anomaly ≠ fraud** | Terrain, haulage distance, phased works and genuine repeat designs all produce the same signals as misuse |
| **Citizen reports are unweighted by reputation** | A coordinated group could file matching reports. Mitigated only by cross-source consistency today |
| **GPS can be spoofed** | Mock-location is detected and flagged into the trust score, but a determined spoof on a rooted device is not fully defeated |
| **Tokens in `SharedPreferences`** | Readable on a rooted device. `flutter_secure_storage` is the upgrade path; access tokens are short-lived |
| **APK not yet built in this environment** | The Flutter toolchain is not installed here, so `flutter analyze` / `flutter test` / `flutter build apk` have not been run. Verified by static review only |

### What would move each of these

Most are integration or data-access limits rather than engineering gaps — the
adapters, the null semantics and the provenance vocabulary are all already in
place, so an authorised eSAKSHI feed or a licensed before/after imagery source
is a swap of one method, not a rewrite.

---

## Design Decisions

| Decision | Why |
|----------|-----|
| Additive scoring, not weighted average | Reasons on screen sum to the gauge number — arithmetic explainability |
| 33 JSON rules + simpleeval, not ML classifier | No labelled fraud dataset exists; rules cite specific guideline clauses |
| pHash with pigeonhole bands, not vector DB | 64-bit hash + 4 btree lookups beats a 500 MB FAISS index at 2000 works |
| Integer paise, never float | ₹15.60L = 156,000,000 paise. Float arithmetic on money is a compliance bug |
| Hash chain, not blockchain | Same tamper-evidence guarantee, zero infrastructure, better demo |
| Append-only facts, no conflict resolution | Immutable events can't conflict — no merge algorithm to write or defend |
| Inconclusive satellite = 0 points | A sensor that can't see must never manufacture suspicion |
| Decisions stored with `ai_score_at_decision` | "Is the AI deciding?" → No. The human decision and the AI recommendation are separate columns |

---

## References

- [MPLADS Guidelines 2023](https://mplads.gov.in) — Annex-II (prohibited works), Annex-IIA (admissible works)
- [eSAKSHI Portal](https://mplads.mospi.gov.in) — Digital end-to-end MPLAD management
- [CAG Performance Audit Reports](https://cag.gov.in) — Irregular clubbing ₹3.21 Cr, UC violations
- [CPWD Delhi Schedule of Rates 2023](https://cpwd.gov.in) — Benchmark rates for cost comparison
- [Bhuvan WMS](https://bhuvan.nrsc.gov.in) — ISRO satellite imagery layers
- [PFMS](https://pfms.nic.in) — Public Financial Management System for TSA/Hybrid releases

---

## License

[MIT](LICENSE)

---

<div align="center">

**SIH 2026 · Team SATYA Coders · NIT Hamirpur**

*"SATYA provides evidence, not verdicts. Approval is an administrative action by an authorised officer."*

</div>
