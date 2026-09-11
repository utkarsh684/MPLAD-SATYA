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


def _engine_kwargs(url: str) -> dict:
    if not is_transaction_pooler(url):
        # Direct connection: SQLAlchemy owns the pool.
        #
        # pool_pre_ping is mandatory, not optional. Managed Postgres (Neon
        # especially, with auto-suspend) drops idle connections; without
        # pre-ping the first request after a quiet period raises
        # OperationalError and looks like a total outage.
        return {"pool_size": 5, "max_overflow": 5, "pool_pre_ping": True}

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
            # psycopg3 promotes a statement to a server-side prepared statement
            # after prepare_threshold executions (default 5). In transaction
            # mode the next transaction may land on a different backend that
            # has never seen that statement, which surfaces as
            # 'prepared statement "_pg3_0" does not exist' - intermittently,
            # only under load, only after the fifth call. None disables it.
            "prepare_threshold": None,
        },
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
