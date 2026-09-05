"""Canonicalisation is the load-bearing detail of the audit chain.

If `canonical()` ever changes shape, every historical hash becomes
unverifiable. The hard-coded digest below is the tripwire.
"""

import hashlib
from datetime import UTC, datetime

from app.audit import GENESIS, canonical, chain_hash, leaf_hash


def test_canonical_is_stable():
    a = canonical({"b": 1, "a": 2, "c": [3, 2, 1]})
    b = canonical({"c": [3, 2, 1], "a": 2, "b": 1})
    assert a == b == b'{"a":2,"b":1,"c":[3,2,1]}'
    assert hashlib.sha256(a).hexdigest() == (
        "bbf618dc23e53236ec7ba96c7d4d0b6e1d660943b309478a037cd97263de21d9"
    )


def test_leaf_hash_is_deterministic_and_order_independent():
    kw = dict(
        ts=datetime(2026, 9, 5, 10, 30, tzinfo=UTC),
        actor_user_id=None, actor_role="district_officer",
        action="fund_release.hold", entity_type="fund_releases", entity_id=None,
    )
    h1 = leaf_hash(**kw, payload={"from": {"status": "pending"}, "to": {"status": "held"}})
    h2 = leaf_hash(**kw, payload={"to": {"status": "held"}, "from": {"status": "pending"}})
    assert h1 == h2
    assert len(h1) == 64
    # Pinned: changing canonical() or the leaf field set breaks this on purpose.
    assert h1 == "2e6c87e1629b8399e58540fa01f54730f64b4f35a51b118acc24d16eed366c4e"


def test_chain_links_change_when_any_link_changes():
    leaf = "a" * 64
    assert chain_hash(GENESIS, leaf) != chain_hash("b" * 64, leaf)
    assert chain_hash(GENESIS, leaf) == chain_hash(GENESIS, leaf)


def test_tampering_a_payload_changes_the_leaf():
    kw = dict(
        ts=datetime(2026, 9, 5, 10, 30, tzinfo=UTC), actor_user_id=None,
        actor_role="mospi_admin", action="fund_release.approve",
        entity_type="fund_releases", entity_id=None,
    )
    clean = leaf_hash(**kw, payload={"amount_paise": 156_000_000})
    tampered = leaf_hash(**kw, payload={"amount_paise": 156_000_001})
    assert clean != tampered
