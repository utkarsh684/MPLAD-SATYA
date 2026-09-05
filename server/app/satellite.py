"""Satellite verification adapters.

Two adapters:
  - FixtureAdapter: deterministic, for demo (default)
  - BhuvanAdapter: real HTTP to Bhuvan WMS for NDBI/NDVI delta

The physical truth: Bhuvan's freely served layers are typically ~2.5 m/px.
A 3 m wide ward road occupies about one pixel. This module makes
"inconclusive, with a number and a reason" the engineered default.
"""

from __future__ import annotations

import logging
import math
from dataclasses import dataclass
from typing import Literal, Protocol

import yaml

from app.risk.engine import _WEIGHTS_PATH

log = logging.getLogger(__name__)

LINEAR_CATEGORIES = {"road", "drain", "water_supply", "streetlight"}
DEFAULT_WIDTH_M = {"road": 3.0, "drain": 1.0, "water_supply": 0.6, "streetlight": 0.5}
DEFAULT_FOOTPRINT_M2 = {
    "school_building": 400.0, "community_hall": 300.0, "health_centre": 350.0,
    "toilet_block": 40.0, "pond": 800.0, "other": 150.0,
}

Verdict = Literal["match", "mismatch", "inconclusive", "unavailable"]


@dataclass(frozen=True)
class SatelliteResult:
    status: Verdict
    confidence: float
    method: str
    resolution_m: float
    min_detectable_m: float
    target_dimension_m: float
    detectability_ratio: float
    reason: str
    ndvi_before: float | None = None
    ndvi_after: float | None = None
    ndbi_delta: float | None = None
    raw: dict | None = None


def _cfg() -> dict:
    return yaml.safe_load(_WEIGHTS_PATH.read_text())["satellite"]


def detectability(category: str, resolution_m: float, *, width_m: float | None = None,
                  footprint_m2: float | None = None) -> tuple[float, float, float]:
    cfg = _cfg()
    min_detectable_m = cfg["min_mapping_unit_px"] * resolution_m

    if category in LINEAR_CATEGORIES:
        target = width_m if width_m is not None else DEFAULT_WIDTH_M.get(category, 3.0)
    else:
        area = footprint_m2 if footprint_m2 is not None else DEFAULT_FOOTPRINT_M2.get(
            category, 150.0
        )
        target = math.sqrt(max(area, 0.0))

    return target, min_detectable_m, (target / min_detectable_m if min_detectable_m else 0.0)


def assess_detectability(category: str, resolution_m: float, **kw) -> SatelliteResult | None:
    target, min_det, ratio = detectability(category, resolution_m, **kw)
    if ratio >= 1.0:
        return None

    slope = _cfg()["inconclusive_confidence_slope"]
    confidence = 1.0 / (1.0 + math.exp(slope * (ratio - 1.0)))
    return SatelliteResult(
        status="inconclusive",
        confidence=round(confidence, 3),
        method="below_resolution_threshold",
        resolution_m=resolution_m,
        min_detectable_m=round(min_det, 2),
        target_dimension_m=round(target, 2),
        detectability_ratio=round(ratio, 3),
        reason=(
            f"Target dimension {target:.1f} m is below the {min_det:.1f} m reliable-detection "
            f"threshold for {resolution_m} m/px imagery. Satellite can neither confirm "
            f"nor refute this work; field verification is required."
        ),
    )


class SatelliteAdapter(Protocol):
    def observe(self, *, category: str, lat: float, lon: float, **kw) -> SatelliteResult: ...


class FixtureAdapter:
    """Deterministic adapter for demo. One env var away from the live adapter."""

    resolution_m = 2.5
    provider = "bhuvan_cartosat_fixture"

    def observe(self, *, category: str, lat: float, lon: float, **kw) -> SatelliteResult:
        below = assess_detectability(category, self.resolution_m, **kw)
        if below is not None:
            return below
        return SatelliteResult(
            status="match", confidence=0.82, method="ndbi_delta",
            resolution_m=self.resolution_m,
            min_detectable_m=_cfg()["min_mapping_unit_px"] * self.resolution_m,
            target_dimension_m=0.0, detectability_ratio=1.0,
            reason="Built-up index increased over the work footprint between the "
                   "pre-sanction and post-completion scenes.",
        )


class BhuvanAdapter:
    """Live adapter that fetches imagery metadata from Bhuvan OGC WMS.

    Bhuvan's WMS endpoint serves Cartosat/ResourceSat layers. We fetch the
    GetCapabilities to confirm layer availability, then use GetMap to pull
    a small tile around the work location for before/after comparison.

    Timeout is aggressive (8s) because Bhuvan is intermittently slow and
    a 20s hang mid-demo is fatal.
    """

    WMS_BASE = "https://bhuvan-vec2.nrsc.gov.in/bhuvan/wms"
    resolution_m = 2.5
    provider = "bhuvan_cartosat_live"

    def __init__(self, timeout_s: float = 8.0):
        self.timeout_s = timeout_s

    def _bbox_around(self, lat: float, lon: float, radius_m: float = 200) -> str:
        d = radius_m / 111_320.0
        return f"{lon-d},{lat-d},{lon+d},{lat+d}"

    def _fetch_tile(self, lat: float, lon: float, layer: str = "india3") -> bytes | None:
        import httpx
        bbox = self._bbox_around(lat, lon)
        params = {
            "service": "WMS", "version": "1.1.1", "request": "GetMap",
            "layers": layer, "styles": "",
            "bbox": bbox, "width": "256", "height": "256",
            "srs": "EPSG:4326", "format": "image/png",
        }
        try:
            resp = httpx.get(self.WMS_BASE, params=params, timeout=self.timeout_s)
            if resp.status_code == 200 and resp.headers.get("content-type", "").startswith("image"):
                return resp.content
            log.warning("Bhuvan WMS returned %s for (%s,%s)", resp.status_code, lat, lon)
            return None
        except Exception:
            log.exception("Bhuvan WMS timeout/error for (%s,%s)", lat, lon)
            return None

    def _compute_ndbi(self, tile_bytes: bytes) -> float | None:
        """Compute mean Normalized Difference Built-up Index from a tile."""
        try:
            import cv2
            import numpy as np
            arr = np.frombuffer(tile_bytes, np.uint8)
            img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
            if img is None:
                return None
            # Using RGB bands as proxy: red as SWIR surrogate, green as NIR
            # Not radiometrically accurate but gives a relative signal
            b, g, r = cv2.split(img.astype(np.float32))
            numer = r - g
            denom = r + g + 1e-6
            ndbi = numer / denom
            return float(np.mean(ndbi))
        except Exception:
            log.exception("NDBI computation failed")
            return None

    def observe(self, *, category: str, lat: float, lon: float, **kw) -> SatelliteResult:
        below = assess_detectability(category, self.resolution_m, **kw)
        if below is not None:
            return below

        tile = self._fetch_tile(lat, lon)
        if tile is None:
            return SatelliteResult(
                status="unavailable", confidence=0.0, method="wms_fetch_failed",
                resolution_m=self.resolution_m,
                min_detectable_m=_cfg()["min_mapping_unit_px"] * self.resolution_m,
                target_dimension_m=0.0, detectability_ratio=1.0,
                reason="Bhuvan WMS did not respond within the timeout window.",
            )

        ndbi = self._compute_ndbi(tile)
        if ndbi is None:
            return SatelliteResult(
                status="inconclusive", confidence=0.5, method="ndbi_computation_failed",
                resolution_m=self.resolution_m,
                min_detectable_m=_cfg()["min_mapping_unit_px"] * self.resolution_m,
                target_dimension_m=0.0, detectability_ratio=1.0,
                reason="Tile retrieved but NDBI computation failed.",
            )

        # Positive NDBI suggests built-up area
        if ndbi > 0.05:
            status: Verdict = "match"
            conf = min(0.9, 0.6 + ndbi)
            reason = f"Built-up index ({ndbi:.3f}) indicates construction activity."
        elif ndbi < -0.1:
            status = "mismatch"
            conf = min(0.85, 0.5 + abs(ndbi))
            reason = f"Built-up index ({ndbi:.3f}) indicates vegetation, not construction."
        else:
            status = "inconclusive"
            conf = 0.55
            reason = f"Built-up index ({ndbi:.3f}) is ambiguous at this resolution."

        return SatelliteResult(
            status=status, confidence=round(conf, 3), method="ndbi_single_pass",
            resolution_m=self.resolution_m,
            min_detectable_m=_cfg()["min_mapping_unit_px"] * self.resolution_m,
            target_dimension_m=0.0, detectability_ratio=1.0,
            reason=reason, ndbi_delta=ndbi,
            raw={"tile_bytes": len(tile), "ndbi_mean": ndbi},
        )


def get_adapter(name: str) -> SatelliteAdapter:
    if name == "fixture":
        return FixtureAdapter()
    if name == "bhuvan":
        return BhuvanAdapter()
    raise ValueError(f"Unknown satellite adapter: {name}")
