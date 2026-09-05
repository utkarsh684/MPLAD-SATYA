"""Works listing, detail, map feed, and the risk/verification screens."""

from __future__ import annotations

from fastapi import APIRouter, Query
from sqlalchemy import select, text
from sqlalchemy.orm import joinedload

from app.deps import CurrentUser, DbSession
from app.errors import ApiError
from app.models import RiskAssessment, VerificationSource, Work
from app.risk.service import score_work
from app.schemas import (
    Page,
    RiskAssessmentOut,
    SourceCardOut,
    VerificationOut,
    WorkDetail,
    WorkSummary,
)
from app.serializers import assessment_out, work_detail, work_summary

router = APIRouter(prefix="/api/v1", tags=["works"])


def _scoped(query, user):
    """Role scoping applied server-side. The client never sends a filter it
    could widen."""
    if user.role in ("district_officer", "field_officer") and user.district_id:
        query = query.where(Work.district_id == user.district_id)
    return query


def _load(db, work_code: str) -> Work:
    work = db.execute(
        select(Work)
        .options(joinedload(Work.district), joinedload(Work.current_assessment))
        .where(Work.work_code == work_code, Work.deleted_at.is_(None))
    ).scalar_one_or_none()
    if work is None:
        raise ApiError("WORK_NOT_FOUND", f"No work with code {work_code}.", 404)
    return work


@router.get("/works", operation_id="listWorks", response_model=Page[WorkSummary])
def list_works(
    db: DbSession,
    user: CurrentUser,
    band: str | None = None,
    status: str | None = None,
    category: str | None = None,
    q: str | None = None,
    limit: int = Query(50, ge=1, le=200),
    cursor: str | None = None,
):
    query = (
        select(Work)
        .options(joinedload(Work.district), joinedload(Work.current_assessment))
        .where(Work.deleted_at.is_(None))
    )
    query = _scoped(query, user)
    if status:
        query = query.where(Work.status == status)
    if category:
        query = query.where(Work.category == category)
    if q:
        query = query.where(Work.title.ilike(f"%{q}%") | Work.work_code.ilike(f"%{q}%"))
    if band:
        query = query.join(
            RiskAssessment, Work.current_assessment_id == RiskAssessment.id
        ).where(RiskAssessment.band == band)
    if cursor:
        query = query.where(Work.work_code > cursor)

    rows = db.execute(query.order_by(Work.work_code).limit(limit + 1)).scalars().unique().all()
    has_more = len(rows) > limit
    rows = rows[:limit]
    return Page[WorkSummary](
        items=[work_summary(w) for w in rows],
        next_cursor=rows[-1].work_code if rows and has_more else None,
        has_more=has_more,
    )


@router.get("/works/{work_code:path}/risk", operation_id="getWorkRisk",
            response_model=RiskAssessmentOut)
def get_risk(work_code: str, db: DbSession, user: CurrentUser):
    """The risk-breakdown screen: score, band, and the ordered reason list."""
    work = _load(db, work_code)
    assessment = work.current_assessment
    if assessment is None:
        assessment = score_work(db, work, trigger="on_demand")
    return assessment_out(assessment, work)


@router.get("/works/{work_code:path}/verification", operation_id="getWorkVerification",
            response_model=VerificationOut)
def get_verification(work_code: str, db: DbSession, user: CurrentUser):
    """The 4-source screen."""
    work = _load(db, work_code)
    if work.current_assessment is None:
        score_work(db, work, trigger="on_demand")
        db.refresh(work)

    sources = db.execute(
        select(VerificationSource).where(VerificationSource.work_id == work.id)
    ).scalars().all()
    order = {"official_record": 0, "satellite": 1, "citizen": 2, "field": 3}
    sources.sort(key=lambda s: order.get(s.source, 9))

    ra = work.current_assessment
    return VerificationOut(
        work=work_summary(work),
        score=ra.score if ra else None,
        band=ra.band if ra else None,
        consistency_pct=ra.consistency_pct if ra else None,
        sources=[SourceCardOut.model_validate(s) for s in sources],
    )


@router.post("/works/{work_code:path}/risk/recompute", operation_id="recomputeWorkRisk",
             response_model=RiskAssessmentOut)
def recompute(work_code: str, db: DbSession, user: CurrentUser):
    work = _load(db, work_code)
    assessment = score_work(db, work, trigger="manual")
    return assessment_out(assessment, work)


@router.get("/works/{work_code:path}/risk/history", operation_id="getWorkRiskHistory",
            response_model=list[RiskAssessmentOut])
def history(work_code: str, db: DbSession, user: CurrentUser):
    """Score timeline. Assessments are immutable, so history is free -- and
    watching a score fall after a re-measurement is a strong demo beat."""
    work = _load(db, work_code)
    rows = db.execute(
        select(RiskAssessment)
        .where(RiskAssessment.work_id == work.id)
        .order_by(RiskAssessment.computed_at.desc())
    ).scalars().all()
    return [assessment_out(a, work) for a in rows]


@router.get("/works/{work_code:path}", operation_id="getWork", response_model=WorkDetail)
def get_work(work_code: str, db: DbSession, user: CurrentUser):
    return work_detail(_load(db, work_code))


@router.get("/map/works", operation_id="listMapWorks", response_model=list[WorkSummary])
def map_works(
    db: DbSession,
    user: CurrentUser,
    bbox: str | None = Query(None, description="minLon,minLat,maxLon,maxLat"),
    limit: int = Query(2000, ge=1, le=2000),
):
    query = (
        select(Work)
        .options(joinedload(Work.district), joinedload(Work.current_assessment))
        .where(Work.deleted_at.is_(None))
    )
    query = _scoped(query, user)
    if bbox:
        try:
            min_lon, min_lat, max_lon, max_lat = (float(x) for x in bbox.split(","))
        except ValueError as exc:
            raise ApiError("BBOX_INVALID", "bbox must be minLon,minLat,maxLon,maxLat", 400) from exc
        query = query.where(
            text(
                "ST_Intersects(works.location::geometry, "
                "ST_MakeEnvelope(:min_lon,:min_lat,:max_lon,:max_lat,4326))"
            ).bindparams(min_lon=min_lon, min_lat=min_lat, max_lon=max_lon, max_lat=max_lat)
        )
    rows = db.execute(query.limit(limit)).scalars().unique().all()
    return [work_summary(w) for w in rows]
