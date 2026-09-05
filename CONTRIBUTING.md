# Contributing to MPLAD SATYA

Thank you for considering contributing to SATYA. This document explains how to get started.

## Development Setup

```bash
cd server
pip install uv
uv sync

cp .env.example .env
# Set DATABASE_URL and JWT_SECRET (≥32 chars)

# Run tests (no database needed for most)
pytest tests/ -q

# Start the server
uvicorn app.main:app --reload --port 8000
```

## Code Standards

### Python

- **Python 3.12+**, type hints everywhere
- **Ruff** for linting and formatting — `ruff check app/ tests/`
- No comments unless the WHY is non-obvious
- Money is **integer paise** (`BigInteger`), never float

### Architecture Rules

1. **One `models.py`** — all 16 tables in one file. No repository pattern, no service-per-entity
2. **Risk engine is pure** — `assess(facts)` takes a dict, returns a result. No DB, no network, no clock
3. **Append-only facts** — evidence, measurements, citizen reports are immutable events. No conflict resolution needed
4. **Decisions are online-only** — you do not disburse public money from a stale offline cache

### Testing

```bash
pytest tests/ -q              # All tests
pytest tests/ -k "risk" -v    # Risk engine tests only
```

**Key invariants** (these must never break):
- Hero work MP/2026/1142 = score 78 with exactly 5 reasons
- Points always sum to score (Hamilton apportionment)
- Every route is authenticated or explicitly in `PUBLIC_ROUTES`
- Audit chain detects tamper

### Adding a Rule

1. Add the rule to `server/app/risk/rules.json`
2. Ensure the fact it references is computed in `server/app/risk/facts.py`
3. Add a reachability test case in `tests/test_risk_engine.py::REACHABILITY_OVERRIDES`
4. Run `pytest tests/test_risk_engine.py -v` to verify

### Adding an Endpoint

1. Add the route to the appropriate router in `server/app/routers/`
2. Use `CurrentUser` dependency for auth (or add to `PUBLIC_ROUTES` in `test_rbac.py` with a reason)
3. Add Pydantic models to `server/app/schemas.py`
4. Set `operation_id` explicitly for clean Dart client generation
5. Run `pytest tests/test_rbac.py` to verify auth coverage

## Commit Messages

- Short, imperative: "Add evidence upload pipeline" not "Added evidence upload pipeline"
- No generated-by or co-authored-by lines
- Reference the component: "risk: add cost z-score rule" or "satellite: wire Bhuvan WMS adapter"

## Pull Requests

- One logical change per PR
- All tests must pass: `pytest tests/ -q`
- All lint must pass: `ruff check app/ tests/`
- Include a brief description of what changed and why

## What NOT to Add

- No blockchain — the hash chain provides the same guarantee with zero infrastructure
- No Redis/Celery/Kafka — volume is ~140 works/day, not 140/second
- No BERT/Prophet/CLIP — no labelled dataset exists to train them
- No microservices — one process, thin routers, a `risk/` package
- No feature flags or backwards-compatibility shims — just change the code
- No generated documentation files — the code and tests are the documentation

## Questions?

Open an issue or reach out to the team.
