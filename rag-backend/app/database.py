import os

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

os.makedirs(os.path.dirname(settings.DATABASE_URL.split("///")[-1]) or ".", exist_ok=True)

engine = create_async_engine(settings.DATABASE_URL, echo=False)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with async_session() as session:
        yield session


# Phase K foundation: columns added after the original table was created.
# create_all() does not modify existing tables, so we apply ALTER TABLE
# additions idempotently on startup. Each tuple is (table, column, ddl).
# Only safe for ADDITIVE changes (new nullable columns or columns with defaults).
_COLUMN_ADDITIONS: list[tuple[str, str, str]] = [
    ("todos", "goal_id", "VARCHAR"),
    ("todos", "estimated_minutes", "INTEGER"),
    ("todos", "is_today_priority", "BOOLEAN NOT NULL DEFAULT 0"),
    ("people", "last_contacted_at", "DATETIME"),
    ("people", "relationship_strength", "FLOAT NOT NULL DEFAULT 0.5"),
    ("agent_runs", "recommendations", "JSON"),
]


async def _ensure_additive_columns(conn) -> None:
    """SQLite-friendly idempotent column add. Skips if column already exists."""
    for table, column, ddl in _COLUMN_ADDITIONS:
        try:
            result = await conn.execute(text(f"PRAGMA table_info({table})"))
            existing = {row[1] for row in result.fetchall()}
            if column in existing:
                continue
            await conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {ddl}"))
        except Exception:
            # Table missing yet, or non-SQLite dialect — create_all handles
            # fresh tables and Postgres prod uses Alembic.
            continue


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await _ensure_additive_columns(conn)
