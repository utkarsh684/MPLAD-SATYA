"""ORM -> response model conversion, in one place."""

from __future__ import annotations

import yaml
from geoalchemy2.shape import to_shape

from app.models import RiskAssessment, Work
from app.risk.engine import _WEIGHTS_PATH
from app.schemas import Money, RiskAssessmentOut, RiskReasonOut, WorkDetail, WorkSummary


def _weights() -> dict:
    return yaml.safe_load(_WEIGHTS_PATH.read_text())


def band_label(band: str | None) -> str | None:
    if not band:
        return None
    return _weights()["bands"].get(band, {}).get("label")


def latlon(geom) -> tuple[float | None, float | None]:
    if geom is None:
        return None, None
    point = to_shape(geom)
    return point.y, point.x


def distance_label(metres: float | None) -> str | None:
    if metres is None:
        return None
    if metres < 1000:
        return f"{round(metres)} m away"
    return f"{metres / 1000:.1f} km away"


def work_summary(work: Work, *, distance_m: float | None = None) -> WorkSummary:
    lat, lon = latlon(work.location)
    ra = work.current_assessment
    return WorkSummary(
        id=work.id,
        work_code=work.work_code,
        title=work.title,
        category=work.category,
        status=work.status,
        ward=work.ward,
        district_name=work.district.name if work.district else None,
        sanctioned_amount=Money.of(work.sanctioned_amount_paise),
        risk_score=ra.score if ra else None,
        risk_band=ra.band if ra else None,
        band_label=band_label(ra.band) if ra else None,
        lat=lat,
        lon=lon,
        distance_m=round(distance_m, 1) if distance_m is not None else None,
        distance_label=distance_label(distance_m),
    )


def work_detail(work: Work) -> WorkDetail:
    base = work_summary(work).model_dump()
    return WorkDetail(
        **base,
        description=work.description,
        implementing_agency=work.implementing_agency,
        sanctioned_qty=float(work.sanctioned_qty) if work.sanctioned_qty else None,
        qty_unit=work.qty_unit,
        physical_progress_pct=work.physical_progress_pct,
        recommendation_date=work.recommendation_date,
        sanction_date=work.sanction_date,
        expected_completion_date=work.expected_completion_date,
        actual_completion_date=work.actual_completion_date,
        esakshi_ref=work.esakshi_ref,
    )


def assessment_out(assessment: RiskAssessment, work: Work) -> RiskAssessmentOut:
    w = _weights()
    return RiskAssessmentOut(
        id=assessment.id,
        work_id=work.id,
        work_code=work.work_code,
        score=assessment.score,
        band=assessment.band,
        band_label=band_label(assessment.band),
        recommended_action=assessment.recommended_action,
        action_label=w["action_labels"][assessment.recommended_action],
        # Server-owned so a client build cannot silently drop the
        # human-in-the-loop language.
        disclaimer=w["disclaimer"],
        consistency_pct=assessment.consistency_pct,
        subscores=assessment.subscores,
        reasons=[RiskReasonOut.model_validate(r) for r in assessment.reasons],
        engine_version=assessment.engine_version,
        rules_sha256=assessment.rules_sha256,
        computed_at=assessment.computed_at,
    )
