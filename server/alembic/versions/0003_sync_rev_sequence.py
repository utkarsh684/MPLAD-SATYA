"""global sync revision sequence

Revision ID: 0003
Revises: 0002

One monotonic integer cursor across every syncable table. This beats per-table
`updated_at` watermarks: no clock skew, and no rows lost to the equal-timestamp
pagination hole.
"""
from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None

SYNCABLE_TABLES = [
    "works",
    "risk_assessments",
    "verification_sources",
    "field_verifications",
    "fund_releases",
    "evidence",
    "citizen_reports",
    "decisions",
    "users",
]


def upgrade() -> None:
    op.execute("CREATE SEQUENCE IF NOT EXISTS sync_rev_seq")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION satya_bump_rev()
        RETURNS trigger AS $$
        BEGIN
            NEW.rev := nextval('sync_rev_seq');
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """
    )
    for table in SYNCABLE_TABLES:
        op.execute(
            f"""
            CREATE TRIGGER trg_{table}_rev
            BEFORE INSERT OR UPDATE ON {table}
            FOR EACH ROW EXECUTE FUNCTION satya_bump_rev();
            """
        )
        op.execute(f"UPDATE {table} SET rev = nextval('sync_rev_seq')")


def downgrade() -> None:
    for table in SYNCABLE_TABLES:
        op.execute(f"DROP TRIGGER IF EXISTS trg_{table}_rev ON {table}")
    op.execute("DROP FUNCTION IF EXISTS satya_bump_rev()")
    op.execute("DROP SEQUENCE IF EXISTS sync_rev_seq")
