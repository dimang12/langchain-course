"""REST endpoints for third-party connectors (Google Calendar for now)."""

from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import get_current_user
from app.connectors import google_calendar
from app.database import async_session, get_db
from app.models.connectors import CalendarEvent, OAuthCredential
from app.models.user import User

router = APIRouter()


def _credential_to_dict(cred: OAuthCredential) -> dict:
    return {
        "id": cred.id,
        "provider": cred.provider,
        "account_email": cred.account_email,
        "scopes": cred.scopes,
        "expires_at": cred.expires_at.isoformat() if cred.expires_at else None,
        "last_synced_at": cred.last_synced_at.isoformat() if cred.last_synced_at else None,
        "created_at": cred.created_at.isoformat(),
    }


# ---------------------------------------------------------------------------
# Listing + status
# ---------------------------------------------------------------------------
@router.get("/")
async def list_connections(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(OAuthCredential).where(OAuthCredential.user_id == user.id)
    )
    creds = result.scalars().all()
    return {
        "google_calendar_configured": google_calendar.is_configured(),
        "connections": [_credential_to_dict(c) for c in creds],
    }


# ---------------------------------------------------------------------------
# Google OAuth
# ---------------------------------------------------------------------------
@router.get("/google/authorize")
async def google_authorize(
    user: User = Depends(get_current_user),
):
    if not google_calendar.is_configured():
        raise HTTPException(
            status_code=503,
            detail=(
                "Google OAuth is not configured. Set GOOGLE_CLIENT_ID and "
                "GOOGLE_CLIENT_SECRET in your backend .env to enable."
            ),
        )
    try:
        url = google_calendar.build_authorize_url(user.id)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Failed to build authorize URL: {exc}")
    return {"authorize_url": url}


@router.get("/google/callback", response_class=HTMLResponse)
async def google_callback(
    code: str = Query(...),
    state: str = Query(...),
):
    """OAuth redirect target. The authenticated user session isn't available
    here (this is a raw browser redirect from Google), so we identify the
    user from the signed state parameter.
    """
    if not google_calendar.is_configured():
        return HTMLResponse(
            "<h1>Google OAuth not configured</h1>",
            status_code=503,
        )

    async with async_session() as db:
        try:
            cred = await google_calendar.exchange_code(code, state, db)
        except ValueError as exc:
            return HTMLResponse(f"<h1>OAuth error</h1><p>{exc}</p>", status_code=400)
        except Exception as exc:  # noqa: BLE001
            return HTMLResponse(f"<h1>OAuth error</h1><p>{exc}</p>", status_code=500)

        # Kick off an initial sync in-line so the first brief has events
        try:
            await google_calendar.sync_user_events(cred.user_id, db)
        except Exception:
            pass

    return HTMLResponse(
        """
        <html>
        <head><title>Connected</title></head>
        <body style="font-family:-apple-system,sans-serif;padding:40px;text-align:center;">
          <h1>✓ Google Calendar connected</h1>
          <p>You can close this window and return to the app.</p>
          <script>setTimeout(function(){window.close()}, 1500);</script>
        </body>
        </html>
        """
    )


@router.post("/google/sync")
async def google_sync(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        count = await google_calendar.sync_user_events(user.id, db)
    except RuntimeError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=500, detail=f"Sync failed: {exc}")
    return {"status": "synced", "events_upserted": count}


@router.delete("/google")
async def google_disconnect(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    ok = await google_calendar.delete_credential(db, user.id)
    return {"status": "disconnected" if ok else "not_connected"}


# ---------------------------------------------------------------------------
# Dev seed — fake calendar events for local testing
# ---------------------------------------------------------------------------
@router.post("/google/dev-seed")
async def google_dev_seed(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Populate fake calendar events for testing. Does NOT require GCP setup."""
    count = await google_calendar.dev_seed_events(db, user.id)
    return {"status": "seeded", "events_created": count}


# ---------------------------------------------------------------------------
# Events listing
# ---------------------------------------------------------------------------
@router.get("/events")
async def list_events(
    start: str | None = Query(None, description="ISO datetime lower bound"),
    end: str | None = Query(None, description="ISO datetime upper bound"),
    limit: int = Query(100, ge=1, le=500),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from datetime import datetime

    stmt = select(CalendarEvent).where(CalendarEvent.user_id == user.id)
    if start:
        try:
            stmt = stmt.where(CalendarEvent.start_time >= datetime.fromisoformat(start))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid start ISO datetime")
    if end:
        try:
            stmt = stmt.where(CalendarEvent.start_time <= datetime.fromisoformat(end))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid end ISO datetime")

    stmt = stmt.order_by(CalendarEvent.start_time).limit(limit)

    result = await db.execute(stmt)
    events = result.scalars().all()
    return [_event_to_dict(e) for e in events]


def _event_to_dict(e: CalendarEvent) -> dict:
    return {
        "id": e.id,
        "provider": e.provider,
        "provider_event_id": e.provider_event_id,
        "title": e.title,
        "description": e.description,
        "start_time": e.start_time.isoformat(),
        "end_time": e.end_time.isoformat(),
        "is_all_day": e.is_all_day,
        "location": e.location,
        "meeting_url": e.meeting_url,
        "attendees": e.attendees,
        "organizer": e.organizer,
        "status": e.status,
    }


# ---------------------------------------------------------------------------
# Create / Update / Delete events
# ---------------------------------------------------------------------------
class CreateEventRequest(BaseModel):
    title: str
    start_time: str
    end_time: str
    description: str | None = None
    is_all_day: bool = False
    location: str | None = None
    meeting_url: str | None = None
    attendees: list[str] | None = None


class UpdateEventRequest(BaseModel):
    title: str | None = None
    start_time: str | None = None
    end_time: str | None = None
    description: str | None = None
    is_all_day: bool | None = None
    location: str | None = None
    meeting_url: str | None = None
    attendees: list[str] | None = None
    status: str | None = None


@router.post("/events")
async def create_event(
    request: CreateEventRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        start = datetime.fromisoformat(request.start_time)
        end = datetime.fromisoformat(request.end_time)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid datetime format")

    event = CalendarEvent(
        user_id=user.id,
        provider="local",
        provider_event_id=f"local-{uuid.uuid4()}",
        title=request.title,
        description=request.description,
        start_time=start,
        end_time=end,
        is_all_day=request.is_all_day,
        location=request.location,
        meeting_url=request.meeting_url,
        attendees=request.attendees,
        status="confirmed",
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return _event_to_dict(event)


@router.put("/events/{event_id}")
async def update_event(
    event_id: str,
    request: UpdateEventRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id,
            CalendarEvent.user_id == user.id,
        )
    )
    event = result.scalar_one_or_none()
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")

    if request.title is not None:
        event.title = request.title
    if request.description is not None:
        event.description = request.description
    if request.start_time is not None:
        event.start_time = datetime.fromisoformat(request.start_time)
    if request.end_time is not None:
        event.end_time = datetime.fromisoformat(request.end_time)
    if request.is_all_day is not None:
        event.is_all_day = request.is_all_day
    if request.location is not None:
        event.location = request.location
    if request.meeting_url is not None:
        event.meeting_url = request.meeting_url
    if request.attendees is not None:
        event.attendees = request.attendees
    if request.status is not None:
        event.status = request.status

    await db.commit()
    await db.refresh(event)
    return _event_to_dict(event)


@router.delete("/events/{event_id}")
async def delete_event(
    event_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id,
            CalendarEvent.user_id == user.id,
        )
    )
    event = result.scalar_one_or_none()
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found")

    await db.delete(event)
    await db.commit()
    return {"status": "deleted"}
