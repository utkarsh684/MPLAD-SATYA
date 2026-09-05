"""Satellite verification endpoint — triggers a live or fixture observation."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter
from geoalchemy2.shape import to_shape
from sqlalchemy import select

from app.config import settings
from app.deps import CurrentUser, DbSession
from app.errors import ApiError
from app.models import SatelliteObservation, Work
from app.risk.service import score_work
from app.satellite import get_adapter

router = APIRouter(prefix="/api/v1", tags=["satellite"])


@router.post(
    "/works/{work_code:path}/satellite/observe",
    operation_id="triggerSatelliteObservation",
)
def trigger_observation(work_code: str, db: DbSession, user: CurrentUser):
    """Trigger a satellite observation for a work.

    Uses the configured adapter (fixture for demo, bhuvan for live).
    Stores the result and recomputes risk.
    """
    work = db.execute(
        select(Work).where(Work.work_code == work_code, Work.deleted_at.is_(None))
    ).scalar_one_or_none()
    if work is None:
        raise ApiError("WORK_NOT_FOUND", f"No work with code {work_code}.", 404)

    try:
        point = to_shape(work.location)
        lat, lon = point.y, point.x
    except Exception as exc:
        raise ApiError("NO_LOCATION", "Work has no valid location.", 400) from exc

    adapter = get_adapter(settings.satellite_adapter)
    result = adapter.observe(category=work.category, lat=lat, lon=lon)

    obs = SatelliteObservation(
        work_id=work.id,
        capture_date=date.today(),
        provider=getattr(adapter, "provider", "unknown"),
        resolution_m=result.resolution_m,
        ndbi_delta=result.ndbi_delta,
        status=result.status,
        confidence=result.confidence,
        method=result.method,
        min_detectable_m2=result.min_detectable_m ** 2,
        target_footprint_m2=result.target_dimension_m ** 2,
        reason=result.reason,
        raw=result.raw,
    )
    db.add(obs)
    db.flush()

    score_work(db, work, trigger="satellite_observation")
    db.commit()

    return {
        "status": result.status,
        "confidence": result.confidence,
        "method": result.method,
        "resolution_m": result.resolution_m,
        "min_detectable_m": result.min_detectable_m,
        "target_dimension_m": result.target_dimension_m,
        "detectability_ratio": result.detectability_ratio,
        "reason": result.reason,
        "ndbi_delta": result.ndbi_delta,
        "adapter": settings.satellite_adapter,
    }


@router.get("/works/{work_code:path}/satellite/history", operation_id="getSatelliteHistory")
def satellite_history(work_code: str, db: DbSession, user: CurrentUser):
    """All satellite observations for a work, newest first."""
    work = db.execute(
        select(Work).where(Work.work_code == work_code, Work.deleted_at.is_(None))
    ).scalar_one_or_none()
    if work is None:
        raise ApiError("WORK_NOT_FOUND", f"No work with code {work_code}.", 404)

    rows = db.execute(
        select(SatelliteObservation)
        .where(SatelliteObservation.work_id == work.id)
        .order_by(SatelliteObservation.capture_date.desc())
    ).scalars().all()

    return [
        {
            "id": str(o.id),
            "capture_date": str(o.capture_date),
            "provider": o.provider,
            "resolution_m": o.resolution_m,
            "status": o.status,
            "confidence": float(o.confidence),
            "method": o.method,
            "reason": o.reason,
            "ndbi_delta": o.ndbi_delta,
            "created_at": o.created_at.isoformat() if o.created_at else None,
        }
        for o in rows
    ]
