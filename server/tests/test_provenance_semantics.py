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


# --------------------------------------------------------------------------
# Analytics must not mix populations.
#
# district-summary counts ALL works but averages only the assessed ones, so
# the two numbers have to travel together. With 2000 works and 150 assessed,
# "679 works, average risk 5.9" is a false statement about 679 works - and,
# rendered without a denominator beside work cards showing "78/100", it also
# reads as a different scale entirely.
# --------------------------------------------------------------------------


def test_district_summary_reports_the_assessed_population():
    import inspect

    from app.routers import analytics

    source = inspect.getsource(analytics.district_summary)
    assert "assessed_works" in source, (
        "the average covers assessed works only; the count of those must be "
        "returned alongside it"
    )


def test_district_average_stays_null_when_nothing_is_assessed():
    import inspect

    from app.routers import analytics

    source = inspect.getsource(analytics.district_summary)
    # 0.0 would colour an entirely unassessed district green and rank it as
    # the safest one on the screen.
    assert "if r.avg_score is not None else None" in source


class TestAnalyticsOverviewDoesNotInventAZero:
    """`GET /analytics/overview` on a portfolio nothing has scored yet.

    0 is the one value a reader takes as "all clear", so reporting it for
    "not computed" inverts the meaning. This bites during a partial seed and
    on any fresh deployment, which is exactly when someone is looking.
    """

    @staticmethod
    def _empty_db():
        """A database holding works but no assessments.

        Dispatches on the statement rather than on call order, so adding a
        query to the endpoint does not break this test for unrelated reasons.
        """
        class _Result:
            def __init__(self, value): self._value = value
            def scalar_one(self): return self._value
            def all(self): return []

        class _Db:
            def execute(self, stmt, *a, **k):
                return _Result(None if "avg(" in str(stmt).lower() else 0)

        return _Db()

    def test_unscored_portfolio_reports_none_not_zero(self):
        from app.routers.analytics import overview

        body = overview(db=self._empty_db(), user=None)
        assert body["average_risk_score"] is None
        assert body["assessed_works"] == 0

    def test_assessed_count_never_overstates_what_was_scored(self):
        """The band distribution covers assessed works, never total_works.

        A donut drawn over the full portfolio would show 1,500 unscored works
        as an absence of risk rather than an absence of information.
        """
        from app.routers.analytics import overview

        body = overview(db=self._empty_db(), user=None)
        assert body["assessed_works"] == sum(body["by_band"].values())


class TestAnUnknownLocationIsNotADefaultLocation:
    """The evidence pipeline used to fall back to Bhopal's coordinates.

    A photo would then be checked for GPS drift against a place nobody had
    claimed for that work, manufacturing a distance - and a verdict - out of a
    default. Unknown has to stay unknown all the way through.
    """

    @staticmethod
    def _exif_at(lat: float, lon: float):
        from app.services.exif import ExifResult, GpsInfo

        return ExifResult(gps=GpsInfo(lat=lat, lon=lon))

    def test_trust_scoring_says_so_instead_of_inventing_a_distance(self):
        from app.services.exif import gps_trust_score

        # A photo 400 km from Bhopal. Against the old default this scored as a
        # gross GPS offset; with no location on record there is nothing to
        # compare it to.
        far = self._exif_at(26.9, 75.8)
        unknown, flags = gps_trust_score(far, work_lat=None, work_lon=None)
        assert "work_location_unknown" in flags
        assert not any(f.startswith("gps_offset_") for f in flags)

        # The control is the same photo taken at the work site. An unknown
        # location must cost exactly what a perfect match costs - nothing -
        # rather than being charged for a distance nobody could measure.
        on_site, _ = gps_trust_score(
            self._exif_at(26.9, 75.8), work_lat=26.9, work_lon=75.8
        )
        assert unknown == on_site

    def test_offset_is_none_when_either_end_is_unknown(self):
        from app.services.exif import photo_offset_m

        assert photo_offset_m(self._exif_at(23.3, 77.4), None, None) is None

    def test_a_known_location_still_measures_normally(self):
        from app.services.exif import gps_trust_score

        _score, flags = gps_trust_score(
            self._exif_at(26.9, 75.8), work_lat=23.2599, work_lon=77.4126
        )
        assert any(f.startswith("gps_offset_") for f in flags)


def test_geo_signals_do_not_depend_on_the_optional_shapely_decode():
    """Shapely is a declared dependency, but the geo facts must not need it.

    When it was absent, geoalchemy2's to_shape raised, the caller read that as
    "this work has no location", and GEO_DUPLICATE quietly stopped firing on
    every work in the database - scores stayed plausible while a whole fraud
    signal was dead. The geometry now stays in SQL, so a missing decode cannot
    silently subtract a finding.
    """
    import pathlib

    source = pathlib.Path(__file__).parent.parent / "app" / "risk" / "facts.py"
    # Comments are allowed to explain the history; imports are what matter.
    code = [
        line for line in source.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    offenders = [ln for ln in code if "import" in ln and
                 ("shapely" in ln.lower() or "to_shape" in ln)]
    assert not offenders, offenders
