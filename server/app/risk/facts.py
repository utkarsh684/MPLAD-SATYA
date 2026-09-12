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
    FundRelease,
    SatelliteObservation,
    Work,
)
from app.services import phash as phash_svc
from app.services.anomaly import cost_zscore, iforest_flag

# Scheme constants.
TENDER_THRESHOLD_PAISE = 25_00_000 * 100      # Rs 25 lakh
WORK_CEILING_PAISE = 1_00_00_000 * 100        # Rs 1 crore per work
PROHIBITED_CATEGORIES: set[str] = set()       # populated from annex_ii.yaml if it existed
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
    """Closest other work of the same category, for the geo-duplicate signal.

    The point is read back out of the row that already holds it rather than
    bound as a parameter: psycopg3 cannot adapt a GeoAlchemy2 WKBElement and
    raises "cannot adapt type 'WKBElement'". An earlier version decoded it to
    floats in Python with geoalchemy2's to_shape, which needs Shapely - and
    when Shapely was missing the decode raised, the caller read that as "no
    location", and GEO_DUPLICATE silently stopped firing on every work in the
    database. Scores stayed plausible, which is the worst way for this to
    fail. Letting SQL use the geometry in place removes the decode, the
    dependency, and that entire failure mode.

    A work with no recorded location has no neighbours to compare against; it
    returns None rather than defaulting to a distance, so a missing location
    can never look like a duplicate.
    """
    if work.location is None:
        return (None, None)

    row = db.execute(
        text(
            """
            WITH here AS (
                SELECT location AS g FROM works WHERE id = :work_id
            )
            SELECT w.work_code,
                   ST_Distance(w.location, here.g) AS distance_m
            FROM works w, here
            WHERE w.id <> :work_id
              AND w.category = :category
              AND w.deleted_at IS NULL
              AND w.location IS NOT NULL
              AND ST_DWithin(w.location, here.g, :radius)
            ORDER BY distance_m ASC
            LIMIT 1
            """
        ),
        {
            "work_id": work.id,
            "category": work.category,
            "radius": SIMILAR_WORK_RADIUS_M,
        },
    ).first()
    return (float(row.distance_m), row.work_code) if row else (None, None)


def _photo_reuse(db: Session, work: Work) -> tuple[float | None, str | None]:
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


def _photo_cross_agency(db: Session, work: Work) -> bool:
    """True if any evidence photo is near-duplicate of a photo from a different agency."""
    ours = db.execute(
        select(Evidence)
        .where(Evidence.work_id == work.id, Evidence.phash.isnot(None))
    ).scalars().all()

    for ev in ours:
        value = phash_svc.PhashValue(phash_svc.to_unsigned(ev.phash))
        rows = db.execute(
            text(phash_svc.NEAR_DUPLICATE_SQL),
            phash_svc.near_duplicate_params(value, work.id),
        ).all()
        for r in rows:
            other_work = db.get(Work, r.work_id)
            if other_work and other_work.implementing_agency != work.implementing_agency:
                return True
    return False


def _max_photo_offset(db: Session, work: Work) -> float | None:
    """Max distance between any evidence GPS and the work location, in metres."""
    if work.location is None:
        return None

    # Same reasoning as _nearest_similar_work: the work's own geometry is used
    # in place rather than decoded into Python and sent back.
    row = db.execute(
        text(
            """
            SELECT MAX(ST_Distance(e.gps, w.location)) AS max_offset_m
            FROM evidence e, works w
            WHERE w.id = :work_id
              AND e.work_id = :work_id
              AND e.gps IS NOT NULL
              AND e.deleted_at IS NULL
            """
        ),
        {"work_id": work.id},
    ).first()
    return round(float(row.max_offset_m), 1) if row and row.max_offset_m else None


def _utilisation(db: Session, work: Work) -> float | None:
    """Ratio of amount released to amount sanctioned, as a percentage."""
    released = db.execute(
        select(func.coalesce(func.sum(FundRelease.claimed_amount_paise), 0))
        .where(FundRelease.work_id == work.id, FundRelease.status == "approved")
    ).scalar_one()
    if work.sanctioned_amount_paise <= 0:
        return None
    return round(released / work.sanctioned_amount_paise * 100, 1)


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

    # --- ML-computed facts (previously stubbed) ---
    zscore = cost_zscore(db, work)
    if_flag = iforest_flag(db, work)
    photo_offset = _max_photo_offset(db, work)
    cross_agency = _photo_cross_agency(db, work)
    utilisation = _utilisation(db, work)

    # Days since any evidence/field-verification was submitted for this work
    last_activity = db.execute(
        select(func.greatest(
            func.max(Evidence.received_at),
            func.max(FieldVerification.submitted_at),
        )).select_from(Evidence).outerjoin(
            FieldVerification, FieldVerification.work_id == Evidence.work_id
        ).where(Evidence.work_id == work.id)
    ).scalar_one()

    days_since_progress: int | None = None
    if last_activity:
        days_since_progress = (datetime.now(UTC) - last_activity).days

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
        # statutory (seeded constants for now — live when annex_ii.yaml exists)
        "is_prohibited_category": work.category in PROHIBITED_CATEGORIES,
        "siblings_same_day_same_agency": siblings,
        "tender_conducted": None,        # no tender register data source yet
        "uc_pending_days": None,          # no UC tracking data source yet
        "creates_durable_asset": None,    # needs work-type classification
        "agency_blacklisted": None,       # needs blacklist register
        "duplicate_sanction_code": None,  # needs cross-scheme dedup
        "land_is_public": None,           # needs land records integration
        "has_completion_certificate": None,
        "private_benefit_flag": None,
        # geo & photo fraud
        "nearest_similar_work_m": nearest_m if (
            nearest_m is not None and nearest_m < GEO_DUPLICATE_RADIUS_M
        ) else nearest_m,
        "nearest_similar_work_code": nearest_code,
        "max_photo_similarity": photo_sim,
        "photo_similarity_match_code": photo_code,
        "min_gps_trust": gps_trust,
        "citizen_mismatch_reports": citizen_mismatch,
        "max_photo_offset_m": photo_offset,
        "photo_shared_across_agencies": cross_agency,
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
        # ML-computed (previously dead)
        "cost_zscore": zscore,
        "iforest_flag": if_flag,
        # efficiency
        "days_since_progress_update": days_since_progress,
        "utilisation_pct": utilisation,
    }
