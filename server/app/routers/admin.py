"""Operational and transparency endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy import func, select

from app import audit
from app.config import settings
from app.deps import DbSession, require_role
from app.errors import ApiError
from app.models import RiskAssessment, Work
from app.risk.engine import _RULES_PATH, _WEIGHTS_PATH, load_rulebook
from app.schemas import AuditVerifyOut

router = APIRouter(prefix="/api/v1", tags=["admin"])


@router.get("/admin/rules", operation_id="getRulebook", summary="The entire rulebook")
def rulebook():
    """Radical transparency: the full rulebook, weights and their digests.

    A system that can state the exact hash of the rules that produced a score
    reads as engineered rather than assembled -- and lets a judge audit the
    logic without reading the source.
    """
    import json

    import yaml

    rules, weights, rules_sha, weights_sha = load_rulebook()
    return {
        "engine_rules_sha256": rules_sha,
        "weights_sha256": weights_sha,
        "rule_count": len(rules),
        "weights": weights,
        "rules": json.loads(_RULES_PATH.read_text()),
        "weights_yaml": yaml.safe_load(_WEIGHTS_PATH.read_text()),
    }


@router.get("/audit/verify", operation_id="verifyAuditChain", response_model=AuditVerifyOut)
def verify_chain(db: DbSession, start: int = Query(1, ge=1), end: int | None = None):
    """Walk the hash chain and recompute every link. Names the exact break point."""
    return AuditVerifyOut(**audit.verify(db, start=start, end=end))


@router.get("/admin/stats", operation_id="getStats",
            dependencies=[Depends(require_role("mospi_admin", "district_officer"))])
def stats(db: DbSession):
    bands = dict(
        db.execute(
            select(RiskAssessment.band, func.count())
            .where(RiskAssessment.is_current.is_(True))
            .group_by(RiskAssessment.band)
        ).all()
    )
    return {
        "works": db.execute(
            select(func.count()).select_from(Work).where(Work.deleted_at.is_(None))
        ).scalar_one(),
        "assessments": db.execute(
            select(func.count()).select_from(RiskAssessment)
            .where(RiskAssessment.is_current.is_(True))
        ).scalar_one(),
        "bands": {"green": bands.get("green", 0), "yellow": bands.get("yellow", 0),
                  "red": bands.get("red", 0)},
    }


@router.post("/admin/demo/reset", operation_id="resetDemoData")
def demo_reset(db: DbSession, x_demo_key: str = Header(default="")):
    """Restore the seeded dataset between judging rounds.

    404s entirely unless DEMO_MODE is on, so a curious judge cannot discover and
    trigger it against a real deployment.
    """
    if not settings.demo_mode:
        raise ApiError("NOT_FOUND", "Not Found", 404)
    if not settings.demo_reset_key or x_demo_key != settings.demo_reset_key:
        raise ApiError("FORBIDDEN", "Invalid demo key.", 403)

    from app.seed.generate import reseed

    counts = reseed(db)
    return {"status": "reset", **counts}
