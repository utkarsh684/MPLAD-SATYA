"""Satellite verification adapters.

Two adapters:
  - FixtureAdapter: deterministic, for demo (default)
  - BhuvanAdapter: real HTTP to Bhuvan OGC WMS

The physical truth: Bhuvan's freely served layers are typically ~2.5 m/px.
A 3 m wide ward road occupies about one pixel. This module makes
"inconclusive, with a number and a reason" the engineered default.

Nothing here computes NDBI. See BhuvanAdapter._brightness_index for why a
rendered visual tile cannot yield one, and BhuvanAdapter's class docstring for
what the public endpoint was measured to actually serve.
"""

from __future__ import annotations

import logging
import math
import re
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
    reason: str

    # Detectability is None whenever it was not computed. A 0.0 here would
    # assert "this target has zero size", and a 1.0 ratio would assert "exactly
    # at the detection limit" -- both are fabricated measurements.
    min_detectable_m: float | None = None
    target_dimension_m: float | None = None
    detectability_ratio: float | None = None

    ndvi_before: float | None = None
    ndvi_after: float | None = None

    # Brightness contrast index, NOT NDBI. See BhuvanAdapter._brightness_index:
    # Bhuvan's public WMS serves a rendered visual PNG with no SWIR or NIR band,
    # so a true Normalized Difference Built-up Index cannot be computed from it.
    # Named for what it is so no downstream screen can imply otherwise.
    brightness_index: float | None = None

    # True only when the value came from comparing two scenes captured at
    # different times. A single pass cannot evidence change.
    is_temporal_comparison: bool = False

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
    """Deterministic adapter for demo. One env var away from the live adapter.

    Its output is synthetic and says so in its own reason text. A fixture that
    narrates a plausible-sounding observation ("built-up index increased
    between the pre-sanction and post-completion scenes") is indistinguishable
    from a real finding once it is quoted in a file note, so this one states
    its own nature in the sentence a human will read.
    """

    resolution_m = 2.5
    provider = "bhuvan_cartosat_fixture"

    def observe(self, *, category: str, lat: float, lon: float, **kw) -> SatelliteResult:
        below = assess_detectability(category, self.resolution_m, **kw)
        if below is not None:
            return below

        target, min_det, ratio = detectability(category, self.resolution_m, **kw)
        return SatelliteResult(
            status="match", confidence=0.82, method="fixture_synthetic",
            resolution_m=self.resolution_m,
            min_detectable_m=round(min_det, 2),
            target_dimension_m=round(target, 2),
            detectability_ratio=round(ratio, 3),
            reason=(
                "SYNTHETIC RESULT - no imagery was retrieved. The offline "
                "fixture adapter returns a deterministic 'consistent' verdict "
                "for works above the resolution threshold so the demo is "
                "reproducible without network access. Set "
                "SATELLITE_ADAPTER=bhuvan for a live observation."
            ),
        )


class BhuvanAdapter:
    """Live adapter that fetches imagery metadata from Bhuvan OGC WMS.

    Timeout is aggressive (8s) because Bhuvan is intermittently slow and
    a 20s hang mid-demo is fatal.

    WHAT THE PUBLIC ENDPOINT ACTUALLY SERVES (verified 2026-09-10)
    -------------------------------------------------------------
    `bhuvan-vec2` is a GeoServer publishing *thematic vector* layers, not raw
    Cartosat imagery. Measured against the live service:

      * the previously hardcoded layer `india3` does not exist -> the service
        answers HTTP 200 with an OGC ServiceException `LayerNotDefined`, so
        this adapter has never once returned a live reading;
      * layers that do exist (`LULC_BUILTUP`, `lulc:GANGA_LULC`, ...) answer
        HTTP 200 `image/png` with a *flat single-colour* 256x256 tile that is
        byte-identical for Bhopal and for Delhi.

    That second point is the dangerous one. A flat red fill scores +0.996 on
    the brightness index, so simply "fixing" the layer name would have made
    every work in India report the same confident built-up signature -- exactly
    the fabricated evidence this module exists to avoid.

    Real per-location imagery from Bhuvan requires a registered API key, which
    this build does not carry. Until one is provisioned the honest outcome of a
    live call is `unavailable`, and `_is_degenerate_tile` enforces that no
    matter which layer is configured.
    """

    WMS_BASE = "https://bhuvan-vec2.nrsc.gov.in/bhuvan/wms"
    resolution_m = 2.5
    provider = "bhuvan_cartosat_live"

    # Configurable rather than hardcoded, so provisioning a real layer (or a
    # keyed endpoint) is a config change and not a code change.
    DEFAULT_LAYER = "LULC_BUILTUP"

    def __init__(self, timeout_s: float = 8.0, layer: str | None = None):
        self.timeout_s = timeout_s
        self.layer = layer or self.DEFAULT_LAYER
        # Populated by _fetch_tile so observe() can report why a call failed
        # instead of collapsing every failure into one message.
        self.last_failure: str | None = None

    def _bbox_around(self, lat: float, lon: float, radius_m: float = 200) -> str:
        """A square-on-the-ground bbox in EPSG:4326.

        A degree of latitude is ~111.32 km everywhere, but a degree of
        longitude shrinks by cos(latitude): ~102 km at 23 deg N. Dividing both
        deltas by 111 320 (the previous behaviour) produced a box about 8 %
        narrower in x than in y at Indian latitudes, so the sampled area was
        not the area we claimed to sample.
        """
        d_lat = radius_m / 111_320.0
        cos_lat = math.cos(math.radians(lat))
        # Guard the poles, where a longitude degree collapses to zero.
        d_lon = radius_m / (111_320.0 * max(abs(cos_lat), 1e-6))
        return f"{lon-d_lon},{lat-d_lat},{lon+d_lon},{lat+d_lat}"

    def _fetch_tile(self, lat: float, lon: float, layer: str | None = None) -> bytes | None:
        """GetMap around the work. Returns None and sets `last_failure`.

        An OGC service is allowed to answer HTTP 200 with an XML
        ServiceExceptionReport, so status alone proves nothing -- the
        content-type check is what actually decides whether we got imagery.
        """
        import httpx

        self.last_failure = None
        layer = layer or self.layer
        bbox = self._bbox_around(lat, lon)
        params = {
            "service": "WMS", "version": "1.1.1", "request": "GetMap",
            "layers": layer, "styles": "",
            "bbox": bbox, "width": "256", "height": "256",
            "srs": "EPSG:4326", "format": "image/png",
        }
        try:
            resp = httpx.get(self.WMS_BASE, params=params, timeout=self.timeout_s)
        except Exception as exc:
            log.warning("Bhuvan WMS transport error for (%s,%s): %r", lat, lon, exc)
            self.last_failure = f"network error contacting Bhuvan ({type(exc).__name__})"
            return None

        content_type = resp.headers.get("content-type", "")
        if resp.status_code == 200 and content_type.startswith("image"):
            return resp.content

        if "xml" in content_type:
            # Surface the actual OGC reason -- "LayerNotDefined" is a
            # configuration bug on our side, not a Bhuvan outage, and the two
            # must not read the same in a log or on screen.
            match = re.search(r'code="([^"]+)"', resp.text)
            code = match.group(1) if match else "ServiceException"
            self.last_failure = f"Bhuvan rejected the request ({code}, layer '{layer}')"
        else:
            self.last_failure = (
                f"Bhuvan returned HTTP {resp.status_code} ({content_type or 'no content-type'})"
            )
        log.warning("Bhuvan WMS: %s", self.last_failure)
        return None

    @staticmethod
    def _is_degenerate_tile(tile_bytes: bytes) -> bool:
        """True when a tile carries no location-specific information.

        The public endpoint answers valid-looking `image/png` for layers that
        exist, but the payload is a flat single-colour fill that is
        byte-identical for Bhopal and Delhi. Measuring anything from such a
        tile produces a confident number that is the same everywhere, which is
        worse than no reading at all.

        Spatial standard deviation *within* each channel is the discriminator:
        a flat fill is ~0 per channel even when the channels differ wildly
        from each other, so a naive std() over the whole array does not catch
        it (the verified red fill scores 120 that way, and 9.8 this way).
        """
        try:
            import cv2
            import numpy as np

            img = cv2.imdecode(np.frombuffer(tile_bytes, np.uint8), cv2.IMREAD_COLOR)
            if img is None:
                return True
            per_channel_std = img.reshape(-1, img.shape[-1]).std(axis=0)
            return bool(np.max(per_channel_std) < 12.0)
        except Exception:
            log.exception("Degenerate-tile check failed")
            return True

    def _brightness_index(self, tile_bytes: bytes) -> float | None:
        """Mean red-green contrast over the tile. This is NOT NDBI.

        NDBI is (SWIR - NIR) / (SWIR + NIR). Bhuvan's public WMS returns a
        rendered visual PNG: three 8-bit display channels, no SWIR, no NIR, and
        an unknown rendering curve applied upstream. The previous version of
        this method computed (R - G) / (R + G) and returned it as `ndbi_delta`,
        which is a different quantity wearing a remote-sensing name.

        What (R - G) / (R + G) does capture is that bare concrete and laterite
        read warmer than vegetation in a visual composite. That is a weak
        corroborating hint, not an index, and everything downstream treats it
        as such: it can never on its own establish that construction occurred.
        """
        try:
            import cv2
            import numpy as np

            arr = np.frombuffer(tile_bytes, np.uint8)
            img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
            if img is None:
                return None

            _b, g, r = cv2.split(img.astype(np.float32))
            index = (r - g) / (r + g + 1e-6)

            # A tile that is entirely transparent, black or clipped yields
            # NaN/inf here. Propagating that would render as a real number.
            finite = index[np.isfinite(index)]
            if finite.size == 0:
                return None
            value = float(np.mean(finite))
            if not math.isfinite(value):
                return None
            # The ratio is mathematically bounded to [-1, 1]; clamp defensively
            # so a malformed tile cannot emit an out-of-range value.
            return max(-1.0, min(1.0, value))
        except Exception:
            log.exception("Brightness index computation failed")
            return None

    def observe(self, *, category: str, lat: float, lon: float, **kw) -> SatelliteResult:
        below = assess_detectability(category, self.resolution_m, **kw)
        if below is not None:
            return below

        target, min_det, ratio = detectability(category, self.resolution_m, **kw)
        geometry = {
            "min_detectable_m": round(min_det, 2),
            "target_dimension_m": round(target, 2),
            "detectability_ratio": round(ratio, 3),
        }

        tile = self._fetch_tile(lat, lon)
        if tile is None:
            return SatelliteResult(
                status="unavailable", confidence=0.0, method="wms_fetch_failed",
                resolution_m=self.resolution_m, **geometry,
                reason=(
                    f"No imagery retrieved: {self.last_failure or 'Bhuvan did not respond'}. "
                    "No satellite evidence is available for this work; this is a "
                    "service or configuration problem, not a finding about the work."
                ),
                raw={"layer": self.layer, "failure": self.last_failure},
            )

        # A tile that looks like an image but is identical everywhere is not
        # evidence. Measuring it would emit the same confident reading for
        # every work in the country.
        if self._is_degenerate_tile(tile):
            return SatelliteResult(
                status="unavailable", confidence=0.0, method="degenerate_tile",
                resolution_m=self.resolution_m, **geometry,
                reason=(
                    "Bhuvan returned a uniform tile carrying no location-specific "
                    "detail. The public endpoint serves thematic vector layers "
                    "rather than per-location imagery; a registered API key is "
                    "required for usable scenes. No satellite evidence is "
                    "available for this work."
                ),
                raw={
                    "layer": self.layer,
                    "tile_bytes": len(tile),
                    "reject_reason": "uniform_fill_no_spatial_variance",
                },
            )

        index = self._brightness_index(tile)
        if index is None:
            return SatelliteResult(
                status="unavailable", confidence=0.0,
                method="index_computation_failed",
                resolution_m=self.resolution_m, **geometry,
                reason=(
                    "Imagery was retrieved but could not be decoded into a "
                    "usable measurement. No satellite evidence is available."
                ),
            )

        # A SINGLE SCENE CANNOT EVIDENCE CHANGE.
        #
        # The previous version returned `match` -- "indicates construction
        # activity" -- from one tile. A road that has existed for twenty years
        # produces exactly the same signal as one built last month, so that
        # verdict was unsupportable by the data behind it. Establishing that
        # construction occurred requires a pre-sanction scene and a
        # post-completion scene, which the free WMS endpoint does not expose.
        #
        # So a live single-pass observation tops out at `inconclusive`, and the
        # index travels as a corroborating hint that a human can weigh. This
        # keeps the reading real and its claim proportionate.
        if index > 0.05:
            reading = (
                f"Surface reads as bare or built-up (brightness contrast "
                f"{index:+.3f}), consistent with an existing structure."
            )
        elif index < -0.10:
            reading = (
                f"Surface reads as vegetated (brightness contrast "
                f"{index:+.3f}), with no built-up signature at this location."
            )
        else:
            reading = (
                f"Surface signature is ambiguous (brightness contrast "
                f"{index:+.3f})."
            )

        return SatelliteResult(
            status="inconclusive",
            # Deliberately modest and fixed. A confidence that scales with the
            # index would imply the index measures what we want it to measure.
            confidence=0.4,
            method="visual_brightness_single_pass",
            resolution_m=self.resolution_m,
            **geometry,
            reason=(
                f"{reading} This is a single-date visual observation, so it "
                f"cannot establish whether the work was actually carried out - "
                f"that needs a before-and-after pair. Treat as a hint; field "
                f"verification remains the deciding evidence."
            ),
            brightness_index=index,
            is_temporal_comparison=False,
            raw={
                "layer": self.layer,
                "tile_bytes": len(tile),
                "brightness_index_mean": index,
                "index_definition": "(R-G)/(R+G) over a rendered visual tile",
                "not_ndbi_because": "WMS visual PNG carries no SWIR or NIR band",
            },
        )


def get_adapter(name: str) -> SatelliteAdapter:
    if name == "fixture":
        return FixtureAdapter()
    if name == "bhuvan":
        return BhuvanAdapter()
    raise ValueError(f"Unknown satellite adapter: {name}")
