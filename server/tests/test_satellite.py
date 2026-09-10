"""Tests for satellite detectability and adapter logic."""

import math

from app.satellite import (
    BhuvanAdapter,
    FixtureAdapter,
    SatelliteResult,
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


# --------------------------------------------------------------------------
# Provenance and null-semantics guarantees.
#
# These pin the promises the UI makes to a judge. If any of them fails, the
# app is claiming something the data does not support.
# --------------------------------------------------------------------------

class _StubResponse:
    def __init__(self, content=b"", status_code=200, content_type="image/png"):
        self.content = content
        self.status_code = status_code
        self.headers = {"content-type": content_type}


def _flat_png(colour: tuple[int, int, int], size: int = 64) -> bytes:
    """A uniform single-colour PNG -- what the public Bhuvan WMS actually
    returns, and what must be rejected as carrying no information."""
    import cv2
    import numpy as np

    b, g, r = colour
    img = np.zeros((size, size, 3), np.uint8)
    img[:, :] = (b, g, r)
    ok, buf = cv2.imencode(".png", img)
    assert ok
    return buf.tobytes()


def _png_bytes(colour: tuple[int, int, int], size: int = 64) -> bytes:
    """A *textured* PNG around the given colour.

    Real imagery has spatial variance; a flat fill does not and is rejected by
    the degenerate-tile guard. Tests that want to exercise the measurement path
    must therefore supply something that looks like a scene.
    """
    import cv2
    import numpy as np

    rng = np.random.default_rng(42)
    b, g, r = colour
    base = np.zeros((size, size, 3), np.float32)
    base[:, :] = (b, g, r)
    base += rng.normal(0, 30, base.shape)
    img = np.clip(base, 0, 255).astype(np.uint8)
    ok, buf = cv2.imencode(".png", img)
    assert ok
    return buf.tobytes()


def test_bbox_is_square_on_the_ground():
    """A degree of longitude is shorter than a degree of latitude in India."""
    adapter = BhuvanAdapter()
    min_lon, min_lat, max_lon, max_lat = (
        float(x) for x in adapter._bbox_around(23.2599, 77.4126, radius_m=200).split(",")
    )
    d_lat_m = (max_lat - min_lat) / 2 * 111_320.0
    d_lon_m = (max_lon - min_lon) / 2 * 111_320.0 * math.cos(math.radians(23.2599))
    # Both half-widths must be the requested 200 m on the ground.
    assert abs(d_lat_m - 200) < 1
    assert abs(d_lon_m - 200) < 1


def test_single_pass_never_claims_a_match(monkeypatch):
    """One scene cannot evidence that construction happened.

    A road that has existed for twenty years produces the same bright signal
    as one built last month, so a live single-date observation must top out at
    `inconclusive` no matter how built-up the surface reads.
    """
    adapter = BhuvanAdapter()
    monkeypatch.setattr(
        "httpx.get", lambda *a, **kw: _StubResponse(_png_bytes((10, 10, 250)))
    )
    result = adapter.observe(category="school_building", lat=23.26, lon=77.41)

    assert result.status == "inconclusive"
    assert result.is_temporal_comparison is False
    assert result.brightness_index is not None
    assert result.brightness_index > 0.05  # strongly "built-up" looking
    # ...and it still refuses to call it a match.
    assert "cannot establish" in result.reason


def test_wms_failure_is_unavailable_not_a_finding(monkeypatch):
    """A service outage must never read as evidence about the work."""
    adapter = BhuvanAdapter()
    monkeypatch.setattr("httpx.get", lambda *a, **kw: _StubResponse(status_code=503))
    result = adapter.observe(category="school_building", lat=23.26, lon=77.41)

    assert result.status == "unavailable"
    assert result.confidence == 0.0
    assert result.brightness_index is None
    assert "outage" in result.reason or "not a finding" in result.reason


def test_wms_timeout_is_unavailable(monkeypatch):
    def _boom(*a, **kw):
        raise TimeoutError("slow")

    adapter = BhuvanAdapter()
    monkeypatch.setattr("httpx.get", _boom)
    result = adapter.observe(category="school_building", lat=23.26, lon=77.41)
    assert result.status == "unavailable"


def test_undecodable_tile_is_unavailable_not_zero(monkeypatch):
    """Garbage bytes must not become a 0.0 index that reads as a measurement."""
    adapter = BhuvanAdapter()
    monkeypatch.setattr(
        "httpx.get", lambda *a, **kw: _StubResponse(b"not-an-image")
    )
    result = adapter.observe(category="school_building", lat=23.26, lon=77.41)

    assert result.status == "unavailable"
    assert result.brightness_index is None


def test_brightness_index_is_finite_and_bounded():
    """NaN or inf must never escape as a rendered number."""
    adapter = BhuvanAdapter()
    # Pure black: r+g == 0, so the naive ratio is 0/0.
    value = adapter._brightness_index(_png_bytes((0, 0, 0)))
    assert value is None or (math.isfinite(value) and -1.0 <= value <= 1.0)

    for colour in [(255, 255, 255), (0, 255, 0), (0, 0, 255)]:
        v = adapter._brightness_index(_png_bytes(colour))
        assert v is not None
        assert math.isfinite(v)
        assert -1.0 <= v <= 1.0


def test_detectability_is_never_fabricated():
    """Unmeasured geometry stays None rather than becoming 0.0/1.0."""
    unknown = SatelliteResult(
        status="unavailable", confidence=0.0, method="x",
        resolution_m=2.5, reason="y",
    )
    assert unknown.min_detectable_m is None
    assert unknown.target_dimension_m is None
    assert unknown.detectability_ratio is None


def test_fixture_declares_itself_synthetic():
    """The fixture's reason text must not read as a real observation.

    Once a sentence is pasted into a file note it loses its LIVE/FIXTURE chip,
    so the sentence itself has to carry the disclosure.
    """
    result = FixtureAdapter().observe(
        category="school_building", lat=23.26, lon=77.41
    )
    assert result.method == "fixture_synthetic"
    assert "SYNTHETIC" in result.reason
    # And it reports the real detectability geometry, not placeholders.
    assert result.target_dimension_m == 20.0
    assert result.detectability_ratio is not None


def test_inconclusive_carries_real_geometry():
    result = assess_detectability("road", 2.5)
    assert result is not None
    assert result.target_dimension_m == 3.0
    assert result.min_detectable_m == 7.5
    assert result.detectability_ratio is not None
    assert result.brightness_index is None


# --------------------------------------------------------------------------
# Degenerate-tile guard.
#
# Verified against the live service on 2026-09-10: the public Bhuvan WMS
# answers HTTP 200 image/png for layers that exist, but the payload is a flat
# single-colour fill that is byte-identical for Bhopal and for Delhi. Scoring
# such a tile yields +0.996 -- an identical confident "built-up" reading for
# every work in India. These tests exist so that can never ship.
# --------------------------------------------------------------------------


def test_uniform_tile_is_rejected_as_evidence(monkeypatch):
    adapter = BhuvanAdapter()
    monkeypatch.setattr(
        "httpx.get", lambda *a, **kw: _StubResponse(_flat_png((10, 10, 250)))
    )
    result = adapter.observe(category="school_building", lat=23.26, lon=77.41)

    assert result.status == "unavailable"
    assert result.method == "degenerate_tile"
    assert result.brightness_index is None
    assert result.confidence == 0.0


def test_uniform_tile_verdict_does_not_vary_by_location(monkeypatch):
    """The failure mode this guard exists for: same answer everywhere."""
    adapter = BhuvanAdapter()
    monkeypatch.setattr(
        "httpx.get", lambda *a, **kw: _StubResponse(_flat_png((10, 10, 250)))
    )
    bhopal = adapter.observe(category="school_building", lat=23.26, lon=77.41)
    delhi = adapter.observe(category="school_building", lat=28.61, lon=77.20)

    # Identical input must yield an honest "no evidence" at both, never an
    # identical confident measurement presented as a per-site finding.
    assert bhopal.status == delhi.status == "unavailable"
    assert bhopal.brightness_index is delhi.brightness_index is None


def test_flat_fill_is_detected_regardless_of_colour():
    adapter = BhuvanAdapter()
    for colour in [(10, 10, 250), (255, 255, 255), (0, 0, 0), (128, 64, 200)]:
        assert adapter._is_degenerate_tile(_flat_png(colour)) is True


def test_textured_tile_is_accepted():
    adapter = BhuvanAdapter()
    assert adapter._is_degenerate_tile(_png_bytes((120, 120, 120))) is False


def test_layer_not_defined_names_the_configuration_fault(monkeypatch):
    """An OGC ServiceException arrives as HTTP 200 with XML, not as an error
    status. It must be distinguishable from a Bhuvan outage."""
    xml = (
        '<?xml version="1.0"?><ServiceExceptionReport version="1.1.1">'
        '<ServiceException code="LayerNotDefined" locator="layers">'
        "Could not find layer india3</ServiceException></ServiceExceptionReport>"
    )

    class _Xml:
        status_code = 200
        headers = {"content-type": "application/vnd.ogc.se_xml;charset=UTF-8"}
        text = xml
        content = xml.encode()

    adapter = BhuvanAdapter()
    monkeypatch.setattr("httpx.get", lambda *a, **kw: _Xml())
    result = adapter.observe(category="school_building", lat=23.26, lon=77.41)

    assert result.status == "unavailable"
    assert "LayerNotDefined" in (adapter.last_failure or "")
    assert "not a finding about the work" in result.reason


def test_layer_is_configurable_not_hardcoded():
    assert BhuvanAdapter(layer="custom:layer").layer == "custom:layer"
    assert BhuvanAdapter().layer == BhuvanAdapter.DEFAULT_LAYER
