"""EXIF extraction, GPS trust scoring, and face blur (DPDP).

Three jobs in one module because they all run on the same image bytes at
upload time and share the PIL/cv2 import cost.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image
from PIL.ExifTags import GPSTAGS, TAGS


@dataclass
class GpsInfo:
    lat: float
    lon: float
    altitude: float | None = None
    accuracy_m: float | None = None
    timestamp: str | None = None


@dataclass
class ExifResult:
    gps: GpsInfo | None = None
    capture_time: str | None = None
    device_make: str | None = None
    device_model: str | None = None
    software: str | None = None
    raw: dict = field(default_factory=dict)


def _dms_to_dd(dms, ref: str) -> float:
    d, m, s = float(dms[0]), float(dms[1]), float(dms[2])
    dd = d + m / 60.0 + s / 3600.0
    if ref in ("S", "W"):
        dd = -dd
    return round(dd, 7)


def extract_exif(image_path: str | Path) -> ExifResult:
    """Pull GPS + device metadata from an image's EXIF."""
    result = ExifResult()
    try:
        img = Image.open(image_path)
        exif_data = img._getexif()
        if exif_data is None:
            return result
    except Exception:
        return result

    decoded = {}
    for tag_id, value in exif_data.items():
        tag = TAGS.get(tag_id, tag_id)
        decoded[tag] = value

    result.capture_time = str(decoded.get("DateTimeOriginal") or decoded.get("DateTime") or "")
    result.device_make = str(decoded.get("Make", ""))
    result.device_model = str(decoded.get("Model", ""))
    result.software = str(decoded.get("Software", ""))
    result.raw = {k: str(v) for k, v in decoded.items() if isinstance(k, str)}

    gps_info = decoded.get("GPSInfo")
    if gps_info and isinstance(gps_info, dict):
        gps_decoded = {}
        for k, v in gps_info.items():
            tag = GPSTAGS.get(k, k)
            gps_decoded[tag] = v

        if "GPSLatitude" in gps_decoded and "GPSLongitude" in gps_decoded:
            lat = _dms_to_dd(gps_decoded["GPSLatitude"], gps_decoded.get("GPSLatitudeRef", "N"))
            lon = _dms_to_dd(gps_decoded["GPSLongitude"], gps_decoded.get("GPSLongitudeRef", "E"))
            alt = None
            if "GPSAltitude" in gps_decoded:
                alt = float(gps_decoded["GPSAltitude"])
            ds = str(gps_decoded.get("GPSDateStamp", ""))
            ts_raw = str(gps_decoded.get("GPSTimeStamp", ""))
            ts = f"{ds} {ts_raw}"
            result.gps = GpsInfo(lat=lat, lon=lon, altitude=alt, timestamp=ts.strip())

    return result


def gps_trust_score(
    exif: ExifResult,
    *,
    work_lat: float | None,
    work_lon: float | None,
    claimed_accuracy_m: float | None = None,
    is_mock_location: bool = False,
) -> tuple[int, list[str]]:
    """Score 0-100 for how trustworthy the GPS data is. Returns (score, flags)."""
    score = 100
    flags: list[str] = []

    if exif.gps is None:
        return 20, ["no_gps_in_exif"]

    if is_mock_location:
        score -= 60
        flags.append("mock_location_flag")

    # Distance between EXIF GPS and the work's registered location.
    #
    # A work with no recorded location cannot be compared against, and
    # substituting a default would measure the photo against a place nobody
    # claimed - inventing a finding, or clearing one, out of nothing. The
    # comparison is skipped and said out loud instead.
    if work_lat is None or work_lon is None:
        flags.append("work_location_unknown")
    else:
        dlat = exif.gps.lat - work_lat
        dlon = exif.gps.lon - work_lon
        dist_m = math.sqrt(dlat**2 + dlon**2) * 111_320
        if dist_m > 500:
            score -= 40
            flags.append(f"gps_offset_{int(dist_m)}m")
        elif dist_m > 100:
            score -= 20
            flags.append(f"gps_offset_{int(dist_m)}m")

    if claimed_accuracy_m is not None and claimed_accuracy_m < 1.0:
        score -= 15
        flags.append("suspiciously_precise_gps")

    if not exif.capture_time:
        score -= 10
        flags.append("no_capture_timestamp")

    if not exif.device_make and not exif.device_model:
        score -= 10
        flags.append("no_device_info")

    return max(0, min(100, score)), flags


def photo_offset_m(
    exif: ExifResult, work_lat: float | None, work_lon: float | None
) -> float | None:
    """Distance in metres between the photo's EXIF GPS and the work location.

    None when either end is unknown - an unmeasurable distance, not a zero one.
    """
    if exif.gps is None or work_lat is None or work_lon is None:
        return None
    dlat = exif.gps.lat - work_lat
    dlon = exif.gps.lon - work_lon
    return round(math.sqrt(dlat**2 + dlon**2) * 111_320, 1)


def blur_faces(image_path: str | Path, output_path: str | Path | None = None) -> int:
    """Detect and blur faces using OpenCV DNN. Returns face count.

    Uses the Haar cascade as fallback — the DNN model files are ~10 MB and
    may not ship with the container. Haar is less accurate but lightweight.
    """
    import cv2

    img = cv2.imread(str(image_path))
    if img is None:
        return 0

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    faces = cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))
    count = len(faces)

    for (x, y, w, h) in faces:
        roi = img[y:y+h, x:x+w]
        blurred = cv2.GaussianBlur(roi, (99, 99), 30)
        img[y:y+h, x:x+w] = blurred

    out = str(output_path or image_path)
    cv2.imwrite(out, img)
    return count
