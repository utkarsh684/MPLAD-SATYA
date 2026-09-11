"""FastAPI application factory."""

from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app import errors
from app.config import settings
from app.db import engine
from app.risk.engine import ENGINE_VERSION, load_rulebook
from app.routers import (
    admin,
    analytics,
    auth,
    citizen,
    dashboard,
    decisions,
    esakshi,
    evidence,
    satellite,
    sync,
    works,
)

logging.basicConfig(
    level=settings.log_level,
    format='{"ts":"%(asctime)s","level":"%(levelname)s","logger":"%(name)s","msg":"%(message)s"}',
)
log = logging.getLogger("satya")


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_rulebook()  # fail fast on a malformed rulebook, not on first request
    if settings.demo_mode:
        log.warning("DEMO_MODE is ON - /admin/demo/reset is reachable")
    yield


app = FastAPI(
    title="MPLAD SATYA API",
    version="0.1.0",
    description=(
        "Evidence-based audit layer for MPLADS public works.\n\n"
        "SATYA produces evidence and a risk recommendation. "
        "Approval remains an administrative action by an authorised officer."
    ),
    lifespan=lifespan,
    docs_url="/docs",
    openapi_url="/openapi.json",
)

# Biggest bandwidth win in the whole API for one line: a works page compresses
# roughly 8x, which on a 2G rural link is 40s versus 5s.
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.env != "production" else [],
    allow_methods=["*"],
    allow_headers=["*"],
)

errors.install(app)

for _router in (
    auth, works, dashboard, decisions, citizen, sync,
    admin, evidence, esakshi, satellite, analytics,
):
    app.include_router(_router.router)


_media = Path(settings.media_root)
_media.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=str(_media)), name="media")


@app.middleware("http")
async def request_context(request: Request, call_next):
    rid = request.headers.get("X-Request-ID") or errors.new_request_id()
    request.state.request_id = rid
    started = time.perf_counter()
    response = await call_next(request)
    duration_ms = round((time.perf_counter() - started) * 1000, 1)
    response.headers["X-Request-ID"] = rid
    log.info(
        "%s %s -> %s (%sms) rid=%s",
        request.method, request.url.path, response.status_code, duration_ms, rid,
    )
    return response


@app.get("/", tags=["ops"], operation_id="serviceIndex", summary="Service index")
def index():
    """What this service is, and where to go next.

    Without this the base URL answered a bare JSON 404, which reads as a
    broken deployment to anyone who opens the link before finding /docs.
    Deliberately DB-free, like /healthz: the index must answer even when
    Postgres is unreachable.
    """
    return {
        "service": "MPLAD SATYA API",
        "description": (
            "Evidence-based audit layer for MPLADS public works. "
            "Provides evidence and a risk recommendation; approval remains an "
            "administrative action by an authorised officer."
        ),
        "version": app.version,
        "docs": "/docs",
        "openapi": "/openapi.json",
        "health": "/healthz",
        "readiness": "/readyz",
        "rulebook": "/api/v1/admin/rules",
        "api_prefix": "/api/v1",
        "source": "https://github.com/utkarsh684/MPLAD-SATYA",
    }


@app.get("/healthz", tags=["ops"], operation_id="healthz", summary="Liveness")
def healthz():
    """Liveness only. Deliberately does NOT touch the database.

    A health check that queries Postgres turns a two-second DB blip into a
    platform-initiated restart: a self-inflicted outage on top of a transient one.
    """
    return {"status": "ok", "version": app.version}


@app.get("/readyz", tags=["ops"], operation_id="readyz", summary="Readiness")
def readyz():
    """Readiness, for humans. Reports what rulebook this instance is running."""
    _, _, rules_sha, weights_sha = load_rulebook()
    out = {
        "status": "ok",
        "engine_version": ENGINE_VERSION,
        "rules_sha256": rules_sha,
        "weights_sha256": weights_sha,
        "demo_mode": settings.demo_mode,   # never hide the flag
        "env": settings.env,
    }
    try:
        with engine.connect() as conn:
            out["db"] = "ok"
            out["postgis"] = conn.execute(text("SELECT postgis_version()")).scalar_one()
    except Exception as exc:  # noqa: BLE001 - readiness must report, not raise
        out["status"] = "degraded"
        out["db"] = f"error: {type(exc).__name__}"
    return out
