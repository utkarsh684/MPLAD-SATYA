"""Transaction-pooler compatibility.

Supabase serves Supavisor in transaction mode on 6543. Every transaction may
land on a different backend, so anything that outlives one transaction is
unavailable. These tests pin the two settings that make the app survive that,
both of which fail intermittently and only under load if they regress.
"""

import pytest

from app.db import _engine_kwargs, is_transaction_pooler

SUPABASE_POOLER = (
    "postgresql+psycopg://postgres.abc:pw@aws-0-ap-northeast-2.pooler.supabase.com:6543/postgres"
)
SUPABASE_DIRECT = (
    "postgresql+psycopg://postgres:pw@db.abc.supabase.co:5432/postgres"
)
# Same hostname as the transaction pooler, different port and different
# semantics. This is the one that a host-substring check gets wrong.
SUPABASE_SESSION_POOLER = (
    "postgresql+psycopg://postgres.abc:pw@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres"
)
NEON = "postgresql+psycopg://u:pw@ep-cool-name.neon.tech/satya?sslmode=require"
LOCAL = "postgresql+psycopg://satya:satya@localhost:5432/satya"


class TestPoolerDetection:
    @pytest.mark.parametrize("url", [SUPABASE_POOLER])
    def test_supabase_transaction_pooler_is_detected(self, url):
        assert is_transaction_pooler(url) is True

    @pytest.mark.parametrize("url", [SUPABASE_DIRECT, NEON, LOCAL])
    def test_direct_connections_are_not_treated_as_pooled(self, url):
        assert is_transaction_pooler(url) is False

    def test_session_pooler_is_not_transaction_pooled(self):
        """Session mode keeps one backend per client, so prepared statements
        and session state are fine. Supabase serves it from the SAME hostname
        as the transaction pooler, so only the port distinguishes them."""
        assert is_transaction_pooler(SUPABASE_SESSION_POOLER) is False
        assert "prepare_threshold" not in _engine_kwargs(
            SUPABASE_SESSION_POOLER
        )["connect_args"]

    def test_pgbouncer_default_port_is_detected(self):
        assert is_transaction_pooler(
            "postgresql+psycopg://u:p@bouncer.internal:6432/db"
        ) is True


class TestPreparedStatementsAreDisabledBehindAPooler:
    """The failure this prevents is nasty: psycopg3 promotes a statement to a
    server-side prepared statement after five executions, and in transaction
    mode the sixth call may land on a backend that never saw it. It surfaces as
    'prepared statement "_pg3_0" does not exist' - intermittently, under load,
    never in a smoke test.
    """

    def test_pooler_disables_auto_prepare(self):
        kwargs = _engine_kwargs(SUPABASE_POOLER)
        assert kwargs["connect_args"]["prepare_threshold"] is None

    def test_direct_connection_keeps_prepared_statements(self):
        # They are a genuine performance win when the connection is ours.
        assert "prepare_threshold" not in _engine_kwargs(NEON)["connect_args"]

    def test_local_connection_has_no_connect_args_at_all(self):
        # Nothing to tune over a loopback socket.
        assert "connect_args" not in _engine_kwargs(LOCAL)


class TestPoolSizing:
    def test_pooler_pool_is_small(self):
        """SQLAlchemy pooling in front of an external pooler is a second pool.

        Two workers x (5 + 5) would hold twenty upstream slots against a
        free-tier pooler that allows far fewer.
        """
        kwargs = _engine_kwargs(SUPABASE_POOLER)
        assert kwargs["pool_size"] + kwargs["max_overflow"] <= 5
        assert kwargs["pool_recycle"] == 300

    def test_direct_connection_keeps_the_larger_pool(self):
        kwargs = _engine_kwargs(NEON)
        assert kwargs["pool_size"] == 5

    def test_pre_ping_is_always_on(self):
        # Managed Postgres drops idle connections; without pre-ping the first
        # request after a quiet period looks like a total outage.
        for url in (SUPABASE_POOLER, NEON, LOCAL):
            assert _engine_kwargs(url)["pool_pre_ping"] is True


class TestMigrationsAvoidThePooler:
    def test_migration_url_falls_back_to_the_main_url(self):
        from app.config import Settings
        s = Settings(_env_file=None, database_url=NEON, jwt_secret="x" * 32)
        assert s.database_migration_url == ""
        assert (s.database_migration_url or s.database_url) == NEON

    def test_migration_url_overrides_when_set(self):
        from app.config import Settings
        s = Settings(
            _env_file=None,
            database_url=SUPABASE_POOLER,
            database_migration_url=SUPABASE_DIRECT,
            jwt_secret="x" * 32,
        )
        chosen = s.database_migration_url or s.database_url
        assert chosen == SUPABASE_DIRECT
        assert is_transaction_pooler(chosen) is False, (
            "DDL must not run through a transaction pooler"
        )


class TestAuditLockRemainsValid:
    def test_audit_chain_uses_a_transaction_scoped_lock(self):
        """pg_advisory_xact_lock is released at COMMIT, so it is pooler-safe.

        pg_advisory_lock (session-scoped) would leak into whichever unrelated
        transaction reused that backend next and could deadlock the chain.
        """
        source = (__import__("pathlib").Path(__file__).parent.parent
                  / "app" / "audit.py").read_text()
        assert "pg_advisory_xact_lock" in source
        assert "pg_advisory_lock(" not in source


class TestProviderUrlsAreAcceptedVerbatim:
    """Pasting the connection string a provider hands you must just work.

    Supabase, Neon and Render all emit `postgresql://`, which resolves to
    psycopg2 - not installed here - so the app died at import with
    ModuleNotFoundError before any of its own error handling existed.
    """

    @pytest.mark.parametrize("raw,expected", [
        ("postgresql://u:p@h:6543/db", "postgresql+psycopg://u:p@h:6543/db"),
        ("postgres://u:p@h/db", "postgresql+psycopg://u:p@h/db"),
    ])
    def test_bare_urls_are_upgraded_to_psycopg3(self, raw, expected):
        from app.config import Settings
        s = Settings(_env_file=None, database_url=raw, jwt_secret="x" * 32)
        assert s.database_url == expected

    def test_an_explicit_driver_is_left_alone(self):
        from app.config import Settings
        for url in ("postgresql+psycopg://u:p@h/db", "postgresql+asyncpg://u:p@h/db"):
            s = Settings(_env_file=None, database_url=url, jwt_secret="x" * 32)
            assert s.database_url == url

    def test_normalisation_applies_to_the_migration_url_too(self):
        from app.config import Settings
        s = Settings(
            _env_file=None,
            database_url="postgresql://u:p@h:6543/db",
            database_migration_url="postgresql://u:p@h:5432/db",
            jwt_secret="x" * 32,
        )
        assert s.database_migration_url.startswith("postgresql+psycopg://")


class TestDeadConnectionsFailRatherThanHang:
    """libpq waits on a socket with no deadline by default.

    When the link to a managed database dies mid-statement the client blocks
    in poll() forever. The seeder did exactly this for fourteen minutes on
    eight seconds of CPU, which reads as slowness rather than as a fault -
    the reason it survived several runs unnoticed.
    """

    @pytest.mark.parametrize(
        "url", [SUPABASE_POOLER, SUPABASE_SESSION_POOLER, SUPABASE_DIRECT, NEON]
    )
    def test_remote_connections_bound_how_long_they_wait(self, url):
        args = _engine_kwargs(url)["connect_args"]
        assert args["keepalives"] == 1
        # The decisive one: keepalives do not fire while data is still queued
        # for transmission, which is the case that actually hung the seeder.
        assert args["tcp_user_timeout"] > 0
        assert args["connect_timeout"] > 0

    def test_the_pooler_keeps_both_its_settings(self):
        """A literal connect_args dict in the pooler branch would silently
        drop the TCP settings; this pins that they coexist."""
        args = _engine_kwargs(SUPABASE_POOLER)["connect_args"]
        assert args["prepare_threshold"] is None
        assert args["tcp_user_timeout"] > 0
