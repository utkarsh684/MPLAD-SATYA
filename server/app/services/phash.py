"""Perceptual hashing and near-duplicate lookup.

No vector database. A 64-bit DCT hash is stored as a signed BIGINT plus four
16-bit band columns, and candidates are found by the pigeonhole principle:
if two hashes differ in <= 3 bits, at least one of four 16-bit bands must match
EXACTLY (3 differing bits cannot touch all 4 bands). Four btree lookups narrow
50k rows to a handful, then an exact popcount ranks them.

95% similarity == 5% of 64 bits == Hamming distance 3. That is where the
"95% match" on the verification screen comes from: it is computed, not asserted.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass

_MASK16 = 0xFFFF
_U64 = 0xFFFFFFFFFFFFFFFF

# Distance 3 == 95.3% similarity. The recall pass widens to 6 (90.6%) so the
# "suggestive" tier of the IMAGE_REUSE rule has candidates to rank.
DUPLICATE_DISTANCE = 3
RECALL_DISTANCE = 6


def to_signed(unsigned: int) -> int:
    """Map an unsigned 64-bit hash into a signed BIGINT.

    TRAP: `imagehash` yields an unsigned 64-bit integer, but Postgres BIGINT is
    signed. Any hash with the top bit set (half of them) overflows on insert.
    This conversion must be applied identically on write and on query, or the
    XOR compares different bit orderings and silently returns nothing.
    """
    return struct.unpack("<q", struct.pack("<Q", unsigned & _U64))[0]


def to_unsigned(signed: int) -> int:
    return struct.unpack("<Q", struct.pack("<q", signed))[0]


def bands(unsigned: int) -> tuple[int, int, int, int]:
    """Split into four 16-bit band values for the pigeonhole index."""
    u = unsigned & _U64
    return (
        u & _MASK16,
        (u >> 16) & _MASK16,
        (u >> 32) & _MASK16,
        (u >> 48) & _MASK16,
    )


def hamming(a_unsigned: int, b_unsigned: int) -> int:
    return ((a_unsigned ^ b_unsigned) & _U64).bit_count()


def similarity(distance: int) -> float:
    """Hamming distance -> the percentage rendered on screen."""
    return 1.0 - (distance / 64.0)


@dataclass(frozen=True)
class PhashValue:
    unsigned: int

    @property
    def signed(self) -> int:
        return to_signed(self.unsigned)

    @property
    def band_values(self) -> tuple[int, int, int, int]:
        return bands(self.unsigned)


def compute(image_path: str) -> PhashValue:
    """Compute the perceptual hash of an image file.

    Pillow/imagehash are imported lazily: they cost meaningful import time and
    the API must not pay for them on a cold start that never touches a photo.
    """
    import imagehash
    from PIL import Image

    with Image.open(image_path) as img:
        h = imagehash.phash(img, hash_size=8)

    bits = "".join("1" if b else "0" for b in h.hash.flatten())
    return PhashValue(unsigned=int(bits, 2))


# Candidate query. Four indexed band equality checks, then an exact popcount on
# the survivors. `bit_count()` needs PG14+ and takes bit/bytea, NOT bigint -
# hence the ::bit(64) casts.
NEAR_DUPLICATE_SQL = """
SELECT e.id, e.work_id, e.storage_key,
       bit_count(e.phash::bit(64) # CAST(:phash AS bigint)::bit(64)) AS distance
FROM evidence e
WHERE e.phash IS NOT NULL
  AND e.work_id <> :work_id
  AND e.deleted_at IS NULL
  AND (e.pb0 = :b0 OR e.pb1 = :b1 OR e.pb2 = :b2 OR e.pb3 = :b3)
  AND bit_count(e.phash::bit(64) # CAST(:phash AS bigint)::bit(64)) <= :max_distance
ORDER BY distance ASC
LIMIT 5
"""


def near_duplicate_params(value: PhashValue, work_id, max_distance: int = RECALL_DISTANCE):
    b0, b1, b2, b3 = value.band_values
    return {
        "phash": value.signed,
        "work_id": work_id,
        "b0": b0, "b1": b1, "b2": b2, "b3": b3,
        "max_distance": max_distance,
    }
