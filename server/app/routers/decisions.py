"""Fund-release decisions (screen 4).

The AI recommendation and the human decision are stored separately and both are
written to the audit chain. "Approval is an administrative action - SATYA
provides evidence, not verdicts" is enforced here, not just printed on a screen.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import joinedload

from app import audit
from app.deps import CurrentUser, DbSession, require_role
from app.errors import ApiError
from app.models import Decision, FieldVerification, FundRelease, RiskAssessment, Work
from app.schemas import DecisionIn, DecisionOut, DecisionSummaryOut, FundReleaseOut, Money
from app.serializers import work_summary

router = APIRouter(
    prefix="/api/v1",
    tags=["decisions"],
    dependencies=[Depends(require_role("district_officer", "mospi_admin"))],
)

ACTION_TO_STATUS = {
    "approve": "approved",
    "hold": "held",
    "partial_release": "partial",
    "field_review": "pending",
    "re_audit": "pending",
}


def _release_out(db, fr: FundRelease) -> FundReleaseOut:
    work = db.execute(
        select(Work)
        .options(joinedload(Work.district), joinedload(Work.current_assessment))
        .where(Work.id == fr.work_id)
    ).scalar_one()
    ra = work.current_assessment
    summary = None
    if ra:
        mismatches = sum(1 for k, v in (ra.subscores or {}).items() if v > 0)
        summary = f"4 sources - {mismatches} signal{'s' if mismatches != 1 else ''}"
    return FundReleaseOut(
        id=fr.id,
        work=work_summary(work),
        installment_no=fr.installment_no,
        tranche_label=fr.tranche_label,
        claimed_amount=Money.of(fr.claimed_amount_paise),
        status=fr.status,
        requested_at=fr.requested_at,
        evidence_summary=summary,
    )


@router.get("/decisions/queue", operation_id="listDecisionQueue",
            response_model=list[FundReleaseOut])
def queue(db: DbSession, user: CurrentUser, limit: int = Query(50, ge=1, le=200)):
    query = (
        select(FundRelease)
        .join(Work, Work.id == FundRelease.work_id)
        .where(FundRelease.status == "pending", Work.deleted_at.is_(None))
    )
    if user.district_id:
        query = query.where(Work.district_id == user.district_id)
    rows = db.execute(query.order_by(FundRelease.requested_at).limit(limit)).scalars().all()
    out = [_release_out(db, fr) for fr in rows]
    out.sort(key=lambda r: -(r.work.risk_score or 0))
    return out


@router.get("/decisions/summary", operation_id="getDecisionSummary",
            response_model=DecisionSummaryOut)
def summary(db: DbSession, user: CurrentUser):
    def total(*statuses: str) -> int:
        q = (
            select(func.coalesce(func.sum(FundRelease.claimed_amount_paise), 0))
            .join(Work, Work.id == FundRelease.work_id)
            .where(FundRelease.status.in_(statuses))
        )
        if user.district_id:
            q = q.where(Work.district_id == user.district_id)
        return int(db.execute(q).scalar_one())

    def count(*statuses: str) -> int:
        q = (
            select(func.count())
            .select_from(FundRelease)
            .join(Work, Work.id == FundRelease.work_id)
            .where(FundRelease.status.in_(statuses))
        )
        if user.district_id:
            q = q.where(Work.district_id == user.district_id)
        return int(db.execute(q).scalar_one())

    return DecisionSummaryOut(
        total_sanctioned=Money.of(total("pending", "approved", "held", "partial")),
        funds_held=Money.of(total("held")),
        approved_for_release=Money.of(total("approved", "partial")),
        pending_review=Money.of(total("pending")),
        counts={
            "pending": count("pending"),
            "held": count("held"),
            "approved": count("approved", "partial"),
        },
    )


@router.post("/fund-releases/{release_id}/decision", operation_id="decideFundRelease",
             response_model=DecisionOut)
def decide(release_id: uuid.UUID, body: DecisionIn, db: DbSession, user: CurrentUser):
    fr = db.get(FundRelease, release_id)
    if fr is None:
        raise ApiError("FUND_RELEASE_NOT_FOUND", "No such fund release.", 404)
    if fr.status != "pending":
        raise ApiError(
            "FUND_RELEASE_ALREADY_DECIDED",
            f"This release is already {fr.status}.",
            409,
            details={"status": fr.status},
        )

    work = db.get(Work, fr.work_id)
    if user.district_id and work.district_id != user.district_id:
        raise ApiError("FORBIDDEN", "This work is outside your district.", 403)

    assessment = db.execute(
        select(RiskAssessment).where(
            RiskAssessment.work_id == work.id, RiskAssessment.is_current.is_(True)
        )
    ).scalar_one_or_none()

    # The gate. Approving a high-risk release requires either ministry authority
    # or a completed field verification -- never a district officer alone acting
    # against a red recommendation.
    if body.action == "approve" and assessment and assessment.band == "red":
        verified = db.execute(
            select(func.count())
            .select_from(FieldVerification)
            .where(
                FieldVerification.work_id == work.id,
                FieldVerification.status == "submitted",
            )
        ).scalar_one()
        if user.role != "mospi_admin" and not verified:
            raise ApiError(
                "HIGH_RISK_APPROVAL_BLOCKED",
                "A high-risk work needs a completed field verification, or ministry "
                "sign-off, before its funds can be released.",
                409,
                details={"risk_score": assessment.score, "band": assessment.band},
            )

    fr.status = ACTION_TO_STATUS[body.action]
    fr.decided_by_user_id = user.id
    fr.decided_at = datetime.now(UTC)
    fr.decision_note = body.remarks
    fr.statutory_ref = body.statutory_ref
    fr.partial_pct = body.partial_pct
    if assessment:
        fr.assessment_id = assessment.id
        fr.gate_band = assessment.band

    decision = Decision(
        fund_release_id=fr.id,
        work_id=work.id,
        officer_user_id=user.id,
        action=body.action,
        justification=body.justification,
        remarks=body.remarks,
        statutory_ref=body.statutory_ref,
        ai_score_at_decision=assessment.score if assessment else None,
        ai_recommendation_at_decision=assessment.recommended_action if assessment else None,
    )
    db.add(decision)
    db.flush()

    entry = audit.append(
        db,
        action=f"fund_release.{body.action}",
        actor_user_id=user.id,
        actor_role=user.role,
        entity_type="fund_releases",
        entity_id=fr.id,
        payload={
            "work_code": work.work_code,
            "amount_paise": fr.claimed_amount_paise,
            "to_status": fr.status,
            "justification": body.justification,
            "ai_score": assessment.score if assessment else None,
            "ai_recommendation": assessment.recommended_action if assessment else None,
        },
    )

    return DecisionOut(
        id=decision.id,
        fund_release_id=fr.id,
        action=decision.action,
        ai_score_at_decision=decision.ai_score_at_decision,
        ai_recommendation_at_decision=decision.ai_recommendation_at_decision,
        created_at=decision.created_at or datetime.now(UTC),
        audit_seq=entry.seq,
    )
