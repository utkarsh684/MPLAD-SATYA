"""Citizen verification submissions."""

from __future__ import annotations

from fastapi import APIRouter, Query
from sqlalchemy import select, text
from sqlalchemy.orm import joinedload

from app.deps import CurrentUser, DbSession
from app.models import CitizenReport, Work
from app.risk.service import score_work
from app.schemas import CitizenReportIn, CitizenReportOut, WorkSummary
from app.security import hash_phone
from app.serializers import work_summary

router = APIRouter(prefix="/api/v1/citizen", tags=["citizen"])

NEAREST_WORK_RADIUS_M = 150.0


@router.get("/works/nearby", operation_id="listNearbyWorks", response_model=list[WorkSummary])
def nearby(
    db: DbSession,
    user: CurrentUser,
    lat: float,
    lon: float,
    radius_m: float = Query(500, ge=50, le=5000),
    limit: int = Query(20, ge=1, le=100),
):
    """Geo-fenced feed. ST_DWithin on geography is index-assisted and in metres.

    ST_Distance(...) < 500 on `geometry` would compare DEGREES and would not use
    the GiST index -- silently wrong and a full scan.
    """
    rows = db.execute(
        text(
            """
            SELECT id, ST_Distance(location, ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography)
                   AS distance_m
            FROM works
            WHERE deleted_at IS NULL
              AND ST_DWithin(location, ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography, :r)
            ORDER BY distance_m ASC
            LIMIT :lim
            """
        ),
        {"lat": lat, "lon": lon, "r": radius_m, "lim": limit},
    ).all()

    out = []
    for row in rows:
        work = db.execute(
            select(Work)
            .options(joinedload(Work.district), joinedload(Work.current_assessment))
            .where(Work.id == row.id)
        ).scalar_one()
        out.append(work_summary(work, distance_m=float(row.distance_m)))
    return out


@router.post("/reports", operation_id="createCitizenReport", response_model=CitizenReportOut)
def create_report(body: CitizenReportIn, db: DbSession, user: CurrentUser):
    """Idempotent on client_uuid so an offline queue can replay safely."""
    existing = db.execute(
        select(CitizenReport).where(CitizenReport.client_uuid == body.client_uuid)
    ).scalar_one_or_none()
    if existing:
        return CitizenReportOut(
            id=existing.id, work_id=existing.work_id,
            status=existing.status, created_at=existing.created_at,
        )

    work_id = body.work_id
    if work_id is None:
        # Resolve to the nearest work: a citizen photographs a site, not a row id.
        row = db.execute(
            text(
                """
                SELECT id FROM works
                WHERE deleted_at IS NULL
                  AND ST_DWithin(location,
                        ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography, :r)
                ORDER BY ST_Distance(location,
                        ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography)
                LIMIT 1
                """
            ),
            {"lat": body.lat, "lon": body.lon, "r": NEAREST_WORK_RADIUS_M},
        ).first()
        work_id = row.id if row else None

    report = CitizenReport(
        work_id=work_id,
        reporter_user_id=user.id,
        # Pseudonymised: no report ever renders a citizen's identity.
        phone_hash=hash_phone(user.phone),
        category=body.category,
        verdict=body.verdict,
        description=body.description,
        gps=f"SRID=4326;POINT({body.lon} {body.lat})",
        evidence_ids=body.evidence_ids or [],
        client_uuid=body.client_uuid,
    )
    db.add(report)
    db.flush()

    if work_id:
        work = db.get(Work, work_id)
        if work:
            score_work(db, work, trigger="citizen_report")

    return CitizenReportOut(
        id=report.id, work_id=report.work_id, status=report.status,
        created_at=report.created_at,
    )
