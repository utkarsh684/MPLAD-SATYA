"""Statistical anomaly detection: z-score and IsolationForest.

These make the COST_ZSCORE_OUTLIER and IFOREST_ANOMALY rules live. Both are
computed per-category within a district so a ₹15L road is compared to other
roads in the same district, not to a ₹2L toilet block elsewhere.
"""

from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Work


def cost_zscore(db: Session, work: Work) -> float | None:
    """How many standard deviations this work's cost is above the district mean."""
    row = db.execute(
        select(
            func.avg(Work.sanctioned_amount_paise).label("mu"),
            func.stddev_pop(Work.sanctioned_amount_paise).label("sigma"),
            func.count().label("n"),
        ).where(
            Work.category == work.category,
            Work.district_id == work.district_id,
            Work.deleted_at.is_(None),
            Work.id != work.id,
        )
    ).first()
    if row is None or row.n < 5 or row.sigma is None or float(row.sigma) == 0:
        return None
    return round((work.sanctioned_amount_paise - float(row.mu)) / float(row.sigma), 2)


_IF_CACHE: dict[tuple, object] = {}


def _get_iforest(db: Session, category: str, district_id) -> object | None:
    """Fit an IsolationForest on the cost distribution for this category+district.

    Cached per (category, district_id) for the lifetime of the process since
    the training data only changes on seed/sync, not per-request.
    """
    key = (category, str(district_id))
    if key in _IF_CACHE:
        return _IF_CACHE[key]

    rows = db.execute(
        select(Work.sanctioned_amount_paise).where(
            Work.category == category,
            Work.district_id == district_id,
            Work.deleted_at.is_(None),
        )
    ).scalars().all()

    if len(rows) < 20:
        _IF_CACHE[key] = None
        return None

    import numpy as np
    from sklearn.ensemble import IsolationForest

    X = np.array(rows, dtype=np.float64).reshape(-1, 1)
    model = IsolationForest(
        n_estimators=100, contamination=0.05, random_state=42
    )
    model.fit(X)
    _IF_CACHE[key] = model
    return model


def iforest_flag(db: Session, work: Work) -> bool:
    """True if the IsolationForest considers this work an outlier."""
    model = _get_iforest(db, work.category, work.district_id)
    if model is None:
        return False
    import numpy as np
    pred = model.predict(np.array([[work.sanctioned_amount_paise]], dtype=np.float64))
    return bool(pred[0] == -1)


def clear_cache():
    _IF_CACHE.clear()
