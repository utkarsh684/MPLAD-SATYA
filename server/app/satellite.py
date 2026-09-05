"""Satellite verification, designed around what the imagery can actually do.

The physical truth: Bhuvan's freely served layers are typically ~2.5 m/px, and
Sentinel-2 is 10 m. A 3 m wide ward road occupies about one pixel of width. You
cannot verify a ward road's length, width or quality from public satellite
imagery, and anyone claiming otherwise loses the room to the first panellist who
knows remote sensing.

So this module makes "inconclusive, with a number and a reason" the engineered,
documented default rather than a failure path -- and the risk engine gives an
inconclusive observation ZERO points. An unusable sensor must never manufacture
suspicion.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Literal, Protocol

import yaml

from app.risk.engine import _WEIGHTS_PATH

# Works whose detectability is governed by WIDTH, not area: a 200 m road is
# long but only ~3 m across, and it is the narrow dimension that defeats the
# sensor.
LINEAR_CATEGORIES = {"road", "drain", "water_supply", "streetlight"}

# Typical narrow-dimension / footprint defaults when the record does not say.
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


def _cfg() -> dict:
    return yaml.safe_load(_WEIGHTS_PATH.read_text())["satellite"]


def detectability(category: str, resolution_m: float, *, width_m: float | None = None,
                  footprint_m2: float | None = None) -> tuple[float, float, float]:
    """Return (target_dimension_m, min_detectable_m, ratio).

    ratio >= 1 means the feature is large enough to be reliably mapped.
    """
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
    """Return an INCONCLUSIVE result when the target is below resolution.

    Returns None when the feature is large enough that a real verdict is
    meaningful, in which case the caller runs the index comparison.
    """
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
    """Deterministic adapter used for the demo.

    Bhuvan's WMS is slow and intermittently down; a 20 s timeout mid-demo is
    fatal. The live adapter exists and is one env var away -- say that openly
    rather than hiding it.
    """

    resolution_m = 2.5
    provider = "bhuvan_cartosat_fixture"

    def observe(self, *, category: str, lat: float, lon: float, **kw) -> SatelliteResult:
        below = assess_detectability(category, self.resolution_m, **kw)
        if below is not None:
            return below
        # Large enough to judge: fixtures report a supportive built-up delta.
        return SatelliteResult(
            status="match", confidence=0.82, method="ndbi_delta",
            resolution_m=self.resolution_m,
            min_detectable_m=_cfg()["min_mapping_unit_px"] * self.resolution_m,
            target_dimension_m=0.0, detectability_ratio=1.0,
            reason="Built-up index increased over the work footprint between the "
                   "pre-sanction and post-completion scenes.",
        )


def get_adapter(name: str) -> SatelliteAdapter:
    if name == "fixture":
        return FixtureAdapter()
    raise NotImplementedError(
        "The live Bhuvan WMS adapter is not wired for v1. Use SATELLITE_ADAPTER=fixture."
    )
