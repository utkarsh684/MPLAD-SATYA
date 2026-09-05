"""pHash conversion and banding.

The signed/unsigned round trip is the one that fails intermittently in
production if it is wrong -- only for hashes with the top bit set -- so it gets
an explicit exhaustive-ish test rather than a smoke check.
"""

import random

from app.services import phash


def test_signed_roundtrip_covers_the_top_bit():
    cases = [0, 1, 2**62, 2**63, 2**63 + 1, 2**64 - 1, 0xFFFFFFFFFFFFFFFF]
    rng = random.Random(7)
    cases += [rng.getrandbits(64) for _ in range(2000)]
    for u in cases:
        s = phash.to_signed(u)
        assert -(2**63) <= s <= 2**63 - 1, f"{u} -> {s} outside BIGINT range"
        assert phash.to_unsigned(s) == u


def test_bands_reconstruct_the_hash():
    rng = random.Random(11)
    for _ in range(500):
        u = rng.getrandbits(64)
        b0, b1, b2, b3 = phash.bands(u)
        for b in (b0, b1, b2, b3):
            assert 0 <= b <= 0xFFFF
        assert (b3 << 48) | (b2 << 32) | (b1 << 16) | b0 == u


def test_pigeonhole_guarantee_holds():
    """The claim the whole no-vector-DB design rests on.

    If two hashes differ in <= 3 bits, at least one 16-bit band must be equal.
    If that is false, the candidate query silently misses real duplicates.
    """
    rng = random.Random(13)
    for _ in range(3000):
        a = rng.getrandbits(64)
        flips = rng.randint(0, phash.DUPLICATE_DISTANCE)
        b = a
        for pos in rng.sample(range(64), flips):
            b ^= 1 << pos
        assert phash.hamming(a, b) <= phash.DUPLICATE_DISTANCE
        assert any(x == y for x, y in zip(phash.bands(a), phash.bands(b), strict=True)), (
            "pigeonhole broken: a <=3-bit difference shared no band"
        )


def test_similarity_matches_the_number_on_screen():
    assert round(phash.similarity(3) * 100) == 95   # the mockup's "95% match"
    assert phash.similarity(0) == 1.0
    assert round(phash.similarity(6) * 100) == 91


def test_hamming_is_symmetric_and_zero_for_identical():
    rng = random.Random(17)
    for _ in range(500):
        a, b = rng.getrandbits(64), rng.getrandbits(64)
        assert phash.hamming(a, b) == phash.hamming(b, a)
        assert phash.hamming(a, a) == 0
