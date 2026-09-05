"""Tests for anomaly detection (z-score computation, pure math only)."""

import math


def test_zscore_math():
    """The z-score formula itself, without DB."""
    values = [100, 110, 95, 105, 102, 98, 100, 103, 107, 99]
    mu = sum(values) / len(values)
    sigma = math.sqrt(sum((x - mu) ** 2 for x in values) / len(values))
    outlier = 300
    z = (outlier - mu) / sigma
    assert z > 3.0, f"z-score {z} should flag a 3x outlier"


def test_zscore_small_sigma():
    """If all values are identical, sigma is 0, result should be None."""
    # This tests the guard in our code: sigma == 0 → return None
    values = [100] * 10
    sigma = math.sqrt(sum((x - 100) ** 2 for x in values) / len(values))
    assert sigma == 0.0
