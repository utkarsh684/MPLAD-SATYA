"""Risk scoring engine.

`assess()` is a PURE function of a facts dict. That is the single most important
property in this module:

  * golden tests run with no database and no HTTP
  * an assessment stored months ago can be replayed from its `inputs_snapshot`
  * "how do you audit the auditor?" has a real answer

Scoring is ADDITIVE with per-category caps, not a weighted average of
sub-scores. This is deliberate: it is what makes the reasons displayed on screen
sum exactly to the number in the gauge. Explainability here is arithmetic, not a
post-hoc attribution method bolted onto an opaque model.
"""

from __future__ import annotations

import hashlib
import json
import math
from functools import lru_cache
from pathlib import Path

import yaml
from simpleeval import InvalidExpression, SimpleEval

from app.risk.format import render
from app.risk.signals import AssessmentResult, Reason

ENGINE_VERSION = "satya-risk/1.0.0"

_DIR = Path(__file__).parent
_RULES_PATH = _DIR / "rules.json"
_WEIGHTS_PATH = _DIR / "weights.yaml"

_SAFE_FUNCS = {
    "min": min, "max": max, "round": round, "abs": abs,
    "len": len, "int": int, "float": float,
}

_SEVERITY_ORDER = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}


def _sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


@lru_cache(maxsize=1)
def load_rulebook() -> tuple[list[dict], dict, str, str]:
    """Rules + weights + their digests. Cached; call `reload()` in tests."""
    rules = json.loads(_RULES_PATH.read_text())
    weights = yaml.safe_load(_WEIGHTS_PATH.read_text())
    return rules, weights, _sha256_file(_RULES_PATH), _sha256_file(_WEIGHTS_PATH)


def reload() -> None:
    load_rulebook.cache_clear()


class _Facts(dict):
    """Unknown fact -> None rather than an exception.

    Rules are written defensively (`x is not None and x > y`), so resolving a
    missing key to None is the correct semantics: absent data simply fails the
    guard. Relying on an exception instead would make every rule's behaviour
    depend on evaluation order inside simpleeval.
    """

    def __missing__(self, key: str) -> None:
        return None


def _evaluator(facts: dict) -> SimpleEval:
    ev = SimpleEval(functions=dict(_SAFE_FUNCS))
    ev.names = _Facts(facts)
    return ev


def _apportion(values: list[float], target: int, keys: list[str]) -> list[int]:
    """Largest-remainder (Hamilton) apportionment.

    Guarantees `sum(result) == target` exactly. Without this, per-reason rounding
    produces 23+18+16+15+5 = 77 next to a gauge reading 78, which is precisely
    the kind of detail a judge notices.
    """
    if target <= 0 or not values:
        return [0] * len(values)
    total = sum(values)
    if total <= 0:
        return [0] * len(values)

    scaled = [v / total * target for v in values]
    floors = [math.floor(s) for s in scaled]
    remainder = target - sum(floors)

    # Deterministic tie-break on the rule code, so the same facts always yield
    # the same displayed numbers.
    order = sorted(
        range(len(scaled)),
        key=lambda i: (-(scaled[i] - floors[i]), keys[i]),
    )
    for i in order[:remainder]:
        floors[i] += 1
    return floors


def _band_for(score: int, weights: dict) -> tuple[str, dict]:
    for name, spec in weights["bands"].items():
        if spec["min"] <= score <= spec["max"]:
            return name, spec
    return "red", weights["bands"]["red"]


def assess(facts: dict) -> AssessmentResult:
    """Score a work from its facts. Pure: no DB, no network, no clock."""
    rules, weights, rules_sha, weights_sha = load_rulebook()
    caps: dict[str, int] = weights["category_caps"]
    total_cap: int = weights["total_cap"]

    ev = _evaluator(facts)
    fired: list[tuple[dict, int]] = []

    for rule in rules:
        try:
            if not ev.eval(rule["when"]):
                continue
            raw = int(ev.eval(rule["points"]))
        except (InvalidExpression, KeyError, NameError, TypeError, ValueError):
            # A fact this rule depends on is absent. Missing data must never
            # fire a rule -- a false positive from a NULL is a demo-day disaster
            # and, in production, an unjustified hold on public money.
            continue
        if raw < 0:
            continue
        fired.append((rule, raw))

    # Per-category cap, applied proportionally within the category.
    by_cat: dict[str, int] = {}
    for rule, raw in fired:
        by_cat[rule["category"]] = by_cat.get(rule["category"], 0) + raw

    cat_factor: dict[str, float] = {}
    for cat, raw_sum in by_cat.items():
        cap = caps.get(cat, total_cap)
        cat_factor[cat] = min(1.0, cap / raw_sum) if raw_sum > 0 else 1.0

    weighted = [raw * cat_factor[rule["category"]] for rule, raw in fired]

    running = sum(weighted)
    if running > total_cap:
        squeeze = total_cap / running
        weighted = [w * squeeze for w in weighted]
        running = total_cap

    score = int(round(running))
    points = _apportion(weighted, score, [r["code"] for r, _ in fired])

    reasons = [
        Reason(
            code=rule["code"],
            category=rule["category"],
            severity=rule["severity"],
            title=rule["title"],
            points=pts,
            raw_points=raw,
            explanation=render(rule["explanation"], facts),
            provenance=render(rule["provenance"], facts),
            refs=rule.get("refs") or {},
        )
        for (rule, raw), pts in zip(fired, points, strict=True)
    ]

    reasons.sort(key=lambda r: (-r.points, _SEVERITY_ORDER.get(r.severity, 3), r.code))

    band, spec = _band_for(score, weights)
    subscores = {cat: 0 for cat in caps}
    for r in reasons:
        subscores[r.category] = subscores.get(r.category, 0) + r.points

    return AssessmentResult(
        score=score,
        band=band,
        recommended_action=spec["action"],
        action_label=weights["action_labels"][spec["action"]],
        disclaimer=weights["disclaimer"],
        subscores=subscores,
        reasons=reasons,
        engine_version=ENGINE_VERSION,
        rules_sha256=rules_sha,
        weights_sha256=weights_sha,
    )
