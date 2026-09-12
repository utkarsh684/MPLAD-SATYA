"""Engine and session wiring."""

from collections.abc import Iterator
from urllib.parse import urlparse

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings


def is_transaction_pooler(url: str) -> bool:
    """True when the URL points at a transaction-mode connection pooler.

    Supabase serves Supavisor on 6543 (transaction mode) and direct Postgres on
    5432 (session mode); pgBouncer deployments conventionally use 6432. The
    distinction matters because transaction mode hands a different backend
    connection to every transaction, so anything that outlives one transaction
    is unavailable: server-side prepared statements, session advisory locks,
    LISTEN/NOTIFY, temporary tables.

    Our audit chain uses pg_advisory_xact_lock, which is transaction-scoped
    and therefore safe here. Prepared statements are not, and psycopg3 creates
    them automatically - see the connect_args below.
    """
    # Port is the only reliable discriminator. Supabase serves BOTH poolers
    # from the same hostname - session mode on 5432, transaction mode on 6543 -
    # so matching on "pooler." in the host would wrongly cripple the session
    # pooler, which supports prepared statements perfectly well.
    return urlparse(url).port in (6543, 6432)


def is_remote(url: str) -> bool:
    """True when the database is not on this machine."""
    host = (urlparse(url).hostname or "").lower()
    return host not in ("localhost", "127.0.0.1", "::1", "")


def _engine_kwargs(url: str) -> dict:
    extra: dict = {}
    if is_remote(url):
        # Cap how many rows SQLAlchemy packs into one INSERT ... VALUES.
        #
        # The default lets it build enormous statements - the seeder produced
        # one of 199 KB with 6,400 bound parameters - and pushing that through
        # a long-haul TLS session to a managed database failed with
        # "SSL error: ssl/tls alert bad record mac", a transport-integrity
        # failure rather than anything SQL-level. Smaller pages cost a few
        # extra round trips and make bulk loading survive a real network.
        extra["insertmanyvalues_page_size"] = 50

        # Make a dead connection fail instead of hanging forever.
        #
        # libpq's default is to wait on the socket with no deadline, so when
        # the link to a managed database drops mid-statement - flaky wifi, a
        # pooler restart, a NAT table losing the mapping - the client blocks
        # in poll() indefinitely. The seeder hit exactly this: fourteen
        # minutes of wall clock, eight seconds of CPU, an open socket to a
        # peer that was never going to answer. It looks like slowness, which
        # is why it went unnoticed through several runs.
        #
        # keepalives probe an idle link; tcp_user_timeout bounds how long an
        # *unacknowledged send* may linger, which is the case that actually
        # bit us. Both are needed - keepalives alone do not fire while data
        # is still queued for transmission.
        extra["connect_args"] = {
            "connect_timeout": 15,
            "keepalives": 1,
            "keepalives_idle": 30,
            "keepalives_interval": 10,
            "keepalives_count": 3,
            "tcp_user_timeout": 60_000,  # ms
        }

    if not is_transaction_pooler(url):
        # Direct connection: SQLAlchemy owns the pool.
        #
        # pool_pre_ping is mandatory, not optional. Managed Postgres (Neon
        # especially, with auto-suspend) drops idle connections; without
        # pre-ping the first request after a quiet period raises
        # OperationalError and looks like a total outage.
        return {"pool_size": 5, "max_overflow": 5, "pool_pre_ping": True, **extra}

    return {
        # Behind an external pooler, SQLAlchemy pooling is a second pool in
        # front of the first. Two workers x (5 + 5) would hold twenty upstream
        # slots against a free-tier pooler that allows far fewer, so the pool
        # is kept small and recycled quickly.
        "pool_size": 2,
        "max_overflow": 3,
        "pool_pre_ping": True,
        "pool_recycle": 300,
        "connect_args": {
            # Merged with the remote TCP settings above rather than replacing
            # them; a literal dict here would silently drop the keepalives.
            **extra.pop("connect_args", {}),
            # psycopg3 promotes a statement to a server-side prepared statement
            # after prepare_threshold executions (default 5). In transaction
            # mode the next transaction may land on a different backend that
            # has never seen that statement, which surfaces as
            # 'prepared statement "_pg3_0" does not exist' - intermittently,
            # only under load, only after the fifth call. None disables it.
            "prepare_threshold": None,
        },
        **extra,
    }


engine = create_engine(settings.database_url, future=True, **_engine_kwargs(settings.database_url))

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
