"""initial schema

Revision ID: 0001
Revises:
"""
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    # ponytail: the initial schema is created straight from the model metadata
    # rather than a hand-transcribed op.create_table() wall. It cannot drift
    # from models.py, which is the failure mode that actually bites during a
    # short build. Switch to real autogenerate diffs from 0004 onward, once
    # there is production data whose migration path must be reviewable.
    import app.models  # noqa: F401  -- registers all tables
    from app.db import Base

    Base.metadata.create_all(bind=op.get_bind())


def downgrade() -> None:
    import app.models  # noqa: F401
    from app.db import Base

    Base.metadata.drop_all(bind=op.get_bind())
