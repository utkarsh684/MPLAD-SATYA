"""Derive the four source verdicts and the Evidence Consistency percentage.

An INCONCLUSIVE source is excluded from the denominator rather than counted as
disagreement. Treating "the sensor cannot see this" as evidence of wrongdoing is
the single most common way an audit system manufactures false accusations.
"""

from __future__ import annotations

from dataclasses import dataclass


def _source_weights() -> dict[str, float]:
    """Loaded from weights.yaml so the calibration is inspectable via the API."""
    import yaml

    from app.risk.engine import _WEIGHTS_PATH

    return yaml.safe_load(_WEIGHTS_PATH.read_text())["consistency_source_weights"]

AGREEMENT = {"match": 1.0, "available": 1.0, "mismatch": 0.0, "inconclusive": None}


@dataclass(frozen=True)
class SourceVerdict:
    source: str
    status: str
    headline: str
    confidence: float | None = None
    observed_value: float | None = None
    expected_value: float | None = None
    observed_unit: str | None = None
    report_count: int = 0


def build_verdicts(facts: dict) -> list[SourceVerdict]:
    out: list[SourceVerdict] = []

    # 1. Official record - present by definition if we have a work at all.
    out.append(
        SourceVerdict(
            source="official_record",
            status="available",
            headline="Available",
            confidence=1.0,
        )
    )

    # 2. Satellite.
    sat_status = facts.get("satellite_status")
    if sat_status is None:
        out.append(SourceVerdict("satellite", "unavailable", "No imagery", None))
    else:
        conf = facts.get("satellite_confidence")
        pct = f"{round((conf or 0) * 100)}% confidence"
        headline = {
            "inconclusive": f"Inconclusive - {pct}",
            "match": f"Consistent - {pct}",
            "mismatch": f"Mismatch - {pct}",
        }.get(sat_status, sat_status.title())
        out.append(SourceVerdict("satellite", sat_status, headline, conf))

    # 3. Citizen.
    reports = facts.get("citizen_mismatch_reports") or 0
    if reports:
        out.append(
            SourceVerdict(
                "citizen", "mismatch",
                f"Mismatch - {reports} report{'s' if reports != 1 else ''}",
                confidence=1.0, report_count=reports,
            )
        )
    else:
        out.append(SourceVerdict("citizen", "unavailable", "No citizen reports", None))

    # 4. Field / AR measurement.
    measured = facts.get("field_measured_value")
    sanctioned = facts.get("sanctioned_qty")
    unit = facts.get("qty_unit") or ""
    if measured is None or sanctioned is None:
        out.append(SourceVerdict("field", "unavailable", "Not yet verified", None))
    else:
        shortfall = facts.get("measurement_shortfall_pct") or 0.0
        status = "mismatch" if shortfall >= 10 else "match"
        headline = (
            f"Mismatch - {measured:g} {unit} vs {sanctioned:g} {unit}"
            if status == "mismatch"
            else f"Consistent - {measured:g} {unit}"
        )
        out.append(
            SourceVerdict(
                "field", status, headline, confidence=1.0,
                observed_value=measured, expected_value=sanctioned, observed_unit=unit,
            )
        )
    return out


def consistency_pct(verdicts: list[SourceVerdict]) -> int:
    """Weighted agreement across sources that actually have something to say."""
    weights = _source_weights()
    numerator = 0.0
    denominator = 0.0
    for v in verdicts:
        agreement = AGREEMENT.get(v.status)
        if agreement is None or v.status == "unavailable":
            # Inconclusive and unavailable sources are excluded entirely.
            continue
        weight = weights.get(v.source, 1.0)
        numerator += agreement * weight
        denominator += weight
    if denominator == 0:
        return 0
    return round(numerator / denominator * 100)
