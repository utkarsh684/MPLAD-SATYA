# Deployment Guide

## Infrastructure

| Component | Service | Plan | Cost |
|-----------|---------|------|------|
| API Server | Render | Starter | $7/mo |
| Database | Neon | Free | $0 |
| Photo Storage | Cloudflare R2 | Free | $0 |
| Push | Firebase FCM | Free | $0 |

**Total: $7/month** for the demo period.

## Render Setup

1. **Connect repo** to Render
2. **Environment**: Docker
3. **Pre-deploy command**: `cd server && alembic upgrade head`
4. **Start command**: `cd server && uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 2`
5. **Health check**: `GET /healthz`

### Environment Variables on Render

```
DATABASE_URL=postgresql://user:pass@host/db?sslmode=require
JWT_SECRET=<random-64-chars>
ENV=staging
SMS_PROVIDER=console
DEMO_MODE=true
DEMO_RESET_KEY=<random-key>
SATELLITE_ADAPTER=fixture
```

## Neon Setup

1. Create a free project at [neon.tech](https://neon.tech)
2. Enable PostGIS: `CREATE EXTENSION IF NOT EXISTS postgis;`
3. Copy the connection string to `DATABASE_URL`
4. Note: Neon auto-suspends after 5 min idle. `pool_pre_ping=True` handles reconnection.

## Seeding

After deploy, seed the demo data:

```bash
# Via Render shell or one-off job
cd server && python -m app.seed.generate --works 2000 --seed 42

# Scoring is the long half. A dropped connection leaves the works in
# place but unscored - re-run this until it reports nothing pending:
python -m app.seed.generate --resume

# After a rule change, an engine fix, or anything that alters how a score
# is computed, the stored assessments are stale - they were correct for
# rules that no longer apply. This recomputes them:
python -m app.seed.generate --rescore
```

`--rescore` supersedes rather than deletes, so assessments computed under the
previous rules stay readable and a score can still be explained as it stood
when a decision was taken. It marks its own work, so an interrupted rescore
resumes rather than starting over.

The seeder:
- Creates 3 districts (Bhopal, Sehore, Raisen)
- Creates 5 demo users with known phone numbers
- Plants 6 specific works with known scores (hero = 80)
- Generates ~1994 ordinary works with realistic cost variance
- Scores all works
- Runs a self-check asserting planted scores match

## Demo Reset

Between judging rounds:
```bash
curl -X POST https://your-app.onrender.com/api/v1/admin/demo/reset \
  -H "X-Demo-Key: your-demo-key"
```

## Wifi Contingency

The highest-value item on the deployment checklist:

```bash
# On the demo laptop
docker compose up -d
alembic upgrade head
python -m app.seed.generate --works 2000 --seed 42
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Phone joins the laptop's hotspot. **Rehearse on the hotspot, not on venue wifi.**

## Readiness Verification

```bash
# After deploy
curl https://your-app.onrender.com/readyz | python -m json.tool

# Expected:
{
  "status": "ok",
  "engine_version": "satya-risk/1.0.0",
  "rules_sha256": "...",
  "demo_mode": true,
  "env": "staging",
  "db": "ok",
  "postgis": "3.4 ..."
}
```
