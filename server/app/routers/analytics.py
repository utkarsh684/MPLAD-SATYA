"""Analytics and reporting endpoints for the dashboard."""

from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import func, select

from app.deps import CurrentUser, DbSession
from app.models import (
    Decision,
    Evidence,
    FundRelease,
    RiskAssessment,
    Work,
)

router = APIRouter(prefix="/api/v1/analytics", tags=["analytics"])


@router.get("/overview", operation_id="getAnalyticsOverview")
def overview(db: DbSession, user: CurrentUser):
    """Top-level numbers for the admin dashboard."""
    total = db.execute(
        select(func.count()).select_from(Work).where(Work.deleted_at.is_(None))
    ).scalar_one()

    by_band = dict(
        db.execute(
            select(RiskAssessment.band, func.count())
            .where(RiskAssessment.is_current.is_(True))
            .group_by(RiskAssessment.band)
        ).all()
    )

    avg_score = db.execute(
        select(func.avg(RiskAssessment.score)).where(RiskAssessment.is_current.is_(True))
    ).scalar_one()

    total_sanctioned = db.execute(
        select(func.sum(Work.sanctioned_amount_paise)).where(Work.deleted_at.is_(None))
    ).scalar_one() or 0

    pending_releases = db.execute(
        select(func.count()).select_from(FundRelease).where(FundRelease.status == "pending")
    ).scalar_one()

    total_evidence = db.execute(
        select(func.count()).select_from(Evidence).where(Evidence.deleted_at.is_(None))
    ).scalar_one()

    total_decisions = db.execute(
        select(func.count()).select_from(Decision)
    ).scalar_one()

    return {
        "total_works": total,
        "by_band": {
            "green": by_band.get("green", 0),
            "yellow": by_band.get("yellow", 0),
            "red": by_band.get("red", 0),
        },
        # None when nothing has been scored yet, never 0. A portfolio with no
        # assessments is not a portfolio averaging zero risk, and 0 is the one
        # value a reader would take as "all clear". The client already draws
        # its distribution over the assessed count rather than total_works;
        # this keeps the API telling the same truth to anyone else reading it.
        "average_risk_score": None if avg_score is None else round(float(avg_score), 1),
        "assessed_works": sum(by_band.values()),
        "total_sanctioned_paise": total_sanctioned,
        "pending_fund_releases": pending_releases,
        "total_evidence_items": total_evidence,
        "total_decisions": total_decisions,
    }


@router.get("/category-risk", operation_id="getCategoryRiskDistribution")
def category_risk(db: DbSession, user: CurrentUser):
    """Risk distribution by work category."""
    rows = db.execute(
        select(
            Work.category,
            func.count().label("count"),
            func.avg(RiskAssessment.score).label("avg_score"),
            func.max(RiskAssessment.score).label("max_score"),
        )
        .join(RiskAssessment, Work.current_assessment_id == RiskAssessment.id)
        .where(Work.deleted_at.is_(None))
        .group_by(Work.category)
        .order_by(func.avg(RiskAssessment.score).desc())
    ).all()

    return [
        {
            "category": r.category,
            "count": r.count,
            "avg_score": round(float(r.avg_score), 1) if r.avg_score else 0,
            "max_score": r.max_score or 0,
        }
        for r in rows
    ]


@router.get("/district-summary", operation_id="getDistrictSummary")
def district_summary(db: DbSession, user: CurrentUser):
    """Per-district aggregates."""
    from app.models import District
    rows = db.execute(
        select(
            District.name,
            func.count(Work.id).label("works"),
            # The average covers assessed works only, so the count of those
            # has to travel with it. Reporting "657 works, average risk 6.8"
            # when 50 were assessed states something that is not true.
            func.count(RiskAssessment.id).label("assessed"),
            func.sum(Work.sanctioned_amount_paise).label("total_paise"),
            func.avg(RiskAssessment.score).label("avg_score"),
        )
        .join(Work, Work.district_id == District.id)
        .outerjoin(RiskAssessment, Work.current_assessment_id == RiskAssessment.id)
        .where(Work.deleted_at.is_(None))
        .group_by(District.name)
    ).all()

    return [
        {
            "district": r.name,
            "works": r.works,
            "assessed_works": r.assessed,
            "total_sanctioned_paise": int(r.total_paise or 0),
            # None, not 0. This is an OUTER join: a district whose works have
            # no current assessment yields NULL here, and reporting that as 0
            # would paint an entirely unassessed district as the safest one on
            # the screen.
            "avg_risk_score": (
                round(float(r.avg_score), 1) if r.avg_score is not None else None
            ),
        }
        for r in rows
    ]


@router.get("/top-risk", operation_id="getTopRiskWorks")
def top_risk(db: DbSession, user: CurrentUser, limit: int = 20):
    """Top N highest-risk works."""
    rows = db.execute(
        select(Work.work_code, Work.title, Work.category, RiskAssessment.score, RiskAssessment.band)
        .join(RiskAssessment, Work.current_assessment_id == RiskAssessment.id)
        .where(Work.deleted_at.is_(None))
        .order_by(RiskAssessment.score.desc())
        .limit(limit)
    ).all()

    return [
        {
            "work_code": r.work_code,
            "title": r.title,
            "category": r.category,
            "score": r.score,
            "band": r.band,
        }
        for r in rows
    ]


@router.get("/rule-frequency", operation_id="getRuleFrequency")
def rule_frequency(db: DbSession, user: CurrentUser):
    """How often each rule fires across all current assessments."""
    from app.models import RiskReason
    rows = db.execute(
        select(
            RiskReason.code,
            RiskReason.category,
            func.count().label("fires"),
            func.avg(RiskReason.points).label("avg_points"),
        )
        .join(RiskAssessment, RiskReason.assessment_id == RiskAssessment.id)
        .where(RiskAssessment.is_current.is_(True), RiskReason.points > 0)
        .group_by(RiskReason.code, RiskReason.category)
        .order_by(func.count().desc())
    ).all()

    return [
        {
            "code": r.code,
            "category": r.category,
            "fires": r.fires,
            "avg_points": round(float(r.avg_points), 1),
        }
        for r in rows
    ]
