"""Value types shared by the risk engine. No I/O, no ORM."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class Reason:
    code: str
    category: str
    severity: str
    title: str
    points: int          # apportioned; these sum EXACTLY to the score
    raw_points: int      # pre-cap rule output, kept for the audit trail
    explanation: str
    provenance: str
    refs: dict = field(default_factory=dict)


@dataclass(frozen=True)
class AssessmentResult:
    score: int
    band: str
    recommended_action: str
    action_label: str
    disclaimer: str
    subscores: dict[str, int]
    reasons: list[Reason]
    engine_version: str
    rules_sha256: str
    weights_sha256: str

    def points_sum(self) -> int:
        return sum(r.points for r in self.reasons)
