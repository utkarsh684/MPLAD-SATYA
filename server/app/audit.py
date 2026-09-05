"""Append-only audit chain.

Deliberately NOT a blockchain. Blockchain solves consensus among mutually
distrusting writers; MoSPI is a single writer, so there is no consensus problem
here -- only integrity and non-repudiation. A sha256 chain gives exactly that,
in one table, verifiable in milliseconds.

Honest limitation, stated up front: an attacker with write access to the
database could recompute every hash from a tampered record forward. Defence is
in depth, not in the hash alone: migration 0002 REVOKEs UPDATE/DELETE from the
application role and installs a trigger that raises on either. The application
literally cannot rewrite history, and neither can a stray migration.
"""

from __future__ import annotations

import hashlib
import json
import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models import AuditLog

GENESIS = "0" * 64


def canonical(obj: Any) -> bytes:
    """Deterministic JSON encoding.

    Pinned in one place and covered by a test with a hard-coded digest: if
    anyone changes `sort_keys` or `separators`, that test fails loudly instead
    of silently invalidating the entire historical chain.
    """
    return json.dumps(
        obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False, default=str
    ).encode("utf-8")


def leaf_hash(
    *,
    ts: datetime,
    actor_user_id: uuid.UUID | None,
    actor_role: str | None,
    action: str,
    entity_type: str | None,
    entity_id: uuid.UUID | None,
    payload: dict,
) -> str:
    return hashlib.sha256(
        canonical(
            {
                "ts": ts.isoformat(timespec="microseconds"),
                "actor_user_id": str(actor_user_id) if actor_user_id else None,
                "actor_role": actor_role,
                "action": action,
                "entity_type": entity_type,
                "entity_id": str(entity_id) if entity_id else None,
                "payload": payload,
            }
        )
    ).hexdigest()


def chain_hash(prev_hash: str, leaf: str) -> str:
    return hashlib.sha256((prev_hash + leaf).encode("ascii")).hexdigest()


def append(
    db: Session,
    *,
    action: str,
    payload: dict,
    actor_user_id: uuid.UUID | None = None,
    actor_role: str | None = None,
    entity_type: str | None = None,
    entity_id: uuid.UUID | None = None,
) -> AuditLog:
    """Append one record.

    MUST be called inside the same transaction as the mutation it records, so a
    rolled-back decision leaves no phantom audit entry. The transaction-scoped
    advisory lock serialises chain appends and releases on commit or rollback.
    """
    # ponytail: one global advisory lock serialises all appends. Free at this
    # volume (~140 writes/day). Shard by district into N chains if writes ever
    # exceed ~200/sec.
    db.execute(text("SELECT pg_advisory_xact_lock(hashtext('satya_audit_chain'))"))

    prev = db.execute(
        select(AuditLog.hash).order_by(AuditLog.seq.desc()).limit(1)
    ).scalar_one_or_none()
    prev_hash = prev or GENESIS

    ts = datetime.now().astimezone()
    leaf = leaf_hash(
        ts=ts, actor_user_id=actor_user_id, actor_role=actor_role, action=action,
        entity_type=entity_type, entity_id=entity_id, payload=payload,
    )
    row = AuditLog(
        ts=ts, actor_user_id=actor_user_id, actor_role=actor_role, action=action,
        entity_type=entity_type, entity_id=entity_id, payload=payload,
        leaf_hash=leaf, prev_hash=prev_hash, hash=chain_hash(prev_hash, leaf),
    )
    db.add(row)
    db.flush()
    return row


def verify(db: Session, start: int = 1, end: int | None = None) -> dict:
    """Walk the chain, recomputing every hash. Names the exact break point."""
    q = select(AuditLog).order_by(AuditLog.seq)
    if start:
        q = q.filter(AuditLog.seq >= start)
    if end:
        q = q.filter(AuditLog.seq <= end)

    prev_hash = GENESIS
    checked = 0
    first_seq: int | None = None
    last: AuditLog | None = None

    for row in db.execute(q).scalars():
        if first_seq is None:
            first_seq = row.seq
            # A partial verification starts from the stored prev_hash; a full
            # walk from seq 1 must start at genesis.
            prev_hash = GENESIS if row.seq == 1 else row.prev_hash

        recomputed_leaf = leaf_hash(
            ts=row.ts, actor_user_id=row.actor_user_id, actor_role=row.actor_role,
            action=row.action, entity_type=row.entity_type, entity_id=row.entity_id,
            payload=row.payload,
        )
        if recomputed_leaf != row.leaf_hash:
            return {
                "valid": False, "checked": checked, "broken_at_seq": row.seq,
                "problem": "record contents do not match their stored leaf hash",
                "expected": recomputed_leaf, "found": row.leaf_hash,
            }
        if row.prev_hash != prev_hash:
            return {
                "valid": False, "checked": checked, "broken_at_seq": row.seq,
                "problem": "chain link broken (a record was removed or reordered)",
                "expected": prev_hash, "found": row.prev_hash,
            }
        expected_hash = chain_hash(row.prev_hash, row.leaf_hash)
        if expected_hash != row.hash:
            return {
                "valid": False, "checked": checked, "broken_at_seq": row.seq,
                "problem": "stored chain hash is inconsistent",
                "expected": expected_hash, "found": row.hash,
            }

        prev_hash = row.hash
        checked += 1
        last = row

    return {
        "valid": True,
        "checked": checked,
        "first_seq": first_seq,
        "last_seq": last.seq if last else None,
        "head_hash": prev_hash if checked else None,
    }
