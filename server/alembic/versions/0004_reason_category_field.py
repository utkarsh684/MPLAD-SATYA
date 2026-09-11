"""add the missing 'field' reason category

Four of the 33 rules in risk/rules.json carry category "field" -
MEASUREMENT_MISMATCH, WORK_NOT_STARTED_ON_SITE, DIFFERENT_WORK_ON_SITE and
SATELLITE_INCONCLUSIVE_ESCALATE - but reason_cat_t was created without it.
Any assessment containing one of them failed to INSERT with

    LookupError: 'field' is not among the defined enum values

MEASUREMENT_MISMATCH is one of the five reasons on the demo work MP/2026/1142,
so the hero scenario could not be persisted at all. It went unnoticed because
assess() is a pure function: the golden test scores 78 without ever touching a
database.

Revision ID: 0004
Revises: 0003
"""

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ALTER TYPE ... ADD VALUE cannot run inside a transaction block that later
    # uses the new value, so it gets its own autocommit block.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE reason_cat_t ADD VALUE IF NOT EXISTS 'field'")


def downgrade() -> None:
    # Postgres cannot remove a value from an enum. Reversing this would mean
    # recreating the type and rewriting every dependent column, which would
    # destroy rows that legitimately use it.
    raise NotImplementedError("enum values cannot be dropped in PostgreSQL")
