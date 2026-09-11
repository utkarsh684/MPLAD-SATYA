from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool

import app.models  # noqa: F401  -- registers every table on Base.metadata
from alembic import context
from app.config import settings
from app.db import Base

config = context.config
# Migrations prefer the direct connection when one is configured; see
# Settings.database_migration_url.
MIGRATION_URL = settings.database_migration_url or settings.database_url
config.set_main_option("sqlalchemy.url", MIGRATION_URL)
if config.config_file_name:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

# PostGIS installs tables, views and indexes that Alembic knows nothing about.
# Without this filter, `autogenerate` cheerfully emits
# `op.drop_table('spatial_ref_sys')` and drops GeoAlchemy2's spatial indexes.
# Everyone using GeoAlchemy2 hits this exactly once, always on the day it matters.
POSTGIS_OWNED = {
    "spatial_ref_sys", "geography_columns", "geometry_columns",
    "raster_columns", "raster_overviews", "topology", "layer",
}


def include_object(obj, name, type_, reflected, compare_to):
    if type_ == "table" and name in POSTGIS_OWNED:
        return False
    # GeoAlchemy2 creates its own GIST indexes; Alembic sees them as strays.
    if type_ == "index" and name and name.startswith("idx_") and "geom" in name:
        return False
    return True


def run_migrations_offline() -> None:
    context.configure(
        url=MIGRATION_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        include_object=include_object,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            include_object=include_object,
            compare_type=True,
        )
        with context.begin_transaction():
            # Alembic does not lock by default. Two uvicorn workers racing on
            # `upgrade head` will deadlock or double-apply.
            connection.exec_driver_sql(
                "SELECT pg_advisory_xact_lock(hashtext('satya_alembic'))"
            )
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
