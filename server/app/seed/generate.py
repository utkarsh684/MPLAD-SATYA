"""Deterministic synthetic dataset.

Two properties make this worth more than a pile of fake rows:

1. It is DETERMINISTIC (fixed seed everywhere), so the demo is reproducible
   rather than lucky.
2. Its LAST STEP IS A SELF-CHECK. After seeding it scores every planted case and
   asserts the produced score and reason codes match the fixture. If they do
   not, seeding exits non-zero. You cannot deploy a build where the hero screen
   shows the wrong number.

All dates are RELATIVE TO TODAY. A dataset seeded in September that hard-codes
"40 days overdue" would read "95 days overdue" by the finals.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import sys
import time
import uuid
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

from sqlalchemy import func, select, text
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.models import (
    BenchmarkRate,
    CitizenReport,
    District,
    Evidence,
    FieldVerification,
    FundRelease,
    SatelliteObservation,
    User,
    Work,
)
from app.risk.service import score_work
from app.satellite import FixtureAdapter
from app.services import phash as phash_svc

FIXTURES = Path(__file__).parent / "fixtures"
SEED = 42

# Commit every N works while scoring, so the exclusive locks taken by wipe()
# are released regularly instead of being held for the entire run.
SCORE_COMMIT_EVERY = 50
# Passes over the unscored set before giving up. Scoring 2000 works is ~20,000
# queries over a long-haul link, so a drop partway through is the normal case
# rather than the exception, and a run that needs a human to restart it is a
# run that does not finish.
SCORE_ATTEMPTS = 6


def _progress(message: str) -> None:
    """Progress goes to stderr so piping stdout stays clean.

    The seeder used to print nothing until it finished. Against a remote
    database that is twenty minutes of silence, which is indistinguishable
    from a hang - and was in fact mistaken for one.
    """
    print(message, file=sys.stderr, flush=True)

# Bhopal, matching the district shown on the approved screens.
DISTRICTS = [
    ("Bhopal", "Madhya Pradesh", "451", 23.2599, 77.4126),
    ("Sehore", "Madhya Pradesh", "452", 23.2020, 77.0850),
    ("Raisen", "Madhya Pradesh", "453", 23.3300, 77.8100),
]

WARDS = [f"Ward {i}" for i in range(1, 25)]
AGENCIES = [
    "PWD Division 1", "PWD Division 2", "Demo Infra Ltd", "Narmada Constructions",
    "MP Urban Development Co", "PHE Division 1", "Zila Panchayat Works Wing",
]
# Category mix approximating the MPLADS annual report distribution.
CATEGORY_MIX = [
    ("road", 0.28), ("water_supply", 0.15), ("school_building", 0.19),
    ("health_centre", 0.09), ("community_hall", 0.10), ("toilet_block", 0.08),
    ("drain", 0.06), ("streetlight", 0.03), ("pond", 0.02),
]
QTY_RANGE = {
    "road": (50, 800, "m"), "drain": (40, 400, "m"), "water_supply": (60, 900, "m"),
    "school_building": (80, 400, "sqm"), "community_hall": (60, 300, "sqm"),
    "health_centre": (90, 350, "sqm"), "toilet_block": (2, 10, "nos"),
    "streetlight": (10, 80, "nos"), "pond": (200, 2000, "cum"), "other": (1, 5, "nos"),
}

DEMO_USERS = [
    ("+919000000001", "MoSPI Admin", "mospi_admin"),
    ("+919000000002", "DM Bhopal", "district_officer"),
    ("+919000000003", "R. Sharma (Field)", "field_officer"),
    ("+919000000004", "Hon. MP Bhopal", "mp"),
    ("+919000000005", "Citizen Demo", "citizen"),
]


def _today() -> date:
    return datetime.now(UTC).date()


def _phash_for(label: str) -> int:
    """Stable pseudo-hash from a label, so seeding needs no image assets."""
    digest = hashlib.sha256(label.encode()).digest()[:8]
    return int.from_bytes(digest, "big")


def _flip_bits(value: int, n: int, rng: random.Random) -> int:
    for pos in rng.sample(range(64), n):
        value ^= 1 << pos
    return value


def _offset(lat: float, lon: float, metres: float, bearing_deg: float) -> tuple[float, float]:
    import math

    d_lat = (metres * math.cos(math.radians(bearing_deg))) / 111_320.0
    d_lon = (metres * math.sin(math.radians(bearing_deg))) / (
        111_320.0 * math.cos(math.radians(lat))
    )
    return lat + d_lat, lon + d_lon


def _point(lat: float, lon: float) -> str:
    return f"SRID=4326;POINT({lon} {lat})"


def wipe(db: Session) -> None:
    db.execute(
        text(
            """
            TRUNCATE citizen_reports, satellite_observations, evidence,
                     upload_sessions, field_verifications, decisions,
                     fund_releases, risk_reasons, risk_assessments,
                     verification_sources, works, benchmark_rates,
                     otp_challenges, push_tokens, sync_cursors, users, districts
            RESTART IDENTITY CASCADE
            """
        )
    )
    # audit_log is append-only by trigger; a demo reset legitimately needs it
    # cleared, so the trigger is dropped for the duration of the TRUNCATE only.
    db.execute(text("ALTER TABLE audit_log DISABLE TRIGGER trg_audit_log_append_only"))
    db.execute(text("TRUNCATE audit_log RESTART IDENTITY"))
    db.execute(text("ALTER TABLE audit_log ENABLE TRIGGER trg_audit_log_append_only"))


def seed(db: Session, n_works: int = 2000, seed_value: int = SEED) -> dict:
    rng = random.Random(seed_value)
    today = _today()

    districts: list[District] = []
    for name, state, lgd, lat, lon in DISTRICTS:
        d = District(name=name, state=state, lgd_code=lgd, centroid=_point(lat, lon))
        db.add(d)
        districts.append(d)
    db.flush()
    bhopal = districts[0]

    for rate in json.loads((FIXTURES / "cpwd_rates.json").read_text()):
        db.add(
            BenchmarkRate(
                category=rate["category"], item_code=rate["item_code"],
                description=rate["description"], unit=rate["unit"],
                rate_paise=rate["rate_paise"], state="Madhya Pradesh",
                region_factor=1.0, source=rate["source"],
                effective_from=date(2024, 4, 1),
            )
        )
    db.flush()
    rates = {r.category: r for r in db.execute(select(BenchmarkRate)).scalars()}

    users = {}
    for phone, name, role in DEMO_USERS:
        u = User(
            phone=phone, name=name, role=role,
            district_id=bhopal.id if role != "mospi_admin" else None,
            is_active=True,
        )
        db.add(u)
        users[role] = u
    db.flush()

    planted = json.loads((FIXTURES / "planted_cases.json").read_text())
    planted_codes = {p["work_code"] for p in planted}
    works_by_code: dict[str, Work] = {}

    # --- positions first, because a geo-duplicate must be placed relative to
    # its anchor and the anchor may appear later in the fixture.
    #
    # Previously this resolved the anchor from works_by_code while still
    # building that map, so for the hero - which is the first planted case and
    # names an anchor defined fifth - the lookup returned None and it silently
    # fell back to the base point. Worse, even the success branch offset from
    # the hardcoded base rather than from the anchor's own position. The two
    # bugs together left the "duplicate" pair about a kilometre apart, so
    # GEO_DUPLICATE could never fire on the demo work it exists to demonstrate.
    base_lat, base_lon = 23.2599, 77.4126
    positions: dict[str, tuple[float, float]] = {}

    for case in planted:
        if not case.get("inject", {}).get("geo_duplicate_of"):
            positions[case["work_code"]] = _offset(
                base_lat, base_lon, rng.uniform(200, 4000), rng.uniform(0, 360)
            )

    for case in planted:
        inject = case.get("inject", {})
        anchor_code = inject.get("geo_duplicate_of")
        if not anchor_code:
            continue
        anchor_pos = positions.get(anchor_code)
        if anchor_pos is None:
            # An anchor that is itself a duplicate is not a case the fixture
            # expresses; failing loudly beats planting a silent non-duplicate.
            raise ValueError(
                f"{case['work_code']} is a geo-duplicate of {anchor_code}, "
                "which has no position - is the anchor also a duplicate?"
            )
        positions[case["work_code"]] = _offset(
            anchor_pos[0], anchor_pos[1], inject["geo_offset_m"], 47.0
        )

    # --- planted cases first, so ordinary works can avoid colliding with them
    for case in planted:
        inject = case.get("inject", {})
        rate = rates[case["category"]]
        lat, lon = positions[case["work_code"]]

        overdue = inject.get("days_overdue", 0)
        expected = today - timedelta(days=overdue) if overdue else today + timedelta(days=45)
        sanction = today - timedelta(days=180)

        work = Work(
            work_code=case["work_code"], title=case["title"], category=case["category"],
            district_id=bhopal.id, ward=case.get("ward"),
            mp_user_id=users["mp"].id,
            implementing_agency=case.get("implementing_agency"),
            sanctioned_amount_paise=case["sanctioned_amount_paise"],
            estimated_amount_paise=case["sanctioned_amount_paise"],
            sanctioned_qty=case["sanctioned_qty"], qty_unit=case["qty_unit"],
            status="in_progress", recommendation_date=sanction - timedelta(days=30),
            sanction_date=sanction, expected_completion_date=expected,
            physical_progress_pct=rng.randint(40, 90),
            location=_point(lat, lon),
            esakshi_ref=f"ESK-{case['work_code'].replace('/', '-')}",
            data_source="seed",
        )
        db.add(work)
        db.flush()
        works_by_code[case["work_code"]] = work

        # evidence: a genuinely different hash, a few bits from the original
        base_hash = _phash_for(case["work_code"])
        if inject.get("photo_reuse_of"):
            base_hash = _flip_bits(
                _phash_for(inject["photo_reuse_of"]), inject.get("photo_hamming", 3), rng
            )
        value = phash_svc.PhashValue(base_hash)
        b0, b1, b2, b3 = value.band_values
        db.add(
            Evidence(
                work_id=work.id, uploaded_by=users["field_officer"].id,
                source="field_officer", kind="photo",
                storage_key=f"seed/{case['work_code'].replace('/', '_')}.jpg",
                sha256=hashlib.sha256(case["work_code"].encode()).hexdigest(),
                mime="image/jpeg", bytes_len=210_000, width=1280, height=960,
                captured_at=datetime.now(UTC) - timedelta(days=3),
                gps=_point(lat, lon), gps_accuracy_m=6.5,
                gps_trust=inject.get("gps_trust", 90), gps_flags=[],
                phash=value.signed, pb0=b0, pb1=b1, pb2=b2, pb3=b3,
                faces_blurred=0,
            )
        )

        if inject.get("field_measured") is not None:
            db.add(
                FieldVerification(
                    work_id=work.id, officer_user_id=users["field_officer"].id,
                    assigned_at=datetime.now(UTC) - timedelta(days=2),
                    due_at=datetime.now(UTC) + timedelta(hours=6),
                    submitted_at=datetime.now(UTC) - timedelta(hours=4),
                    status="submitted", measured_value=inject["field_measured"],
                    measured_unit=case["qty_unit"], measure_method="ar_arcore",
                    measure_accuracy_m=0.4, observed_status="partial",
                    gps=_point(lat, lon), client_uuid=uuid.uuid4(),
                )
            )

        for _ in range(inject.get("citizen_reports", 0)):
            db.add(
                CitizenReport(
                    work_id=work.id, reporter_user_id=users["citizen"].id,
                    phone_hash=hashlib.sha256(b"demo-citizen").hexdigest(),
                    category="incomplete", verdict="partial",
                    description="Work appears incomplete on site.",
                    gps=_point(*_offset(lat, lon, rng.uniform(10, 90), rng.uniform(0, 360))),
                    client_uuid=uuid.uuid4(),
                )
            )

        sat = FixtureAdapter().observe(category=case["category"], lat=lat, lon=lon)
        db.add(
            SatelliteObservation(
                work_id=work.id, capture_date=today - timedelta(days=10),
                provider="bhuvan_cartosat_fixture", resolution_m=sat.resolution_m,
                status=sat.status, confidence=sat.confidence, method=sat.method,
                min_detectable_m2=sat.min_detectable_m ** 2,
                target_footprint_m2=sat.target_dimension_m ** 2, reason=sat.reason,
            )
        )

        db.add(
            FundRelease(
                work_id=work.id, installment_no=2, tranche_label="Tranche 2",
                claimed_amount_paise=case["sanctioned_amount_paise"],
                invoice_ref=f"INV-{case['work_code'].replace('/', '-')}",
                requested_at=datetime.now(UTC) - timedelta(days=1),
                status="pending",
            )
        )

    db.flush()

    # --- ordinary works
    categories = [c for c, _ in CATEGORY_MIX]
    cat_weights = [w for _, w in CATEGORY_MIX]
    made = 0
    serial = 2000
    while made < max(0, n_works - len(planted)):
        serial += 1
        code = f"MP/2026/{serial}"
        if code in planted_codes:
            continue
        category = rng.choices(categories, weights=cat_weights, k=1)[0]
        lo, hi, unit = QTY_RANGE[category]
        qty = round(rng.uniform(lo, hi), 1)
        rate = rates[category]
        # Honest +/-20% cost variance: tight enough that a real 2.9x
        # overstatement is a clear outlier, loose enough that clean works are
        # not all flagged. This sigma is the knob the false-positive test tunes.
        multiplier = rng.lognormvariate(0, 0.18)
        amount = int(rate.rate_paise * qty * multiplier)

        district = rng.choice(districts)
        d_lat, d_lon = next(
            (lat_, lon_)
            for name_, _state, _lgd, lat_, lon_ in DISTRICTS
            if name_ == district.name
        )
        lat, lon = _offset(d_lat, d_lon, rng.uniform(300, 15000), rng.uniform(0, 360))

        sanction = today - timedelta(days=rng.randint(30, 900))
        expected = sanction + timedelta(days=rng.randint(120, 365))
        status = rng.choice(["in_progress", "in_progress", "completed", "sanctioned"])

        work = Work(
            work_code=code,
            title=f"{category.replace('_', ' ').title()} - {rng.choice(WARDS)}",
            category=category, district_id=district.id, ward=rng.choice(WARDS),
            mp_user_id=users["mp"].id, implementing_agency=rng.choice(AGENCIES),
            sanctioned_amount_paise=amount, estimated_amount_paise=amount,
            sanctioned_qty=qty, qty_unit=unit, status=status,
            recommendation_date=sanction - timedelta(days=rng.randint(15, 60)),
            sanction_date=sanction,
            expected_completion_date=expected,
            actual_completion_date=expected - timedelta(days=rng.randint(0, 30))
            if status == "completed" else None,
            physical_progress_pct=100 if status == "completed" else rng.randint(0, 95),
            location=_point(lat, lon),
            esakshi_ref=f"ESK-{code.replace('/', '-')}", data_source="seed",
        )
        db.add(work)
        made += 1
        if made % 250 == 0:
            db.flush()

    db.flush()

    # --- score everything
    #
    # This is the slow phase by a wide margin: score_work runs a dozen queries
    # per work, so against a remote database it is thousands of round trips.
    # Held inside one transaction it also keeps the exclusive locks taken by
    # wipe() for the whole run, which blocks every other reader - including a
    # deployed API pointed at the same database.
    #
    # So it commits in batches and reports progress. The trade-off is
    # deliberate: a crash mid-scoring now leaves a partially seeded database
    # rather than nothing, and main() says so explicitly instead of implying
    # the old all-or-nothing guarantee still holds.
    all_works = db.execute(select(Work)).scalars().all()
    total = len(all_works)
    db.commit()

    for i, work in enumerate(all_works, 1):
        score_work(db, work, trigger="seed")
        if i % SCORE_COMMIT_EVERY == 0 or i == total:
            db.commit()
            _progress(f"scored {i}/{total} works")

    # --- assignments for the demo field officer (screen 1 counters)
    officer = users["field_officer"]
    now = datetime.now(UTC)
    bhopal_works = [w for w in all_works if w.district_id == bhopal.id][:12]
    for i, work in enumerate(bhopal_works):
        existing = db.execute(
            select(FieldVerification).where(
                FieldVerification.work_id == work.id,
                FieldVerification.officer_user_id == officer.id,
            )
        ).scalar_one_or_none()
        if existing:
            continue
        db.add(
            FieldVerification(
                work_id=work.id, officer_user_id=officer.id,
                assigned_at=now - timedelta(days=1),
                due_at=now + timedelta(hours=6 if i < 4 else 24 * (1 + i % 5)),
                status="assigned",
            )
        )
    db.flush()
    return {"works": len(all_works), "planted": len(planted), "users": len(DEMO_USERS)}


def score_pending(db: Session) -> int:
    """Score every work that still has no current assessment.

    Scoring 2000 works is roughly 20,000 queries, and over a long-haul link to
    a managed database one blip ends the run - seen three times here, twice as
    "network is unreachable" and once as an SSL bad-record-mac. Without a
    resume path each attempt restarted from nothing, so a flaky link made
    seeding impossible rather than merely slow.

    Retrying is safe because the work is idempotent: committed batches are
    durable, a rolled-back tail simply stays unscored, and each pass asks the
    database afresh what still has no assessment. Nothing is scored twice and
    nothing is skipped.

    This is deliberately NOT part of seed(): that function builds districts,
    rates, users and works from scratch, and re-running it is how you get a
    fresh dataset. This only fills in the scores.
    """
    before = _unscored(db)
    if not before:
        _progress("nothing left to score")
        return 0

    for attempt in range(1, SCORE_ATTEMPTS + 1):
        try:
            _score_once(db)
            break
        except OperationalError:
            # The link died mid-run. Nothing is lost: committed batches are
            # durable, the rolled-back tail simply stays unscored, and the
            # next pass re-queries for whatever still has no assessment. That
            # idempotence is why the retry can be this blunt.
            db.rollback()
            if attempt == SCORE_ATTEMPTS:
                raise
            wait = min(2 ** attempt, 60)
            _progress(
                f"connection lost after {before - _unscored(db)} works; "
                f"retrying in {wait}s ({attempt}/{SCORE_ATTEMPTS})"
            )
            time.sleep(wait)

    return before - _unscored(db)


def _unscored(db: Session) -> int:
    return db.execute(
        select(func.count()).select_from(Work)
        .where(Work.current_assessment_id.is_(None))
    ).scalar_one()


def _score_once(db: Session) -> None:
    """One pass over everything that still has no assessment."""
    pending = db.execute(
        select(Work).where(Work.current_assessment_id.is_(None))
    ).scalars().all()
    total = len(pending)
    _progress(f"scoring {total} works that have no assessment yet")
    for i, work in enumerate(pending, 1):
        score_work(db, work, trigger="seed_resume")
        if i % SCORE_COMMIT_EVERY == 0 or i == total:
            db.commit()
            _progress(f"scored {i}/{total}")


def self_check(db: Session) -> list[str]:
    """Assert every planted case still produces its documented result."""
    problems: list[str] = []
    for case in json.loads((FIXTURES / "planted_cases.json").read_text()):
        expect = case.get("expect") or {}
        if not expect:
            continue
        work = db.execute(
            select(Work).where(Work.work_code == case["work_code"])
        ).scalar_one_or_none()
        if work is None:
            problems.append(f"{case['work_code']}: not seeded")
            continue
        assessment = work.current_assessment
        if assessment is None:
            problems.append(f"{case['work_code']}: no assessment")
            continue

        if "score" in expect and assessment.score != expect["score"]:
            problems.append(
                f"{case['work_code']}: score {assessment.score} != expected {expect['score']}"
            )
        if "band" in expect and assessment.band != expect["band"]:
            problems.append(
                f"{case['work_code']}: band {assessment.band} != expected {expect['band']}"
            )
        if "recommended_action" in expect and (
            assessment.recommended_action != expect["recommended_action"]
        ):
            problems.append(
                f"{case['work_code']}: action {assessment.recommended_action} "
                f"!= {expect['recommended_action']}"
            )
        if "reasons" in expect:
            actual = [[r.code, r.points] for r in assessment.reasons if r.points > 0]
            wanted = [list(x) for x in expect["reasons"]]
            if actual != wanted:
                problems.append(f"{case['work_code']}: reasons {actual} != expected {wanted}")
    return problems


def reseed(db: Session, n_works: int = 2000) -> dict:
    wipe(db)
    counts = seed(db, n_works=n_works)
    problems = self_check(db)
    if problems:
        raise RuntimeError("seed self-check failed: " + "; ".join(problems))
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description="Seed the SATYA demo dataset")
    parser.add_argument("--works", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--keep", action="store_true", help="do not wipe first")
    parser.add_argument(
        "--resume",
        action="store_true",
        help="score works left unscored by an interrupted run; builds nothing new",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        if args.resume:
            scored = score_pending(db)
            problems = self_check(db)
            if problems:
                print("SELF-CHECK FAILED after resume:", file=sys.stderr)
                for p in problems:
                    print(f"  - {p}", file=sys.stderr)
                return 1
            db.commit()
            print(f"resumed: scored {scored} works; self-check passed")
            return 0

        if not args.keep:
            wipe(db)
        counts = seed(db, n_works=args.works, seed_value=args.seed)
        problems = self_check(db)
        if problems:
            # Scoring commits in batches, so by this point the rows are already
            # durable and rollback() cannot undo them. Say so plainly rather
            # than implying the database was left untouched.
            db.rollback()
            print("SEED SELF-CHECK FAILED:", file=sys.stderr)
            for p in problems:
                print(f"  - {p}", file=sys.stderr)
            print(
                "\nThe database holds partially seeded data. Re-run the seeder "
                "to wipe and rebuild it.",
                file=sys.stderr,
            )
            return 1
        db.commit()
        print(f"seeded {counts['works']} works ({counts['planted']} planted); self-check passed")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
