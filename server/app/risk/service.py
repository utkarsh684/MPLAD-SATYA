"""Persistence around the pure engine: score a work and store the result."""

from __future__ import annotations

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.models import RiskAssessment, RiskReason, VerificationSource, Work
from app.risk.consistency import build_verdicts, consistency_pct
from app.risk.engine import assess
from app.risk.facts import build_facts


def score_work(db: Session, work: Work, trigger: str = "manual") -> RiskAssessment:
    """Recompute and persist. Assessments are immutable; this inserts a new row.

    History is free and makes a strong demo beat: watch a score fall from 78 to
    34 after an officer's re-measurement, with both assessments still readable.
    """
    facts = build_facts(db, work)
    result = assess(facts)

    verdicts = build_verdicts(facts)
    consistency = consistency_pct(verdicts)

    db.execute(
        update(RiskAssessment)
        .where(RiskAssessment.work_id == work.id, RiskAssessment.is_current.is_(True))
        .values(is_current=False)
    )

    assessment = RiskAssessment(
        work_id=work.id,
        score=result.score,
        band=result.band,
        subscores=result.subscores,
        consistency_pct=consistency,
        recommended_action=result.recommended_action,
        engine_version=result.engine_version,
        rules_sha256=result.rules_sha256,
        weights_sha256=result.weights_sha256,
        inputs_snapshot=facts,
        is_current=True,
        trigger_reason=trigger,
    )
    db.add(assessment)
    db.flush()

    for rank, reason in enumerate(result.reasons, start=1):
        db.add(
            RiskReason(
                assessment_id=assessment.id,
                rank=rank,
                code=reason.code,
                category=reason.category,
                severity=reason.severity,
                title=reason.title,
                points=reason.points,
                raw_points=reason.raw_points,
                explanation=reason.explanation,
                provenance=reason.provenance,
                refs=reason.refs,
            )
        )

    # Upsert the four source cards.
    existing = {
        vs.source: vs
        for vs in db.execute(
            select(VerificationSource).where(VerificationSource.work_id == work.id)
        ).scalars()
    }
    for v in verdicts:
        row = existing.get(v.source)
        if row is None:
            row = VerificationSource(work_id=work.id, source=v.source)
            db.add(row)
        row.status = v.status
        row.headline = v.headline
        row.confidence = v.confidence
        row.observed_value = v.observed_value
        row.expected_value = v.expected_value
        row.observed_unit = v.observed_unit
        row.report_count = v.report_count

    work.current_assessment_id = assessment.id
    db.flush()
    return assessment
