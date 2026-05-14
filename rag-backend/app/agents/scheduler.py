"""APScheduler wiring for agentic jobs.

Uses AsyncIOScheduler so jobs share the FastAPI event loop. The job store
is SQLAlchemy-backed (synchronous connection string) so scheduled jobs
survive server restarts.

Primary job: `daily_brief_all_users` runs every morning at 08:00 UTC and
dispatches a per-user brief generation task. Per-user timezone support is
handled inside the job by comparing the user's local hour — a simple
pattern that avoids N cron jobs.
"""

from __future__ import annotations

import logging

from apscheduler.jobstores.sqlalchemy import SQLAlchemyJobStore
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import select

from app.agents.daily_brief import run_daily_brief
from app.agents.prioritizer import run_prioritizer
from app.config import settings
from app.connectors import google_calendar
from app.database import async_session
from app.models.connectors import OAuthCredential
from app.models.identity import UserProfile
from app.models.user import User

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None


def _sync_db_url() -> str:
    """Derive a sync SQLAlchemy URL from the async DATABASE_URL.

    APScheduler's SQLAlchemyJobStore uses synchronous drivers.
    """
    url = settings.DATABASE_URL
    return (
        url.replace("sqlite+aiosqlite://", "sqlite://")
        .replace("postgresql+asyncpg://", "postgresql://")
    )


async def daily_brief_all_users() -> None:
    """Dispatch daily briefs for every user whose local time is around 8am.

    This job runs hourly. For each run we check each user's timezone and
    trigger a brief if the user's local hour equals 8. This is simpler
    than maintaining N per-user cron jobs and degrades gracefully if a
    user hasn't set a timezone yet (we fall back to UTC, so a UTC user
    at 8am UTC still gets theirs).
    """
    from datetime import datetime

    try:
        import pytz  # type: ignore
    except ImportError:
        pytz = None

    async with async_session() as db:
        users_result = await db.execute(select(User))
        users = users_result.scalars().all()

        for user in users:
            profile_result = await db.execute(
                select(UserProfile).where(UserProfile.user_id == user.id)
            )
            profile = profile_result.scalar_one_or_none()
            tz_name = (profile.timezone if profile and profile.timezone else "UTC")

            if pytz is not None:
                try:
                    tz = pytz.timezone(tz_name)
                    local_hour = datetime.now(tz).hour
                except Exception:
                    local_hour = datetime.utcnow().hour
            else:
                local_hour = datetime.utcnow().hour

            if local_hour != 8:
                continue

            logger.info("Running prioritizer for user %s (tz=%s)", user.id, tz_name)
            try:
                await run_prioritizer(user_id=user.id, db=db, trigger="scheduled")
            except Exception as exc:  # noqa: BLE001
                logger.exception("prioritizer failed for user %s: %s", user.id, exc)
            # Legacy daily brief still runs alongside for transition; it can
            # be removed once the prioritizer has earned its keep.
            try:
                await run_daily_brief(user_id=user.id, db=db, trigger="scheduled")
            except Exception as exc:  # noqa: BLE001
                logger.exception("daily_brief failed for user %s: %s", user.id, exc)


async def sync_all_calendars() -> None:
    """Periodic job: refresh calendar events for every connected user.

    Runs on a cron schedule (every 15 min). Skips users without credentials
    and tolerates per-user sync failures.
    """
    if not google_calendar.is_configured():
        return

    async with async_session() as db:
        creds_result = await db.execute(
            select(OAuthCredential).where(
                OAuthCredential.provider == google_calendar.PROVIDER
            )
        )
        creds = creds_result.scalars().all()

        for cred in creds:
            try:
                await google_calendar.sync_user_events(cred.user_id, db)
            except Exception as exc:  # noqa: BLE001
                logger.warning(
                    "Calendar sync failed for user %s: %s", cred.user_id, exc
                )


def start_scheduler() -> AsyncIOScheduler | None:
    """Create and start the scheduler. Returns None if startup fails.

    A scheduler failure MUST NOT prevent the FastAPI app from serving
    requests — we log and return None so the lifespan handler can proceed.
    """
    global _scheduler
    if _scheduler is not None:
        return _scheduler

    try:
        jobstores = {"default": SQLAlchemyJobStore(url=_sync_db_url())}
        scheduler = AsyncIOScheduler(jobstores=jobstores, timezone="UTC")
        scheduler.add_job(
            daily_brief_all_users,
            trigger="cron",
            minute=0,
            id="daily_brief_hourly_dispatch",
            replace_existing=True,
            max_instances=1,
            coalesce=True,
            misfire_grace_time=900,
        )
        scheduler.add_job(
            sync_all_calendars,
            trigger="cron",
            minute="*/15",
            id="calendar_sync_periodic",
            replace_existing=True,
            max_instances=1,
            coalesce=True,
            misfire_grace_time=300,
        )
        scheduler.start()
        _scheduler = scheduler
        logger.info("APScheduler started with daily_brief + calendar_sync jobs")
        return scheduler
    except Exception as exc:  # noqa: BLE001
        logger.exception("Failed to start APScheduler: %s", exc)
        return None


def shutdown_scheduler() -> None:
    global _scheduler
    if _scheduler is not None:
        try:
            _scheduler.shutdown(wait=False)
        except Exception:
            pass
        _scheduler = None
