# Offline-First Sync Protocol

## Design Principle

Rural India has intermittent connectivity. The app must work fully offline and sync when signal is available.

**The simplification that removes conflict resolution entirely**: everything the field produces is an **append-only immutable event** (evidence, measurements, citizen reports). Immutable facts cannot conflict. Work master data is server-authoritative — officers never edit it.

## Pull

```
GET /api/v1/sync/pull?cursor=42&device_id=abc
```

- `cursor` encodes a global monotonic revision number (from `sync_rev_seq` sequence)
- Trailing watermark: cursor lags 2 seconds behind the DB to prevent skipping late-committing transactions
- Returns changed rows across all syncable tables, plus tombstones (`deleted_at`)
- Response: `{items: [...], next_cursor: 57, server_time: "..."}`

## Push

```
POST /api/v1/sync/push
{
  "device_id": "abc",
  "ops": [
    {"type": "citizen_report", "client_uuid": "...", "data": {...}},
    {"type": "field_verification", "client_uuid": "...", "data": {...}}
  ]
}
```

- Each op has a device-generated `client_uuid` (UUIDv4)
- Server upserts into `client_ops` keyed on `client_uuid`
- **Replay returns the stored original response** — crash-safe, no duplicates
- Per-op savepoints: one bad op doesn't fail the batch
- This is what makes "Pending Sync: 2" trustworthy on the phone

## Decisions Are Online-Only

Fund release decisions require a token minted < 15 minutes ago. You do not disburse public money from a stale offline cache.

**Say this to a judge and watch it land.**

## Syncable Tables

```
works, risk_assessments, verification_sources, field_verifications,
fund_releases, evidence, citizen_reports, decisions, users
```

Each carries a `rev` column stamped by a database trigger (migration 0003). One integer cursor across every table beats per-table timestamps: no clock skew, no equal-timestamp pagination hole.
