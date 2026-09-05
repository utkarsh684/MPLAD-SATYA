"""Build the facts dict for a work.

This is the ONLY module in `risk/` that touches a Session. Keeping it separate
is what makes `assess()` a pure function, which in turn is what makes golden
tests and assessment replay possible.

Every value is a JSON-serialisable primitive, and anything unknown is None
rather than a sentinel: a rule must never fire because data was missing.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.models import (
    BenchmarkRate,
    CitizenReport,
    Evidence,
    FieldVerification,
    SatelliteObservation,
    Work,
)
from app.services import phash as phash_svc

# Scheme constants. Kept here (not in rules.json) because they are facts about
# the scheme, not scoring policy.
TENDER_THRESHOLD_PAISE = 25_00_000 * 100      # Rs 25 lakh
WORK_CEILING_PAISE = 1_00_00_000 * 100        # Rs 1 crore per work
PROHIBITED_CATEGORIES: set[str] = set()       # populated from annex_ii.yaml
GEO_DUPLICATE_RADIUS_M = 10.0
SIMILAR_WORK_RADIUS_M = 50.0


def _today() -> date:
    return datetime.now(UTC).date()


def _days_between(a: date | None, b: date | None) -> int | None:
    if a is None or b is None:
        return None
    return (b - a).days


def _benchmark(db: Session, work: Work) -> BenchmarkRate | None:
    return db.execute(
        select(BenchmarkRate)
        .where(BenchmarkRate.category == work.category)
        .order_by(BenchmarkRate.effective_from.desc())
        .limit(1)
    ).scalar_one_or_none()


def _nearest_similar_work(db: Session, work: Work) -> tuple[float | None, str | None]:
    """Closest same-category work. PostGIS ST_DWithin on geography = metres."""
    row = db.execute(
        text(
            """
            SELECT w.work_code,
                   ST_Distance(w.location, :loc) AS distance_m
            FROM works w
            WHERE w.id <> :work_id
              AND w.category = :category
              AND w.deleted_at IS NULL
              AND ST_DWithin(w.location, :loc, :radius)
            ORDER BY distance_m ASC
            LIMIT 1
            """
        ),
        {
            "loc": work.location,
            "work_id": work.id,
            "category": work.category,
            "radius": SIMILAR_WORK_RADIUS_M,
        },
    ).first()
    return (float(row.distance_m), row.work_code) if row else (None, None)


def _photo_reuse(db: Session, work: Work) -> tuple[float | None, str | None]:
    """Best perceptual-hash match against evidence on any OTHER work."""
    ours = db.execute(
        select(Evidence)
        .where(Evidence.work_id == work.id, Evidence.phash.isnot(None))
    ).scalars().all()

    best_similarity: float | None = None
    best_code: str | None = None

    for ev in ours:
        value = phash_svc.PhashValue(phash_svc.to_unsigned(ev.phash))
        rows = db.execute(
            text(phash_svc.NEAR_DUPLICATE_SQL),
            phash_svc.near_duplicate_params(value, work.id),
        ).all()
        for r in rows:
            sim = phash_svc.similarity(int(r.distance))
            if best_similarity is None or sim > best_similarity:
                best_similarity = sim
                other = db.get(Work, r.work_id)
                best_code = other.work_code if other else None
    return best_similarity, best_code


def build_facts(db: Session, work: Work) -> dict:
    """Assemble every input the rulebook can reference."""
    today = _today()

    bench = _benchmark(db, work)
    benchmark_total_paise = None
    cost_ratio = None
    unit_rate_ratio = None
    if bench and work.sanctioned_qty:
        qty = float(work.sanctioned_qty)
        benchmark_total_paise = int(bench.rate_paise * float(bench.region_factor) * qty)
        if benchmark_total_paise > 0:
            cost_ratio = work.sanctioned_amount_paise / benchmark_total_paise
            unit_rate_ratio = cost_ratio

    nearest_m, nearest_code = _nearest_similar_work(db, work)
    photo_sim, photo_code = _photo_reuse(db, work)

    fv = db.execute(
        select(FieldVerification)
        .where(
            FieldVerification.work_id == work.id,
            FieldVerification.status == "submitted",
        )
        .order_by(FieldVerification.submitted_at.desc())
        .limit(1)
    ).scalar_one_or_none()

    measurement_shortfall_pct = None
    if fv and fv.measured_value is not None and work.sanctioned_qty:
        sanctioned = float(work.sanctioned_qty)
        if sanctioned > 0:
            ratio = float(fv.measured_value) / sanctioned
            measurement_shortfall_pct = max(0.0, (1.0 - ratio) * 100.0)

    citizen_mismatch = db.execute(
        select(func.count())
        .select_from(CitizenReport)
        .where(
            CitizenReport.work_id == work.id,
            CitizenReport.verdict.in_(("not_found", "partial", "different")),
        )
    ).scalar_one()

    sat = db.execute(
        select(SatelliteObservation)
        .where(SatelliteObservation.work_id == work.id)
        .order_by(SatelliteObservation.capture_date.desc())
        .limit(1)
    ).scalar_one_or_none()

    gps_trust = db.execute(
        select(func.min(Evidence.gps_trust)).where(Evidence.work_id == work.id)
    ).scalar_one()

    siblings = db.execute(
        select(func.count())
        .select_from(Work)
        .where(
            Work.implementing_agency == work.implementing_agency,
            Work.sanction_date == work.sanction_date,
            Work.implementing_agency.isnot(None),
            Work.sanction_date.isnot(None),
            Work.deleted_at.is_(None),
        )
    ).scalar_one()

    expected = work.expected_completion_date
    days_overdue = None
    if expected and work.actual_completion_date is None and expected < today:
        days_overdue = (today - expected).days

    d_rec_sanction = _days_between(work.recommendation_date, work.sanction_date)

    return {
        # identity
        "work_code": work.work_code,
        "category": work.category,
        "status": work.status,
        "implementing_agency": work.implementing_agency,
        "physical_progress_pct": work.physical_progress_pct,
        # money & quantity
        "sanctioned_amount_paise": work.sanctioned_amount_paise,
        "estimated_amount_paise": work.estimated_amount_paise,
        "sanctioned_qty": float(work.sanctioned_qty) if work.sanctioned_qty else None,
        "qty_unit": work.qty_unit,
        "benchmark_total_paise": benchmark_total_paise,
        "benchmark_source": bench.source if bench else None,
        "cost_ratio": cost_ratio,
        "unit_rate_ratio": unit_rate_ratio,
        "cost_revision_ratio": (
            work.sanctioned_amount_paise / work.estimated_amount_paise
            if work.estimated_amount_paise else None
        ),
        "tender_threshold_paise": TENDER_THRESHOLD_PAISE,
        "work_ceiling_paise": WORK_CEILING_PAISE,
        # statutory
        "is_prohibited_category": work.category in PROHIBITED_CATEGORIES,
        "siblings_same_day_same_agency": siblings,
        # geo & photo fraud
        "nearest_similar_work_m": nearest_m if (
            nearest_m is not None and nearest_m < GEO_DUPLICATE_RADIUS_M
        ) else nearest_m,
        "nearest_similar_work_code": nearest_code,
        "max_photo_similarity": photo_sim,
        "photo_similarity_match_code": photo_code,
        "min_gps_trust": gps_trust,
        "citizen_mismatch_reports": citizen_mismatch,
        # field
        "field_measured_value": float(fv.measured_value) if fv and fv.measured_value else None,
        "field_observed_status": fv.observed_status if fv else None,
        "measurement_shortfall_pct": measurement_shortfall_pct,
        # satellite
        "satellite_status": sat.status if sat else None,
        "satellite_confidence": float(sat.confidence) if sat else None,
        "satellite_reason": sat.reason if sat else None,
        # timeline
        "days_overdue": days_overdue,
        "days_recommend_to_sanction": d_rec_sanction,
        "days_recommend_to_sanction_abs": abs(d_rec_sanction) if d_rec_sanction else None,
        "days_sanction_to_completion": _days_between(
            work.sanction_date, work.actual_completion_date
        ),
        "completion_before_sanction": (
            work.actual_completion_date is not None
            and work.sanction_date is not None
            and work.actual_completion_date < work.sanction_date
        ),
        "days_since_sanction": _days_between(work.sanction_date, today),
    }
