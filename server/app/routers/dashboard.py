"""Field officer dashboard and assignment queue (screen 1)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, text
from sqlalchemy.orm import joinedload

from app.deps import CurrentUser, DbSession, require_role
from app.errors import ApiError
from app.models import FieldVerification, RiskAssessment, Work
from app.risk.service import score_work
from app.schemas import AssignmentOut, FieldDashboardOut, FieldVerificationSubmitIn
from app.serializers import work_summary

router = APIRouter(prefix="/api/v1", tags=["dashboard"])

OPEN = ("assigned", "in_progress")


@router.get("/me/dashboard", operation_id="getFieldDashboard", response_model=FieldDashboardOut)
def dashboard(db: DbSession, user: CurrentUser):
    base = select(func.count()).select_from(FieldVerification).where(
        FieldVerification.officer_user_id == user.id,
        FieldVerification.status.in_(OPEN),
    )
    assigned = db.execute(base).scalar_one()

    now = datetime.now(UTC)
    end_of_day = now.replace(hour=23, minute=59, second=59)
    due_today = db.execute(base.where(FieldVerification.due_at <= end_of_day)).scalar_one()

    high_risk = db.execute(
        select(func.count())
        .select_from(FieldVerification)
        .join(Work, Work.id == FieldVerification.work_id)
        .join(RiskAssessment, Work.current_assessment_id == RiskAssessment.id)
        .where(
            FieldVerification.officer_user_id == user.id,
            FieldVerification.status.in_(OPEN),
            RiskAssessment.band == "red",
        )
    ).scalar_one()

    # pending_sync is deliberately null: the server cannot know what is sitting
    # in a phone's outbox. The client fills it in.
    return FieldDashboardOut(
        assigned=assigned, due_today=due_today, high_risk=high_risk, pending_sync=None
    )


@router.get("/me/verifications", operation_id="listMyVerifications",
            response_model=list[AssignmentOut])
def my_verifications(
    db: DbSession,
    user: CurrentUser,
    lat: float | None = None,
    lon: float | None = None,
    limit: int = Query(20, ge=1, le=100),
):
    """Priority queue: highest risk first, then soonest due."""
    rows = db.execute(
        select(FieldVerification)
        .where(
            FieldVerification.officer_user_id == user.id,
            FieldVerification.status.in_(OPEN),
        )
        .order_by(FieldVerification.due_at)
        .limit(limit)
    ).scalars().all()

    out: list[AssignmentOut] = []
    for fv in rows:
        work = db.execute(
            select(Work)
            .options(joinedload(Work.district), joinedload(Work.current_assessment))
            .where(Work.id == fv.work_id)
        ).scalar_one()

        distance_m = None
        if lat is not None and lon is not None:
            distance_m = db.execute(
                text(
                    "SELECT ST_Distance(location, "
                    "ST_SetSRID(ST_MakePoint(:lon,:lat),4326)::geography) "
                    "FROM works WHERE id = :id"
                ),
                {"lat": lat, "lon": lon, "id": work.id},
            ).scalar_one()

        out.append(
            AssignmentOut(
                id=fv.id,
                work=work_summary(work, distance_m=distance_m),
                status=fv.status,
                assigned_at=fv.assigned_at,
                due_at=fv.due_at,
            )
        )

    # Highest risk first, then soonest due -- matches the priority list on screen.
    out.sort(key=lambda a: (-(a.work.risk_score or 0), a.due_at))
    return out


@router.post("/verifications/{verification_id}/start", operation_id="startVerification",
             response_model=AssignmentOut)
def start(verification_id: uuid.UUID, db: DbSession, user: CurrentUser):
    fv = db.get(FieldVerification, verification_id)
    if fv is None or fv.officer_user_id != user.id:
        raise ApiError("VERIFICATION_NOT_FOUND", "No such assignment.", 404)
    if fv.status == "assigned":
        fv.status = "in_progress"
        fv.started_at = datetime.now(UTC)
    work = db.execute(
        select(Work)
        .options(joinedload(Work.district), joinedload(Work.current_assessment))
        .where(Work.id == fv.work_id)
    ).scalar_one()
    return AssignmentOut(
        id=fv.id, work=work_summary(work), status=fv.status,
        assigned_at=fv.assigned_at, due_at=fv.due_at,
    )


@router.post(
    "/verifications/{verification_id}/submit",
    operation_id="submitVerification",
    dependencies=[Depends(require_role("field_officer", "district_officer", "mospi_admin"))],
)
def submit(
    verification_id: uuid.UUID,
    body: FieldVerificationSubmitIn,
    db: DbSession,
    user: CurrentUser,
):
    """Idempotent on client_uuid so an offline queue can replay safely."""
    existing = db.execute(
        select(FieldVerification).where(FieldVerification.client_uuid == body.client_uuid)
    ).scalar_one_or_none()
    if existing is not None and existing.status == "submitted":
        return {"status": "duplicate", "verification_id": str(existing.id)}

    fv = db.get(FieldVerification, verification_id)
    if fv is None or fv.officer_user_id != user.id:
        raise ApiError("VERIFICATION_NOT_FOUND", "No such assignment.", 404)

    fv.status = "submitted"
    fv.submitted_at = datetime.now(UTC)
    fv.client_uuid = body.client_uuid
    fv.measured_value = body.measured_value
    fv.measured_unit = body.measured_unit
    fv.measure_method = body.measure_method
    fv.measure_accuracy_m = body.measure_accuracy_m
    fv.observed_status = body.observed_status
    fv.notes = body.notes
    fv.evidence_ids = body.evidence_ids or []
    if body.lat is not None and body.lon is not None:
        fv.gps = f"SRID=4326;POINT({body.lon} {body.lat})"
    db.flush()

    work = db.get(Work, fv.work_id)
    assessment = score_work(db, work, trigger="field_submitted")
    return {
        "status": "applied",
        "verification_id": str(fv.id),
        "risk_score": assessment.score,
        "risk_band": assessment.band,
    }
