"""Offline-first delta sync.

Design note: everything the field produces (verifications, citizen reports,
evidence) is modelled as APPEND-ONLY IMMUTABLE FACTS. Immutable facts cannot
conflict, so there is no merge algorithm to write and none to defend. Work
master data is server-authoritative; the client never writes it.

Fund-release decisions are deliberately NOT syncable: you do not disburse public
money from a stale offline cache.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Query
from sqlalchemy import select, text

from app.deps import CurrentUser, DbSession
from app.models import (
    CitizenReport,
    Evidence,
    FieldVerification,
    FundRelease,
    RiskAssessment,
    VerificationSource,
    Work,
)
from app.schemas import SyncOpResult, SyncPullOut, SyncPushIn, SyncPushOut

router = APIRouter(prefix="/api/v1/sync", tags=["sync"])

# Served in this order so a client can insert without violating foreign keys.
PULL_ORDER = [
    ("works", Work),
    ("risk_assessments", RiskAssessment),
    ("verification_sources", VerificationSource),
    ("field_verifications", FieldVerification),
    ("fund_releases", FundRelease),
    ("evidence", Evidence),
    ("citizen_reports", CitizenReport),
]

# A commit can land with a lower `rev` than one already visible, so serving
# right up to the newest row can skip records. Trailing the high-water mark by
# two seconds closes that hole; the client is offline for hours, so a two-second
# delay is invisible.
WATERMARK_LAG_SECONDS = 2


def _row_to_dict(obj) -> dict:
    out: dict = {}
    for col in obj.__table__.columns:
        name = col.name
        if name in ("location", "gps", "centroid", "last_location", "boundary"):
            continue  # geography columns are sent as lat/lon below
        value = getattr(obj, name, None)
        out[name] = str(value) if hasattr(value, "hex") or isinstance(value, datetime) else value
    return out


@router.get("/pull", operation_id="syncPull", response_model=SyncPullOut)
def pull(
    db: DbSession,
    user: CurrentUser,
    cursor: int = Query(0, ge=0),
    limit: int = Query(500, ge=1, le=2000),
):
    # Trailing high-water mark. A transaction that started earlier can commit
    # LATER with a lower `rev`, so serving right up to the newest row would let
    # a client advance past a record it never saw. Excluding rows written in the
    # last couple of seconds closes that hole. The client is offline for hours,
    # so a two-second delay is invisible.
    cutoff = datetime.now(UTC) - timedelta(seconds=WATERMARK_LAG_SECONDS)

    entities: dict[str, list[dict]] = {}
    max_rev = cursor
    remaining = limit

    for name, model in PULL_ORDER:
        if remaining <= 0:
            entities[name] = []
            continue
        query = (
            select(model)
            .where(model.rev > cursor, model.updated_at <= cutoff)
            .order_by(model.rev)
            .limit(remaining)
        )
        # Role scoping applied server-side; the client cannot widen its own view.
        if model is Work and user.district_id and user.role != "mospi_admin":
            query = query.where(Work.district_id == user.district_id)

        rows = db.execute(query).scalars().unique().all()
        entities[name] = [_row_to_dict(r) for r in rows]
        remaining -= len(rows)
        for r in rows:
            if r.rev and r.rev > max_rev:
                max_rev = r.rev

    return SyncPullOut(
        cursor=max_rev,
        has_more=remaining <= 0,
        server_time=datetime.now(UTC),
        entities=entities,
    )


@router.post("/push", operation_id="syncPush", response_model=SyncPushOut)
def push(body: SyncPushIn, db: DbSession, user: CurrentUser):
    """Per-op results, never all-or-nothing.

    One malformed row from a bad app build must not block an officer's other
    nineteen legitimate submissions forever.
    """
    from app.routers.citizen import create_report
    from app.routers.dashboard import submit as submit_verification
    from app.schemas import CitizenReportIn, FieldVerificationSubmitIn

    results: list[SyncOpResult] = []

    for op in body.ops:
        savepoint = db.begin_nested()
        try:
            if op.type == "field_verification.submit":
                payload = dict(op.payload)
                verification_id = payload.pop("verification_id")
                parsed = FieldVerificationSubmitIn(client_uuid=op.client_uuid, **payload)
                outcome = submit_verification(verification_id, parsed, db, user)
                savepoint.commit()
                results.append(
                    SyncOpResult(
                        client_uuid=op.client_uuid,
                        status="duplicate" if outcome.get("status") == "duplicate" else "applied",
                        server_id=outcome.get("verification_id"),
                    )
                )
            elif op.type == "citizen_report.create":
                parsed = CitizenReportIn(client_uuid=op.client_uuid, **op.payload)
                outcome = create_report(parsed, db, user)
                savepoint.commit()
                results.append(
                    SyncOpResult(
                        client_uuid=op.client_uuid, status="applied", server_id=outcome.id
                    )
                )
            else:
                savepoint.rollback()
                results.append(
                    SyncOpResult(
                        client_uuid=op.client_uuid,
                        status="rejected",
                        error_code="UNKNOWN_OP_TYPE",
                        message=f"Unsupported operation '{op.type}'.",
                    )
                )
        except Exception as exc:  # noqa: BLE001 - one bad op must not fail the batch
            savepoint.rollback()
            results.append(
                SyncOpResult(
                    client_uuid=op.client_uuid,
                    status="rejected",
                    error_code=getattr(exc, "code", "OP_FAILED"),
                    message=str(exc)[:200],
                )
            )

    cursor = db.execute(text("SELECT COALESCE(last_value, 0) FROM sync_rev_seq")).scalar_one()
    return SyncPushOut(cursor=cursor, results=results)
