"""The engine tests that actually prove something.

`assess()` is pure, so these need no database and no HTTP.
"""

import json
import random
from pathlib import Path

import pytest

from app.risk import assess, load_rulebook

RULES = json.loads((Path(__file__).parent.parent / "app/risk/rules.json").read_text())


HERO = {
    "work_code": "MP/2026/1142",
    "category": "road",
    "status": "in_progress",
    "sanctioned_amount_paise": 156_000_000,
    "benchmark_total_paise": 54_000_000,
    "cost_ratio": 156_000_000 / 54_000_000,
    "sanctioned_qty": 100.0,
    "qty_unit": "m",
    "nearest_similar_work_m": 8.2,
    "max_photo_similarity": 0.953,
    "field_measured_value": 52.0,
    "measurement_shortfall_pct": 48.0,
    "days_overdue": 40,
    "satellite_status": "inconclusive",
    "satellite_reason": "Imagery at 2.5 m/px cannot resolve a 3 m wide road",
}


def test_hero_work_scores_exactly_78():
    """Golden test. This is the number on stage; CI fails before the judges see a drift."""
    r = assess(HERO)
    assert r.score == 78
    assert r.band == "red"
    assert r.recommended_action == "hold_field_verify"
    assert r.action_label == "HOLD RELEASE FOR FIELD REVIEW"

    scoring = [(x.code, x.points) for x in r.reasons if x.points > 0]
    assert scoring == [
        ("COST_ANOMALY_BENCHMARK", 24),
        ("GEO_DUPLICATE", 18),
        ("IMAGE_REUSE", 16),
        ("MEASUREMENT_MISMATCH", 15),
        ("TIMELINE_OVERDUE", 5),
    ]


def test_hero_explanations_match_the_approved_screen():
    by_code = {x.code: x for x in assess(HERO).reasons}
    assert by_code["COST_ANOMALY_BENCHMARK"].explanation == (
        "Reported Rs 15.60 L is 2.9x the Rs 5.40 L benchmark"
    )
    assert by_code["COST_ANOMALY_BENCHMARK"].provenance == (
        "Evidence: eSAKSHI vs. benchmark database"
    )
    assert by_code["GEO_DUPLICATE"].explanation == "Another similar work sanctioned 8 m away"
    assert by_code["IMAGE_REUSE"].explanation == (
        "95% match with another work's evidence photo"
    )
    assert by_code["MEASUREMENT_MISMATCH"].explanation == "Observed 52 m vs 100 m sanctioned"


def test_points_always_sum_to_score():
    """The property that makes explainability arithmetic rather than hand-waving."""
    rng = random.Random(42)
    for _ in range(400):
        facts = {
            "category": "road",
            "status": rng.choice(["in_progress", "completed", "sanctioned"]),
            "sanctioned_amount_paise": rng.randint(1_00_000, 5_00_00_000),
            "benchmark_total_paise": rng.randint(1_00_000, 2_00_00_000),
            "cost_ratio": rng.uniform(0.5, 8.0),
            "cost_zscore": rng.uniform(0, 9),
            "nearest_similar_work_m": rng.uniform(0, 40),
            "max_photo_similarity": rng.uniform(0.5, 1.0),
            "measurement_shortfall_pct": rng.uniform(0, 95),
            "days_overdue": rng.randint(0, 900),
            "uc_pending_days": rng.randint(0, 500),
            "min_gps_trust": rng.randint(0, 100),
            "citizen_mismatch_reports": rng.randint(0, 9),
            "is_prohibited_category": rng.random() < 0.15,
            "agency_blacklisted": rng.random() < 0.1,
            "tender_conducted": rng.random() < 0.8,
            "tender_threshold_paise": 25_00_000,
            "siblings_same_day_same_agency": rng.randint(0, 6),
            "days_since_progress_update": rng.randint(0, 400),
        }
        r = assess(facts)
        assert r.points_sum() == r.score, f"{r.points_sum()} != {r.score}"
        assert 0 <= r.score <= 100


def test_empty_facts_score_zero_and_never_crash():
    """Missing data must never fabricate a finding.

    A false positive from a NULL is an unjustified hold on public money.
    """
    r = assess({})
    assert r.score == 0
    assert r.band == "green"
    assert r.reasons == []


def test_clean_work_is_green():
    r = assess({
        "category": "school_building", "status": "in_progress",
        "sanctioned_amount_paise": 12_75_000 * 100,
        "benchmark_total_paise": 12_00_000 * 100,
        "cost_ratio": 1.06, "nearest_similar_work_m": 850.0,
        "max_photo_similarity": 0.31, "measurement_shortfall_pct": 2.0,
        "days_overdue": 0, "min_gps_trust": 92,
    })
    assert r.score == 0
    assert r.band == "green"
    assert r.recommended_action == "auto_approve"


def test_satellite_inconclusive_never_raises_the_score():
    """An unusable sensor must not manufacture suspicion.

    This is the design claim a remote-sensing judge will probe hardest.
    """
    base = {"category": "road", "days_overdue": 40}
    without = assess(base)
    with_sat = assess({**base, "satellite_status": "inconclusive",
                       "satellite_reason": "below resolution threshold"})
    assert with_sat.score == without.score
    escalation = [x for x in with_sat.reasons if x.code == "SATELLITE_INCONCLUSIVE_ESCALATE"]
    assert len(escalation) == 1, "the procedural escalation should still be surfaced"
    assert escalation[0].points == 0


def test_band_boundaries():
    _, weights, _, _ = load_rulebook()
    assert weights["bands"]["green"]["max"] == 30
    assert weights["bands"]["yellow"]["min"] == 31
    assert weights["bands"]["red"]["min"] == 71


# Some rules are mutually exclusive by construction: a work cannot be both
# below the tender threshold (TENDER_SPLIT) and above it (TENDER_NOT_CONDUCTED),
# nor simultaneously "not started" and "a different work". These overrides give
# those rules the facts they need.
REACHABILITY_OVERRIDES = {
    "TENDER_NOT_CONDUCTED": {
        "sanctioned_amount_paise": 90_00_000,
        "siblings_same_day_same_agency": 0,
    },
    "DIFFERENT_WORK_ON_SITE": {"field_observed_status": "different_work"},
}


@pytest.mark.parametrize("rule", RULES, ids=[r["code"] for r in RULES])
def test_every_rule_is_reachable(rule):
    """A rule that can never fire is dead weight pretending to be coverage."""
    facts = {
        "is_prohibited_category": True, "siblings_same_day_same_agency": 4,
        "sanctioned_amount_paise": 20_00_000, "tender_threshold_paise": 25_00_000,
        "tender_conducted": False, "uc_pending_days": 120,
        "work_ceiling_paise": 10_00_000, "creates_durable_asset": False,
        "days_recommend_to_sanction": -5, "days_recommend_to_sanction_abs": 5,
        "agency_blacklisted": True, "implementing_agency": "Demo Infra Ltd",
        "duplicate_sanction_code": "MP/2026/1140", "land_is_public": False,
        "status": "completed", "has_completion_certificate": False,
        "private_benefit_flag": True, "cost_ratio": 3.2, "cost_zscore": 4.1,
        "iforest_flag": True, "unit_rate_ratio": 2.4, "cost_revision_ratio": 1.6,
        "sanctioned_qty": 0.0, "nearest_similar_work_m": 8.2,
        "max_photo_similarity": 0.96, "min_gps_trust": 20,
        "citizen_mismatch_reports": 3, "max_photo_offset_m": 900.0,
        "days_sanction_to_completion": 3, "completion_before_sanction": True,
        "photo_shared_across_agencies": True, "measurement_shortfall_pct": 48.0,
        "field_observed_status": "not_started", "physical_progress_pct": 60,
        "days_overdue": 40, "days_since_progress_update": 120,
        "utilisation_pct": 0.3, "days_since_sanction": 400,
        "satellite_status": "inconclusive",
        "category": "road", "qty_unit": "m", "benchmark_total_paise": 5_00_000,
        "benchmark_source": "CPWD DSR 2024", "field_measured_value": 52.0,
        "satellite_reason": "resolution", "utilisation": 0.3,
    }
    facts.update(REACHABILITY_OVERRIDES.get(rule["code"], {}))
    codes = {x.code for x in assess(facts).reasons}
    assert rule["code"] in codes, f"{rule['code']} never fires even on a maximally bad work"
