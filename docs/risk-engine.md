# Risk Engine — Technical Reference

## Overview

The risk engine scores every MPLAD work 0–100 based on 33 declarative rules across five categories. The core function `assess(facts)` is **pure** — no database, no network, no clock. This is what makes golden tests, assessment replay, and "how do you audit the auditor?" answerable.

## Scoring Model

**Additive with per-category caps**, not a weighted average.

| Category | Cap | Rule Count | Examples |
|----------|-----|------------|----------|
| Rule | 40 | 12 | Annex-II prohibited, tender evasion, UC overdue |
| Anomaly | 25 | 6 | Cost vs CPWD benchmark, z-score, IsolationForest |
| Fraud | 35 | 8 | Geo-duplicate, photo reuse, GPS spoof, cross-agency photo |
| Field | 20 | 4 | Measurement mismatch, work not started, different work |
| Inefficiency | 10 | 3 | Timeline overdue, stalled progress, low utilisation |

Caps total 130, score caps at 100. A work can max several layers.

## Rule Format

Each rule in `rules.json`:

```json
{
  "code": "COST_ANOMALY_BENCHMARK",
  "category": "anomaly",
  "severity": "HIGH",
  "when": "cost_ratio is not None and cost_ratio >= 1.5",
  "points": "min(25, round((cost_ratio - 1.0) / 2.0 * 25))",
  "title": "Cost exceeds CPWD benchmark",
  "explanation": "Reported {sanctioned_amount_paise|inr} is {cost_ratio|x} the {benchmark_source} benchmark of {benchmark_total_paise|inr}",
  "provenance": "eSAKSHI vs CPWD DSR 2023"
}
```

`when` and `points` are evaluated by `simpleeval` with `min/max/round/abs/len/int/float` in the function whitelist. Missing facts resolve to `None` via a `_Facts(dict)` subclass — a rule that depends on absent data simply fails its guard.

## Hamilton Apportionment

The displayed points on each reason sum **exactly** to the gauge number. Without this, rounding produces `16+14+12+10+10+7+4 = 73` next to a gauge reading `80`.

The `_apportion()` function implements the largest-remainder method:
1. Scale each reason's contribution proportionally to the target score
2. Take the floor of each
3. Distribute the remaining points to the reasons with the largest fractional remainders
4. Deterministic tie-break on rule code

## Bands and Actions

| Band | Score Range | Action | Label |
|------|------------|--------|-------|
| Green | 0–30 | `auto_approve` | ELIGIBLE FOR RELEASE |
| Yellow | 31–70 | `manual_review` | SEND FOR REVIEW |
| Red | 71–100 | `hold_field_verify` | HOLD RELEASE FOR FIELD REVIEW |

## Reproducibility

Every `RiskAssessment` row stores:
- `engine_version` — e.g. `satya-risk/1.0.0`
- `rules_sha256` — digest of `rules.json`
- `weights_sha256` — digest of `weights.yaml`
- `inputs_snapshot` — the complete facts dict (JSONB)

A score computed today can be re-explained in a year, even after rules change. This is the real answer to "how do you audit the auditor?"

## Facts Pipeline

`build_facts(db, work)` in `facts.py` queries:

| Fact | Source | Previously |
|------|--------|-----------|
| `cost_ratio` | CPWD benchmark rates | ✅ Always worked |
| `cost_zscore` | `stddev_pop` across district+category | ❌ Was never computed |
| `iforest_flag` | sklearn IsolationForest per district+category | ❌ Was never computed |
| `nearest_similar_work_m` | PostGIS `ST_DWithin` | ✅ Always worked |
| `max_photo_similarity` | pHash banded SQL | ✅ Always worked |
| `max_photo_offset_m` | PostGIS `ST_Distance(evidence.gps, work.location)` | ❌ Was never computed |
| `photo_shared_across_agencies` | pHash + agency cross-check | ❌ Was never computed |
| `days_since_progress_update` | MAX of evidence/verification timestamps | ❌ Was never computed |
| `utilisation_pct` | SUM(approved releases) / sanctioned | ❌ Was never computed |
| `citizen_mismatch_reports` | COUNT of negative citizen verdicts | ✅ Always worked |

## Evidence Consistency

```
consistency_pct = Σ(agreement × weight) / Σ(weight)
```

Where:
- `available/match` → agreement = 1.0
- `mismatch` → agreement = 0.0
- `inconclusive/unavailable` → **excluded from both numerator and denominator**

All source weights are 1.0 (equal). Loaded from `weights.yaml`.
