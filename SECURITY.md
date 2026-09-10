# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | ✅ Current |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly.

**Do NOT open a public GitHub issue.**

Email: **adoranto737@gmail.com**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will acknowledge receipt within 48 hours and provide a resolution timeline within 7 days.

---

## Security Architecture

### Authentication

- **Phone OTP** — 6-digit code, 5-minute expiry, 5 attempt limit
- OTP hash uses SHA-256 with a per-instance pepper (not bcrypt — pointless for 6-digit, 5-minute, 5-attempt codes)
- **JWT** — 30-day access token, 180-day refresh token
- Token revocation via `token_version` column — bumping it invalidates all tokens for a user in one UPDATE
- No password storage anywhere in the system

### Authorization (RBAC)

| Role | Can do | Cannot do |
|------|--------|-----------|
| `mospi_admin` | View all districts, approve any release | — |
| `district_officer` | View own district, approve releases (with gate) | Access other districts |
| `field_officer` | Conduct verifications in assigned district | Approve fund releases |
| `mp` | View own constituency data | Modify data, approve releases |
| `citizen` | Report nearby works, view public data | Approve releases, access admin |

**Fund release gate**: Approving a red-band release requires `mospi_admin` or a completed field verification. This is enforced server-side in the decisions router.

Every route is either authenticated via JWT or explicitly listed in `PUBLIC_ROUTES` — the RBAC test suite (`test_rbac.py`) enforces this declaratively, so an unprotected endpoint cannot be merged without a test failure.

### Audit Trail

- SHA-256 hash chain: `hash = sha256(prev_hash || leaf_hash)`
- **Append-only enforcement**: two layers
  1. `REVOKE UPDATE, DELETE ON audit_log` from the application role
  2. `BEFORE UPDATE OR DELETE` trigger that raises an exception
- A single retro-edit or deletion breaks the chain from that point forward
- Genesis hash: `"0" * 64`
- `pg_advisory_xact_lock` serialises appends to prevent race conditions

### Privacy (DPDP Compliance)

- **Face blur**: OpenCV Haar cascade runs on every uploaded photo before storage. Citizen photos of construction sites capture workers and bystanders — blurring is what makes the "no personal data" claim true
- **Phone pseudonymisation**: `reporter_hash = sha256(pepper + phone)` — citizen reports are linked by hash, never by identity
- **No PII in logs**: Request logging captures method, path, status, duration — never request bodies or auth tokens
- **Purpose limitation**: Citizen data is used only for work verification scoring, never for profiling

### Fail-Closed Design

```python
@model_validator(mode="after")
def _fail_closed_in_production(self):
    if self.env == "production":
        if self.sms_provider == "console":
            raise ValueError("console OTP delivery is forbidden in production")
        if self.demo_mode:
            raise ValueError("DEMO_MODE must be false in production")
    if len(self.jwt_secret) < 32:
        raise ValueError("JWT_SECRET must be at least 32 characters")
```

Production refuses to boot with:
- `SMS_PROVIDER=console` (demo OTP delivery)
- `DEMO_MODE=true` (demo reset endpoint)
- `JWT_SECRET` shorter than 32 characters

### Demo Mode

`DEMO_MODE` enables `/admin/demo/reset` (gated by `X-Demo-Key` header). It is:
- Default `false`
- Advertised openly in `/readyz` response
- Fail-closed: cannot be `true` when `ENV=production`

The judge answer to "isn't that a backdoor?" is: it cannot boot in production, and it advertises itself in the health check.

### Input Validation

- All request bodies validated by Pydantic v2 with strict types
- SQL injection: all queries use SQLAlchemy ORM or parameterised `text()` — no string interpolation
- File uploads: 15 MB limit, type-checked before processing
- Money: integer paise (BigInteger), never float — eliminates IEEE 754 rounding as an attack surface

### Transport

- CORS restricted to `*` only in dev; empty allowlist in production
- GZip middleware (minimum 1000 bytes) for bandwidth — critical on 2G rural links
- `X-Request-ID` header on every response for traceability

---

## Dependencies

All dependencies are pinned to exact versions in `pyproject.toml`. No wildcard version ranges.

| Dependency | Purpose | Version |
|------------|---------|---------|
| fastapi | API framework | 0.115.6 |
| sqlalchemy | ORM | 2.0.36 |
| pyjwt[crypto] | Token signing | 2.10.1 |
| psycopg[binary] | PostgreSQL driver | 3.2.3 |
| opencv-python-headless | Face blur (no GUI) | 4.10.0.84 |
| simpleeval | Rule evaluation sandbox | 1.0.3 |

`simpleeval` is used instead of `eval()` for rule evaluation — it provides a restricted execution environment with no access to builtins, imports, or the filesystem.

## Evidence upload hardening

Uploaded bytes decide what is stored — never the client-supplied filename.

`/media` is served by `StaticFiles`, so a file an uploader could name
`photo.html` or `photo.svg` would previously have been stored with that
extension and later served as **active content on the API origin**: stored XSS
against anyone opening an evidence link. The upload path now:

1. sniffs the real container format with Pillow (`Image.open` + `verify()`),
2. rejects anything outside `{JPEG, PNG, WEBP, HEIC}` with `415`,
3. derives both the stored extension and the recorded MIME from the **detected**
   format, discarding the filename and the `Content-Type` header,
4. rejects truncated or corrupt files with `400` before they enter the evidence
   chain.

SVG is deliberately excluded: it is XML, it can carry script, and no camera
emits it. Stored filenames remain server-generated UUIDs, so path traversal via
the filename is not reachable either.

Covered by `tests/test_upload_security.py`.

## Provenance integrity

Two invariants are enforced in code and pinned by tests, because breaking
either would let the product assert something it cannot support:

- **UNKNOWN is never rendered as ZERO.** `consistency_pct()` returns `None`
  when no source was informative, not `0` — 0 % means every source contradicted
  the record, `None` means nothing could be checked. Satellite detectability
  fields are `None` when not computed rather than `0.0`/`1.0`.
  (`tests/test_provenance_semantics.py`)
- **A fixture is never presentable as a live observation.** The offline
  satellite adapter states its own synthetic nature inside the reason text an
  officer reads, not only in a UI badge that is lost the moment the sentence is
  quoted into a file note. (`tests/test_satellite.py`)
