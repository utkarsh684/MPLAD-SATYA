"""Evidence upload pipeline: photo → EXIF → pHash → GPS trust → face blur → store."""

from __future__ import annotations

import hashlib
import uuid
from datetime import UTC, datetime
from pathlib import Path
from tempfile import NamedTemporaryFile

from fastapi import APIRouter, File, Form, UploadFile
from sqlalchemy import select

from app.deps import CurrentUser, DbSession
from app.errors import ApiError
from app.models import Evidence, Work
from app.risk.service import score_work
from app.schemas import EvidenceOut
from app.services import phash as phash_svc
from app.services.exif import blur_faces, extract_exif, gps_trust_score, photo_offset_m
from app.services.storage import file_url, get_path, store_path

router = APIRouter(prefix="/api/v1", tags=["evidence"])


def _load_work(db, work_code: str) -> Work:
    work = db.execute(
        select(Work).where(Work.work_code == work_code, Work.deleted_at.is_(None))
    ).scalar_one_or_none()
    if work is None:
        raise ApiError("WORK_NOT_FOUND", f"No work with code {work_code}.", 404)
    return work


def _work_location(work: Work) -> tuple[float, float]:
    """Extract lat/lon from PostGIS geography."""
    try:
        from geoalchemy2.shape import to_shape
        point = to_shape(work.location)
        return point.y, point.x
    except Exception:
        return 23.2599, 77.4126


# Raster formats only. SVG is deliberately absent: it is XML, it can carry
# script, and it is not a camera output. GIF is absent because it is not a
# photographic evidence format and its decoder surface buys us nothing.
_ALLOWED_IMAGE_FORMATS = {
    "JPEG": (".jpg", "image/jpeg"),
    "PNG": (".png", "image/png"),
    "WEBP": (".webp", "image/webp"),
    "HEIF": (".heic", "image/heic"),
}


def _verify_image(data: bytes) -> tuple[str, str]:
    """Confirm the bytes really are a supported image; return (ext, mime).

    Pillow reads the container header rather than trusting the filename or the
    Content-Type header, both of which the uploader controls. `verify()` then
    walks the stream far enough to reject a truncated or malformed file before
    it enters the evidence chain, so a corrupt upload fails here with a clear
    error instead of surfacing as a broken image days later in an audit.
    """
    from io import BytesIO

    from PIL import Image, UnidentifiedImageError

    try:
        with Image.open(BytesIO(data)) as probe:
            fmt = (probe.format or "").upper()
            probe.verify()
    except UnidentifiedImageError as exc:
        raise ApiError(
            "FILE_NOT_AN_IMAGE",
            "That file is not a readable image. Upload a photo taken with the "
            "camera (JPEG, PNG, WEBP or HEIC).",
            415,
        ) from exc
    except Exception as exc:
        raise ApiError(
            "FILE_CORRUPT",
            "The image could not be read - it may have been truncated during "
            "upload. Try again.",
            400,
        ) from exc

    if fmt not in _ALLOWED_IMAGE_FORMATS:
        raise ApiError(
            "FILE_TYPE_NOT_ALLOWED",
            f"{fmt or 'That file type'} is not accepted as evidence. "
            "Use JPEG, PNG, WEBP or HEIC.",
            415,
            details={"detected_format": fmt},
        )
    return _ALLOWED_IMAGE_FORMATS[fmt]


@router.post("/works/{work_code:path}/evidence", operation_id="uploadEvidence",
             response_model=EvidenceOut)
async def upload_evidence(
    work_code: str,
    db: DbSession,
    user: CurrentUser,
    file: UploadFile = File(...),
    source: str = Form("field_officer"),
    client_uuid: str | None = Form(None),
    is_mock_location: bool = Form(False),
    claimed_accuracy_m: float | None = Form(None),
):
    """Full evidence pipeline: hash, EXIF, GPS trust, face blur, pHash, store."""
    work = _load_work(db, work_code)

    # Idempotency
    if client_uuid:
        existing = db.execute(
            select(Evidence).where(Evidence.client_uuid == uuid.UUID(client_uuid))
        ).scalar_one_or_none()
        if existing:
            return _evidence_out(existing)

    data = await file.read()
    if len(data) > 15_000_000:
        raise ApiError("FILE_TOO_LARGE", "Maximum 15 MB.", 413)
    if not data:
        raise ApiError("FILE_EMPTY", "The uploaded file is empty.", 400)

    sha = hashlib.sha256(data).hexdigest()

    # The stored extension is derived from what the bytes ACTUALLY are, never
    # from the client-supplied filename.
    #
    # /media is served by StaticFiles, so a file the uploader could name
    # "photo.html" or "photo.svg" would be stored and later served as active
    # content on the API origin -- stored XSS against anyone who opens an
    # evidence link. Sniffing the real format also rejects a renamed PDF or
    # executable that would otherwise sit in the evidence chain as a "photo".
    ext, mime = _verify_image(data)

    # Write to temp for processing
    with NamedTemporaryFile(suffix=ext, delete=False) as tmp:
        tmp.write(data)
        tmp_path = Path(tmp.name)

    try:
        # 1. EXIF extraction
        exif = extract_exif(tmp_path)

        # 2. GPS trust scoring
        work_lat, work_lon = _work_location(work)
        trust, gps_flags = gps_trust_score(
            exif, work_lat=work_lat, work_lon=work_lon,
            claimed_accuracy_m=claimed_accuracy_m,
            is_mock_location=is_mock_location,
        )

        # 3. Photo offset from work site
        _ = photo_offset_m(exif, work_lat, work_lon)  # logged in gps_flags

        # 4. Face blur (DPDP compliance)
        faces_count = blur_faces(tmp_path)

        # 5. pHash computation
        phash_val = phash_svc.compute(str(tmp_path))
        b0, b1, b2, b3 = phash_val.band_values

        # 6. Store the (now blurred) file
        storage_key, _ = store_path(tmp_path, prefix="evidence")

        from PIL import Image
        with Image.open(get_path(storage_key)) as img:
            w, h = img.size

    finally:
        tmp_path.unlink(missing_ok=True)

    gps_lat = exif.gps.lat if exif.gps else None
    gps_lon = exif.gps.lon if exif.gps else None
    gps_point = f"SRID=4326;POINT({gps_lon} {gps_lat})" if gps_lat and gps_lon else None

    ev = Evidence(
        work_id=work.id,
        uploaded_by=user.id,
        source=source,
        kind="photo",
        storage_key=storage_key,
        sha256=sha,
        # The sniffed type, not the client's Content-Type header.
        mime=mime,
        bytes_len=len(data),
        width=w, height=h,
        captured_at=datetime.now(UTC),
        gps=gps_point,
        gps_accuracy_m=claimed_accuracy_m,
        gps_trust=trust,
        gps_flags=gps_flags,
        phash=phash_val.signed,
        pb0=b0, pb1=b1, pb2=b2, pb3=b3,
        faces_blurred=faces_count,
        exif=exif.raw,
        client_uuid=uuid.UUID(client_uuid) if client_uuid else None,
    )
    db.add(ev)
    db.flush()

    # Recompute risk with the new evidence
    score_work(db, work, trigger="evidence_upload")
    db.commit()

    return _evidence_out(ev)


@router.get("/works/{work_code:path}/evidence", operation_id="listEvidence",
            response_model=list[EvidenceOut])
def list_evidence(work_code: str, db: DbSession, user: CurrentUser):
    work = _load_work(db, work_code)
    rows = db.execute(
        select(Evidence)
        .where(Evidence.work_id == work.id, Evidence.deleted_at.is_(None))
        .order_by(Evidence.created_at.desc())
    ).scalars().all()
    return [_evidence_out(e) for e in rows]


def _evidence_out(ev: Evidence) -> dict:
    return {
        "id": ev.id,
        "work_id": ev.work_id,
        "source": ev.source,
        "kind": ev.kind,
        "storage_url": file_url(ev.storage_key),
        "sha256": ev.sha256,
        "mime": ev.mime,
        "bytes_len": ev.bytes_len,
        "width": ev.width,
        "height": ev.height,
        "captured_at": ev.captured_at,
        "gps_trust": ev.gps_trust,
        "gps_flags": ev.gps_flags or [],
        "faces_blurred": ev.faces_blurred,
        "phash_hex": hex(phash_svc.to_unsigned(ev.phash)) if ev.phash else None,
        "client_uuid": ev.client_uuid,
        "created_at": ev.created_at,
    }
