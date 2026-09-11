"""The rulebook and the database schema must agree.

`assess()` is a pure function, so the golden test can score the hero work
without a database - which is exactly how a rulebook category missing from the
DB enum went unnoticed. Four rules carried category "field" while reason_cat_t
did not define it, so any assessment containing one of them failed to INSERT.
One of those rules, MEASUREMENT_MISMATCH, is a reason on MP/2026/1142, so the
demo scenario could never be persisted.

These tests compare the three places a category is declared.
"""

import json
import pathlib

import yaml

from app.models import (
    BANDS,
    RECOMMENDED_ACTIONS,
    SEVERITIES,
    WORK_CATEGORIES,
)
from app.models import REASON_CATEGORIES as ENUM_CATEGORIES

ROOT = pathlib.Path(__file__).parent.parent / "app" / "risk"
RULES = json.loads((ROOT / "rules.json").read_text())
WEIGHTS = yaml.safe_load((ROOT / "weights.yaml").read_text())


def test_every_rule_category_exists_in_the_database_enum():
    used = {r["category"] for r in RULES}
    missing = used - set(ENUM_CATEGORIES)
    assert not missing, (
        f"rules use {sorted(missing)}, which reason_cat_t does not define. "
        "Every assessment containing one of those rules will fail to INSERT."
    )


def test_every_rule_category_has_a_cap():
    used = {r["category"] for r in RULES}
    caps = set(WEIGHTS["category_caps"])
    assert not (used - caps), (
        f"no cap for {sorted(used - caps)}; those points would be uncapped"
    )


def test_caps_and_enum_describe_the_same_categories():
    assert set(WEIGHTS["category_caps"]) == set(ENUM_CATEGORIES)


def test_every_rule_severity_is_storable():
    used = {r["severity"] for r in RULES}
    assert not (used - set(SEVERITIES)), f"unknown severities: {used - set(SEVERITIES)}"


def test_every_band_action_is_storable():
    actions = {spec["action"] for spec in WEIGHTS["bands"].values()}
    assert not (actions - set(RECOMMENDED_ACTIONS))


def test_band_names_match_the_enum():
    assert set(WEIGHTS["bands"]) == set(BANDS)


def test_satellite_category_defaults_cover_every_work_category():
    """A work category with no footprint default silently falls back to
    'other', which would quietly mis-state detectability."""
    from app.satellite import DEFAULT_FOOTPRINT_M2, DEFAULT_WIDTH_M, LINEAR_CATEGORIES

    known = set(DEFAULT_WIDTH_M) | set(DEFAULT_FOOTPRINT_M2) | LINEAR_CATEGORIES
    missing = set(WORK_CATEGORIES) - known
    assert not missing, f"no satellite size default for {sorted(missing)}"
