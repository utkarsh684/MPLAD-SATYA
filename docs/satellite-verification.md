# Satellite Verification — Design & Honesty

## The Physical Constraint

Bhuvan (ISRO) freely serves Cartosat imagery at ~2.5 m/px. Sentinel-2 is 10 m/px.

A 3 m wide ward road occupies **one pixel** at 2.5 m/px. You cannot verify a road's length, width, or quality from this imagery. Anyone claiming otherwise loses the room to the first panellist who knows remote sensing.

## Detectability Model

A feature is reliably detectable at ≥ 3×3 pixels (standard minimum mapping unit in remote sensing):

```
min_detectable_m = 3 × resolution_m

For Bhuvan @ 2.5 m/px:
    min_detectable = 7.5 m

For a road (width 3 m):
    detectability_ratio = 3.0 / 7.5 = 0.4 → INCONCLUSIVE
    confidence = logistic(0.4) ≈ 68%

For a school building (20 m × 20 m):
    detectability_ratio = 20.0 / 7.5 = 2.67 → DETECTABLE
    → run real NDBI comparison
```

## Adapters

### FixtureAdapter (Default)

Deterministic, used for demo. Returns realistic results based on the detectability model without network calls.

Set `SATELLITE_ADAPTER=fixture` (default).

### BhuvanAdapter (Live)

Real HTTP calls to Bhuvan WMS endpoint:
- Fetches a 256×256 tile around the work location
- Computes NDBI (Normalized Difference Built-up Index) from RGB bands as SWIR proxy
- Positive NDBI → match (construction detected)
- Negative NDBI → mismatch (vegetation, not construction)
- Ambiguous → inconclusive

Set `SATELLITE_ADAPTER=bhuvan`.

**Warning**: Bhuvan WMS is intermittently slow. Timeout is 8 seconds. Mid-demo timeout is a real risk — this is why fixture is the default.

## Scoring Integration

An inconclusive satellite observation contributes **ZERO points** to the risk score. An unusable sensor must never manufacture suspicion.

The `SATELLITE_INCONCLUSIVE_ESCALATE` rule fires at 0 points — it signals that field verification is the only reliable path, without penalising the work.

## Demo Narrative

"We use ISRO's Bhuvan satellite imagery for large-footprint works like buildings. For roads and drains — which are below resolution at 2.5 m/px — we report inconclusive with a calibrated confidence number, and the system falls back to field verification. This is honest engineering, not a missing feature."
