# MPLAD SATYA — backend

Evidence-based audit layer for MPLADS public works. FastAPI + PostgreSQL/PostGIS.

SATYA produces **evidence and a recommendation**. Approval remains an
administrative action by an authorised officer — enforced in code, not just
printed on a screen.

## Run locally

```bash
docker compose up -d                  # PostGIS 16
uv venv --python 3.12 && uv pip install -e ".[dev]"
cp .env.example .env
alembic upgrade head
python -m app.seed.generate --works 2000 --seed 42
uvicorn app.main:app --reload
```

Then open http://localhost:8000/docs

Demo logins (console OTP — the code is printed in the server log and returned
as `debug_code`):

| Phone | Role |
|---|---|
| +919000000001 | mospi_admin |
| +919000000002 | district_officer |
| +919000000003 | field_officer |
| +919000000004 | mp |
| +919000000005 | citizen |

## How scoring works

Additive, with per-category caps, apportioned by largest remainder so the
reasons on screen **sum exactly to the score in the gauge**. Explainability is
arithmetic here, not a post-hoc attribution method bolted onto an opaque model.

```
score = min(100, Σ reason.points)
caps:  rule 40 · anomaly 25 · fraud 35 · field 20 · inefficiency 10
bands: 0–30 green · 31–70 yellow · 71–100 red
```

The full rulebook, the weights and their sha256 digests are served live at
`GET /api/v1/admin/rules`. Every stored assessment records `engine_version`,
`rules_sha256` and the complete `inputs_snapshot`, so a score can be
re-explained months later even after the rules change.

**The weights are an expert prior, not learned parameters.** No labelled
national MPLADS fraud dataset exists. They are tunable per district.

## Deliberate design positions

- **No blockchain.** A single writer has an integrity problem, not a consensus
  problem. `audit_log` is a sha256 hash chain, made physically append-only by a
  `REVOKE` plus a `BEFORE UPDATE OR DELETE` trigger. `GET /api/v1/audit/verify`
  walks it and names the exact break point.
- **Satellite-inconclusive scores zero.** Public imagery (~2.5 m/px) cannot
  resolve a 3 m ward road. Sub-resolution targets return `inconclusive` with a
  stated confidence and raise field-verification priority — they never raise the
  risk score. An unusable sensor must not manufacture suspicion.
- **Citizen reports need corroboration.** Anonymous adverse reports against a
  named contractor are an abuse vector; below the threshold they lower Evidence
  Consistency and trigger verification, but add no points.
- **No vector database.** 64-bit pHash in a signed BIGINT plus four 16-bit band
  columns; pigeonhole candidate generation then exact popcount.
- **Offline data is append-only.** Immutable facts cannot conflict, so there is
  no merge algorithm. Fund-release decisions are online-only: you do not
  disburse public money from a stale offline cache.

## Deployment traps (verified, not guessed)

- Render **free** Postgres expires 30 days after creation and has no backups.
  Use Neon (persistent free tier, PostGIS supported) or pay.
- Render **free** web services cold-start ~50s. `plan: starter` avoids it.
- `pool_pre_ping=True` is mandatory: managed Postgres drops idle connections,
  and without it the first request after a quiet period looks like an outage.
- Alembic `autogenerate` will try to drop PostGIS tables. `alembic/env.py` has
  the `include_object` filter that prevents it.

## Tests

```bash
pytest -q          # 80 tests, no database required
```

The suite pins `MP/2026/1142` at exactly **78** with its five reasons and their
provenance strings. If a refactor moves that number, CI fails before a judge
sees it. The seed generator runs the same assertion and **exits non-zero** if a
planted case drifts, so a build where the demo screen is wrong cannot ship.
