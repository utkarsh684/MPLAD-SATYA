"""UNKNOWN must never be rendered as ZERO.

Each test here guards a place where a missing measurement could silently
become a number an officer would read as a finding.
"""

from app.risk.consistency import SourceVerdict, consistency_pct


def _v(source: str, status: str) -> SourceVerdict:
    return SourceVerdict(
        source=source, status=status, headline="", confidence=None,
        observed_value=None, expected_value=None, observed_unit=None,
        report_count=0,
    )


def test_no_informative_source_yields_none_not_zero():
    """All four sources silent => consistency is unknown, not 0 %.

    0 % means every source contradicted the record. None means nothing could
    be checked. Rendering the second as the first would let an unusable
    sensor manufacture the appearance of total disagreement.
    """
    verdicts = [
        _v("satellite", "inconclusive"),
        _v("official_record", "unavailable"),
        _v("citizen", "unavailable"),
        _v("field", "inconclusive"),
    ]
    assert consistency_pct(verdicts) is None


def test_total_disagreement_really_is_zero():
    """The genuine 0 % case must still return 0, not None."""
    verdicts = [_v("official_record", "mismatch"), _v("field", "mismatch")]
    assert consistency_pct(verdicts) == 0


def test_full_agreement_is_hundred():
    verdicts = [_v("official_record", "match"), _v("field", "match")]
    assert consistency_pct(verdicts) == 100


def test_inconclusive_sources_are_excluded_not_counted_as_disagreement():
    """One matching source plus three silent ones is 100 %, not 25 %."""
    verdicts = [
        _v("official_record", "match"),
        _v("satellite", "inconclusive"),
        _v("citizen", "unavailable"),
        _v("field", "inconclusive"),
    ]
    assert consistency_pct(verdicts) == 100
