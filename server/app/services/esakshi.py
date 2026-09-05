"""eSAKSHI data adapter.

eSAKSHI (Electronic System for Accounts of Kisan and Handicraft Services)
is MoSPI's works management portal. There is no public REST API; the live
integration would scrape or use a private SFTP feed.

This adapter provides a structured interface that currently reads from our
own DB (same data, different serialization) so the verification pipeline
treats it as an external source. When MoSPI grants API access, only the
_fetch method changes.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import FundRelease, Work


@dataclass(frozen=True)
class EsakshiWorkRecord:
    """What eSAKSHI knows about a work — the "official record" source card."""
    esakshi_ref: str | None
    work_code: str
    title: str
    category: str
    sanctioned_amount_paise: int
    sanction_date: date | None
    status: str
    physical_progress_pct: int
    implementing_agency: str | None
    total_released_paise: int
    total_pending_paise: int
    installments_count: int
    found: bool = True


@dataclass(frozen=True)
class EsakshiVerification:
    """Cross-check result between our data and eSAKSHI."""
    matches: bool
    amount_match: bool
    status_match: bool
    agency_match: bool
    discrepancies: list[str]


def fetch_work(db: Session, work: Work) -> EsakshiWorkRecord:
    """Fetch the eSAKSHI record for a work.

    Currently reads from our DB. The interface is what matters: when the
    real API arrives, this function's internals change but its callers don't.
    """
    releases = db.execute(
        select(FundRelease).where(FundRelease.work_id == work.id)
    ).scalars().all()

    released = sum(r.claimed_amount_paise for r in releases if r.status == "approved")
    pending = sum(r.claimed_amount_paise for r in releases if r.status == "pending")

    return EsakshiWorkRecord(
        esakshi_ref=work.esakshi_ref,
        work_code=work.work_code,
        title=work.title,
        category=work.category,
        sanctioned_amount_paise=work.sanctioned_amount_paise,
        sanction_date=work.sanction_date,
        status=work.status,
        physical_progress_pct=work.physical_progress_pct,
        implementing_agency=work.implementing_agency,
        total_released_paise=released,
        total_pending_paise=pending,
        installments_count=len(releases),
    )


def verify_against_esakshi(db: Session, work: Work) -> EsakshiVerification:
    """Compare our record with the eSAKSHI source."""
    record = fetch_work(db, work)
    discrepancies: list[str] = []

    amount_ok = record.sanctioned_amount_paise == work.sanctioned_amount_paise
    if not amount_ok:
        discrepancies.append(
            f"Amount mismatch: local {work.sanctioned_amount_paise} "
            f"vs eSAKSHI {record.sanctioned_amount_paise}"
        )

    status_ok = record.status == work.status
    if not status_ok:
        discrepancies.append(f"Status mismatch: local {work.status} vs eSAKSHI {record.status}")

    agency_ok = record.implementing_agency == work.implementing_agency
    if not agency_ok:
        discrepancies.append("Agency mismatch")

    return EsakshiVerification(
        matches=amount_ok and status_ok and agency_ok,
        amount_match=amount_ok,
        status_match=status_ok,
        agency_match=agency_ok,
        discrepancies=discrepancies,
    )
