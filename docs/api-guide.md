# API Quick Reference

Base URL: `http://localhost:8000` (dev) or your Render deployment URL.

All authenticated endpoints require `Authorization: Bearer <jwt>` header.

## Authentication Flow

```
1. POST /api/v1/auth/otp/request  {"phone": "+919876543210"}
   → {request_id, expires_in, debug_code (dev only)}

2. POST /api/v1/auth/otp/verify   {"request_id": "...", "phone": "...", "otp": "123456"}
   → {access_token, refresh_token, user}

3. Use access_token as Bearer token for all subsequent requests
```

## Key Endpoints

### Works

```
GET  /api/v1/works?band=red&limit=50&cursor=MP/2026/1142
GET  /api/v1/works/{work_code}
GET  /api/v1/map/works?bbox=77.0,23.0,78.0,24.0
```

### Risk Scoring

```
GET  /api/v1/works/{work_code}/risk
→ {score: 80, band: "red", reasons: [{code, title, points, explanation, provenance}]}

GET  /api/v1/works/{work_code}/verification
→ {sources: [{source: "official_record", status, headline}, ...], consistency_pct}

POST /api/v1/works/{work_code}/risk/recompute
GET  /api/v1/works/{work_code}/risk/history
```

### Evidence Upload

```
POST /api/v1/works/{work_code}/evidence
Content-Type: multipart/form-data
→ file, source, client_uuid, is_mock_location, claimed_accuracy_m

Pipeline: EXIF extract → GPS trust → face blur → pHash → store → rescore
```

### eSAKSHI Integration

```
GET /api/v1/works/{work_code}/esakshi          → official record
GET /api/v1/works/{work_code}/esakshi/verify   → cross-verification
```

### Satellite

```
POST /api/v1/works/{work_code}/satellite/observe  → trigger observation
GET  /api/v1/works/{work_code}/satellite/history   → observation history
```

### Fund Release Decisions

```
GET  /api/v1/decisions/queue                     → pending releases
GET  /api/v1/decisions/summary                   → ₹ totals
POST /api/v1/fund-releases/{id}/decision         → approve/hold
     {action: "approve"|"hold"|"field_review", justification, statutory_ref}
```

### Analytics

```
GET /api/v1/analytics/overview           → totals by band, avg score
GET /api/v1/analytics/category-risk      → risk by work category
GET /api/v1/analytics/district-summary   → per-district aggregates
GET /api/v1/analytics/top-risk?limit=20  → highest risk works
GET /api/v1/analytics/rule-frequency     → how often each rule fires
```

### Offline Sync

```
GET  /api/v1/sync/pull?cursor=42    → changed rows since cursor
POST /api/v1/sync/push              → batch of client ops (idempotent)
```

## Error Format

Every error returns:
```json
{
  "error": {
    "code": "WORK_NOT_FOUND",
    "message": "No work with code MP/2026/9999.",
    "message_key": "work_not_found",
    "request_id": "abc123"
  }
}
```

## Pagination

List endpoints use cursor-based pagination:
```json
{
  "items": [...],
  "next_cursor": "MP/2026/1142",
  "has_more": true
}
```

Pass `next_cursor` as `?cursor=` to get the next page.
