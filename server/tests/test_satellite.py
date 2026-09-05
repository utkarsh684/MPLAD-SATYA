"""Tests for satellite detectability and adapter logic."""

from app.satellite import (
    BhuvanAdapter,
    FixtureAdapter,
    assess_detectability,
    detectability,
)


def test_road_below_resolution():
    """A 3m wide road at 2.5 m/px → inconclusive."""
    result = assess_detectability("road", 2.5)
    assert result is not None
    assert result.status == "inconclusive"
    assert 0.5 < result.confidence < 0.8


def test_building_above_resolution():
    """A school building (20m x 20m) at 2.5 m/px → detectable, returns None."""
    result = assess_detectability("school_building", 2.5)
    assert result is None  # large enough, caller should run the real check


def test_fixture_adapter_road():
    adapter = FixtureAdapter()
    result = adapter.observe(category="road", lat=23.26, lon=77.41)
    assert result.status == "inconclusive"
    assert result.confidence > 0


def test_fixture_adapter_building():
    adapter = FixtureAdapter()
    result = adapter.observe(category="school_building", lat=23.26, lon=77.41)
    assert result.status == "match"
    assert result.confidence > 0.5


def test_detectability_ratio():
    target, min_det, ratio = detectability("road", 2.5)
    assert target == 3.0  # default road width
    assert min_det == 7.5  # 3 * 2.5
    assert ratio < 1.0  # below detectable


def test_bhuvan_adapter_exists():
    """BhuvanAdapter can be instantiated (doesn't need network)."""
    adapter = BhuvanAdapter(timeout_s=1.0)
    assert adapter.provider == "bhuvan_cartosat_live"
    assert adapter.WMS_BASE.startswith("https://")
