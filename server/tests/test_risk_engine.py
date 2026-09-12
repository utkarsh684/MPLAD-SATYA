"""The engine tests that actually prove something.

`assess()` is pure, so these need no database and no HTTP.
"""

import json
import random
from pathlib import Path

import pytest

from app.risk import assess, load_rulebook
from app.risk.engine import _band_for

RULES = json.loads((Path(__file__).parent.parent / "app/risk/rules.json").read_text())


# The facts the engine actually computes for MP/2026/1142 from a seeded
# database, taken from that assessment's own inputs_snapshot.
#
# This dict used to be hand-written and much thinner, which made the golden
# test agree with itself rather than with the demo: it omitted the
# cross-agency photo match and the unit-rate ratio, so two real rules never
# fired here and the total came to 78 while the deployed service returned 80.
# A golden test that does not match the running system cannot protect it.
HERO = {
    "work_code": "MP/2026/1142",
    "category": "road",
    "status": "in_progress",
    "sanctioned_amount_paise": 156_000_000,
    "estimated_amount_paise": 156_000_000,
    "benchmark_total_paise": 54_000_000,
    "cost_ratio": 156_000_000 / 54_000_000,
    "cost_revision_ratio": 1.0,
    "unit_rate_ratio": 156_000_000 / 54_000_000,
    "sanctioned_qty": 100.0,
    "qty_unit": "m",
    "physical_progress_pct": 53,
    "nearest_similar_work_m": 8.18271215,
    "nearest_similar_work_code": "MP/2026/1140",
    "max_photo_similarity": 0.953125,
    "photo_similarity_match_code": "MP/2026/0987",
    "photo_shared_across_agencies": True,
    "field_measured_value": 52.0,
    "field_observed_status": "partial",
    "measurement_shortfall_pct": 48.0,
    "min_gps_trust": 85,
    "days_overdue": 40,
    "days_since_sanction": 180,
    "days_recommend_to_sanction": 30,
    "days_recommend_to_sanction_abs": 30,
    "days_since_progress_update": 0,
    "siblings_same_day_same_agency": 2,
    "satellite_status": "inconclusive",
    "satellite_confidence": 0.68,
    "satellite_reason": "Imagery at 2.5 m/px cannot resolve a 3 m wide road",
    "utilisation_pct": 0.0,
    "iforest_flag": False,
    "is_prohibited_category": False,
    "completion_before_sanction": False,
    "implementing_agency": "Demo Infra Ltd",
    "tender_threshold_paise": 250_000_000,
    "work_ceiling_paise": 1_000_000_000,
}


def test_hero_work_scores_exactly_80():
    """Golden test. This is the number on stage; CI fails before a drift ships.

    Verified against the deployed service, which returns the same 80 and the
    same ordered reasons for this work:
        ./scripts/verify-hero.sh
    """
    r = assess(HERO)
    assert r.score == 80
    assert r.band == "red"
    assert r.recommended_action == "hold_field_verify"
    assert r.action_label == "HOLD RELEASE FOR FIELD REVIEW"

    scoring = [(x.code, x.points) for x in r.reasons if x.points > 0]
    assert scoring == [
        ("COST_ANOMALY_BENCHMARK", 17),
        ("MEASUREMENT_MISMATCH", 15),
        ("GEO_DUPLICATE", 13),
        ("IMAGE_REUSE", 11),
        ("SAME_PHOTO_CROSS_AGENCY", 11),
        ("UNIT_RATE_OUTLIER", 8),
        ("TIMELINE_OVERDUE", 5),
    ]


def test_hero_category_caps_are_what_redistribute_the_points():
    """Why the headline reason is 17 and not its raw 24.

    Two anomaly rules fire together against a 25-point category cap, and three
    fraud rules against 35, so every reason in those categories is scaled
    down. Pinned because it is the first thing anyone asks when the displayed
    points do not match a rule's raw value.
    """
    r = assess(HERO)
    assert r.subscores["anomaly"] == 25
    assert r.subscores["fraud"] == 35
    assert sum(x.points for x in r.reasons) == r.score


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
        "citizen_mismatch_reports": 6, "max_photo_offset_m": 900.0,
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


# --------------------------------------------------------------------------
# Band boundary exhaustive check.
#
# The bands in weights.yaml are inclusive ranges (0-30, 31-70, 71-100). An
# off-by-one at 30/31 or 70/71 changes the recommended action on real money,
# so every boundary is pinned rather than sampled.
# --------------------------------------------------------------------------

def _band(score: int) -> str:
    _, weights, _, _ = load_rulebook()
    return _band_for(score, weights)[0]


@pytest.mark.parametrize(
    "score,expected",
    [
        (0, "green"), (1, "green"), (15, "green"), (29, "green"), (30, "green"),
        (31, "yellow"), (32, "yellow"), (50, "yellow"), (69, "yellow"), (70, "yellow"),
        (71, "red"), (72, "red"), (78, "red"), (99, "red"), (100, "red"),
    ],
)
def test_band_boundary_behaviour(score, expected):
    assert _band(score) == expected


def test_no_score_falls_through_the_bands():
    """Every reachable score must map to a band."""
    for score in range(0, 101):
        assert _band(score) in {"green", "yellow", "red"}


def test_score_is_capped_at_100():
    """Firing everything must not exceed the total cap."""
    everything = dict(HERO)
    everything.update({
        "annex_ii_prohibited": True,
        "tender_required": True,
        "tender_conducted": False,
        "agency_blacklisted": True,
        "uc_pending_days": 400,
        "cost_zscore": 9.9,
        "iforest_flag": True,
        "photo_shared_across_agencies": True,
        "max_photo_offset_m": 5000.0,
        "field_observed_status": "not_started",
        "physical_progress_pct": 95,
        "days_overdue": 2000,
        "utilisation_pct": 3.0,
        "days_since_progress_update": 900,
    })
    r = assess(everything)
    assert r.score <= 100
    assert r.band == "red"
    # The displayed reasons must still add up to the gauge exactly.
    assert sum(x.points for x in r.reasons) == r.score


def test_scoring_is_deterministic():
    """Same facts in, byte-identical reasons out."""
    a, b = assess(HERO), assess(HERO)
    assert a.score == b.score
    assert [(x.code, x.points) for x in a.reasons] == [
        (x.code, x.points) for x in b.reasons
    ]


def test_reason_points_always_sum_to_score():
    """The explainability contract, across a spread of fact sets."""
    for overrides in [
        {},
        {"cost_ratio": 1.2},
        {"days_overdue": 500},
        {"nearest_similar_work_m": 2.0},
        {"max_photo_similarity": 0.99},
    ]:
        facts = dict(HERO)
        facts.update(overrides)
        r = assess(facts)
        assert sum(x.points for x in r.reasons) == r.score, overrides


def test_negative_points_never_reduce_a_score():
    """A malformed rule value must be skipped, not subtracted."""
    facts = dict(HERO)
    facts["days_overdue"] = -50
    r = assess(facts)
    assert r.score >= 0
    assert all(x.points >= 0 for x in r.reasons)
