# Changelog

All notable changes to the SATYA backend.

## [0.1.0] — 2026-09-05

### Added
- **Risk Engine**: 33 declarative rules across 5 categories (rule, anomaly, fraud, field, inefficiency)
- **Additive scoring** with Hamilton apportionment — displayed reasons sum exactly to the gauge number
- **Evidence upload pipeline**: EXIF extraction → GPS trust scoring → face blur (OpenCV) → pHash → storage
- **pHash near-duplicate detection**: 64-bit DCT hash with pigeonhole banded lookup (no vector DB)
- **IsolationForest + z-score** anomaly detection per category+district
- **Satellite verification**: FixtureAdapter (demo) + BhuvanAdapter (live WMS + NDBI)
- **eSAKSHI adapter**: official record cross-verification
- **4-source verification**: official record, satellite, citizen, field — with evidence consistency %
- **Offline sync**: append-only immutable events, global monotonic rev sequence, trailing watermark
- **Auth**: Phone OTP with fail-closed production validator, JWT with token_version revocation
- **RBAC**: 5 roles (mospi_admin, district_officer, field_officer, mp, citizen) with server-side scoping
- **Audit chain**: SHA-256 hash chain, append-only trigger + REVOKE, advisory lock serialisation
- **40 API endpoints**: works, risk, evidence, eSAKSHI, satellite, dashboard, decisions, citizen, sync, analytics, admin
- **Analytics**: overview, category-risk, district-summary, top-risk, rule-frequency endpoints
- **FCM push notifications** scaffold
- **Deterministic seeder**: 2000 works (seed=42), 6 planted cases, self-check assertion
- **110 tests**: golden score test, Hamilton invariant, pHash pigeonhole, RBAC coverage, audit tamper detection
- **Demo mode**: fail-closed (can't boot in production), advertised in /readyz
- **Privacy**: DPDP face blur, phone pseudonymisation, no PII in logs

### Infrastructure
- PostgreSQL 16 + PostGIS + GeoAlchemy2
- Neon (free tier, PostGIS, never expires) for database
- Cloudflare R2 (10 GB free) for photo storage
- Render Starter ($7/mo) for API
- 3 Alembic migrations (schema, audit trigger, sync rev sequence)
