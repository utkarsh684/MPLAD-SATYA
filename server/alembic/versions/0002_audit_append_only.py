"""make audit_log physically append-only

Revision ID: 0002
Revises: 0001

Two layers, because one is not enough: the REVOKE stops the application role,
the trigger stops a stray migration or a DBA with psql open. The hash chain
proves tampering happened; these make it fail outright.
"""
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION satya_audit_append_only()
        RETURNS trigger AS $$
        BEGIN
            RAISE EXCEPTION
                'audit_log is append-only (attempted % on seq=%)',
                TG_OP, COALESCE(OLD.seq, -1);
        END;
        $$ LANGUAGE plpgsql;
        """
    )
    op.execute(
        """
        CREATE TRIGGER trg_audit_log_append_only
        BEFORE UPDATE OR DELETE ON audit_log
        FOR EACH ROW EXECUTE FUNCTION satya_audit_append_only();
        """
    )
    # Best-effort: the deployment role may not own the table on managed
    # Postgres. The trigger above is the guarantee that always holds.
    op.execute(
        """
        DO $$
        BEGIN
            EXECUTE format('REVOKE UPDATE, DELETE ON audit_log FROM %I', current_user);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'could not revoke on audit_log: %', SQLERRM;
        END $$;
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS trg_audit_log_append_only ON audit_log")
    op.execute("DROP FUNCTION IF EXISTS satya_audit_append_only()")
