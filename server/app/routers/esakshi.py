"""eSAKSHI integration endpoints.

Provides cross-verification between SATYA data and the eSAKSHI records,
and exposes the eSAKSHI view of a work for the official record source card.
"""

from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import select

from app.deps import CurrentUser, DbSession
from app.errors import ApiError
from app.models import Work
from app.services.esakshi import fetch_work, verify_against_esakshi

router = APIRouter(prefix="/api/v1", tags=["esakshi"])


def _load(db, work_code: str) -> Work:
    work = db.execute(
        select(Work).where(Work.work_code == work_code, Work.deleted_at.is_(None))
    ).scalar_one_or_none()
    if work is None:
        raise ApiError("WORK_NOT_FOUND", f"No work with code {work_code}.", 404)
    return work


@router.get("/works/{work_code:path}/esakshi", operation_id="getEsakshiRecord")
def get_esakshi_record(work_code: str, db: DbSession, user: CurrentUser):
    """The eSAKSHI record for a work — what the official system says."""
    work = _load(db, work_code)
    record = fetch_work(db, work)
    return {
        "esakshi_ref": record.esakshi_ref,
        "work_code": record.work_code,
        "title": record.title,
        "category": record.category,
        "sanctioned_amount_paise": record.sanctioned_amount_paise,
        "sanction_date": str(record.sanction_date) if record.sanction_date else None,
        "status": record.status,
        "physical_progress_pct": record.physical_progress_pct,
        "implementing_agency": record.implementing_agency,
        "total_released_paise": record.total_released_paise,
        "total_pending_paise": record.total_pending_paise,
        "installments_count": record.installments_count,
        "source": "esakshi",
        "found": record.found,
    }


@router.get("/works/{work_code:path}/esakshi/verify", operation_id="verifyEsakshi")
def verify_esakshi(work_code: str, db: DbSession, user: CurrentUser):
    """Cross-verify our data against the eSAKSHI record."""
    work = _load(db, work_code)
    result = verify_against_esakshi(db, work)
    return {
        "matches": result.matches,
        "amount_match": result.amount_match,
        "status_match": result.status_match,
        "agency_match": result.agency_match,
        "discrepancies": result.discrepancies,
    }
