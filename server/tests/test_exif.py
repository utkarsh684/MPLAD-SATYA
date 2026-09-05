"""Tests for EXIF extraction, GPS trust, and face blur."""

from app.services.exif import ExifResult, GpsInfo, gps_trust_score, photo_offset_m


def test_gps_trust_no_gps():
    exif = ExifResult()
    score, flags = gps_trust_score(exif, work_lat=23.26, work_lon=77.41)
    assert score == 20
    assert "no_gps_in_exif" in flags


def test_gps_trust_mock_location():
    exif = ExifResult(gps=GpsInfo(lat=23.26, lon=77.41))
    score, flags = gps_trust_score(
        exif, work_lat=23.26, work_lon=77.41, is_mock_location=True
    )
    assert score <= 40
    assert "mock_location_flag" in flags


def test_gps_trust_far_offset():
    exif = ExifResult(gps=GpsInfo(lat=23.30, lon=77.45))
    score, flags = gps_trust_score(exif, work_lat=23.26, work_lon=77.41)
    assert score < 80
    assert any("gps_offset" in f for f in flags)


def test_gps_trust_close_good():
    exif = ExifResult(
        gps=GpsInfo(lat=23.2600, lon=77.4127),
        capture_time="2026:09:01 10:30:00",
        device_make="Samsung", device_model="Galaxy A54",
    )
    score, flags = gps_trust_score(exif, work_lat=23.2599, work_lon=77.4126)
    assert score >= 80
    assert len(flags) == 0


def test_gps_trust_suspiciously_precise():
    exif = ExifResult(gps=GpsInfo(lat=23.26, lon=77.41))
    score, flags = gps_trust_score(
        exif, work_lat=23.26, work_lon=77.41, claimed_accuracy_m=0.1
    )
    assert "suspiciously_precise_gps" in flags


def test_photo_offset_none_without_gps():
    exif = ExifResult()
    assert photo_offset_m(exif, 23.26, 77.41) is None


def test_photo_offset_computed():
    exif = ExifResult(gps=GpsInfo(lat=23.27, lon=77.42))
    offset = photo_offset_m(exif, 23.26, 77.41)
    assert offset is not None
    assert offset > 1000  # ~1.5 km
