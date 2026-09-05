"""File storage abstraction. Local disk for dev, R2-ready interface.

Keeps the upload pipeline storage-agnostic: swap in R2 presigned URLs later
without touching the evidence router.
"""

from __future__ import annotations

import hashlib
import uuid
from pathlib import Path

from app.config import settings


def _media_root() -> Path:
    p = Path(settings.media_root)
    p.mkdir(parents=True, exist_ok=True)
    return p


def store_file(data: bytes, *, prefix: str = "evidence", ext: str = ".jpg") -> tuple[str, str]:
    """Store raw bytes. Returns (storage_key, sha256)."""
    digest = hashlib.sha256(data).hexdigest()
    key = f"{prefix}/{digest[:4]}/{uuid.uuid4().hex}{ext}"
    dest = _media_root() / key
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return key, digest


def store_path(src: Path, *, prefix: str = "evidence") -> tuple[str, str]:
    """Store a file from a path. Returns (storage_key, sha256)."""
    data = src.read_bytes()
    ext = src.suffix or ".bin"
    return store_file(data, prefix=prefix, ext=ext)


def get_path(key: str) -> Path:
    return _media_root() / key


def file_url(key: str) -> str:
    return f"/media/{key}"
