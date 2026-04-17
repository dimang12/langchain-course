"""Google Calendar connector — OAuth + event sync.

Provides:
- `is_configured()` — quick guard; returns False if Google credentials aren't set
- `build_authorize_url(user_id)` — returns the URL to redirect the user to
- `exchange_code(code, state)` — callback handler; stores encrypted tokens
- `sync_user_events(user_id, db)` — fetches events and upserts into CalendarEvent

The OAuth state parameter encodes the user_id so the callback can identify
who completed the flow. State is signed with the JWT secret for integrity.
"""

from __future__ import annotations

import hmac
import logging
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.connectors.encryption import decrypt, encrypt
from app.models.connectors import CalendarEvent, OAuthCredential

logger = logging.getLogger(__name__)

GOOGLE_SCOPES = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/userinfo.email",
    "openid",
]
PROVIDER = "google_calendar"


def is_configured() -> bool:
    return bool(settings.GOOGLE_CLIENT_ID and settings.GOOGLE_CLIENT_SECRET)


# ---------------------------------------------------------------------------
# State parameter — signed user_id for CSRF + identification on callback
# ---------------------------------------------------------------------------
def _sign_state(user_id: str) -> str:
    key = settings.JWT_SECRET.encode()
    sig = hmac.new(key, user_id.encode(), digestmod="sha256").hexdigest()[:16]
    return f"{user_id}:{sig}"


def _verify_state(state: str) -> str | None:
    try:
        user_id, sig = state.rsplit(":", 1)
    except ValueError:
        return None
    expected = hmac.new(settings.JWT_SECRET.encode(), user_id.encode(), digestmod="sha256").hexdigest()[:16]
    if not hmac.compare_digest(expected, sig):
        return None
    return user_id


# ---------------------------------------------------------------------------
# OAuth flow
# ---------------------------------------------------------------------------
def build_authorize_url(user_id: str) -> str:
    """Return the Google consent URL."""
    if not is_configured():
        raise RuntimeError("Google OAuth is not configured")

    from google_auth_oauthlib.flow import Flow

    flow = Flow.from_client_config(
        {
            "web": {
                "client_id": settings.GOOGLE_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": [settings.GOOGLE_OAUTH_REDIRECT_URI],
            }
        },
        scopes=GOOGLE_SCOPES,
    )
    flow.redirect_uri = settings.GOOGLE_OAUTH_REDIRECT_URI

    auth_url, _ = flow.authorization_url(
        access_type="offline",
        include_granted_scopes="true",
        prompt="consent",
        state=_sign_state(user_id),
    )
    return auth_url


async def exchange_code(code: str, state: str, db: AsyncSession) -> OAuthCredential:
    """Exchange the OAuth code for tokens and persist them encrypted."""
    if not is_configured():
        raise RuntimeError("Google OAuth is not configured")

    user_id = _verify_state(state)
    if user_id is None:
        raise ValueError("Invalid OAuth state parameter")

    from google_auth_oauthlib.flow import Flow

    flow = Flow.from_client_config(
        {
            "web": {
                "client_id": settings.GOOGLE_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": [settings.GOOGLE_OAUTH_REDIRECT_URI],
            }
        },
        scopes=GOOGLE_SCOPES,
        state=state,
    )
    flow.redirect_uri = settings.GOOGLE_OAUTH_REDIRECT_URI

    flow.fetch_token(code=code)
    creds = flow.credentials

    # Grab email from the id_token if present
    account_email: str | None = None
    try:
        id_info = getattr(creds, "id_token", None)
        if id_info and isinstance(id_info, str):
            import json
            import base64

            parts = id_info.split(".")
            if len(parts) >= 2:
                padded = parts[1] + "=" * (-len(parts[1]) % 4)
                payload = json.loads(base64.urlsafe_b64decode(padded))
                account_email = payload.get("email")
    except Exception:
        pass

    return await _upsert_credential(
        db=db,
        user_id=user_id,
        access_token=creds.token,
        refresh_token=creds.refresh_token,
        expires_at=creds.expiry.replace(tzinfo=None) if creds.expiry else None,
        scopes=" ".join(creds.scopes or GOOGLE_SCOPES),
        account_email=account_email,
    )


async def _upsert_credential(
    db: AsyncSession,
    user_id: str,
    access_token: str,
    refresh_token: str | None,
    expires_at: datetime | None,
    scopes: str,
    account_email: str | None,
) -> OAuthCredential:
    result = await db.execute(
        select(OAuthCredential).where(
            OAuthCredential.user_id == user_id,
            OAuthCredential.provider == PROVIDER,
        )
    )
    cred = result.scalar_one_or_none()
    encrypted_access = encrypt(access_token)
    encrypted_refresh = encrypt(refresh_token) if refresh_token else None

    if cred is None:
        cred = OAuthCredential(
            user_id=user_id,
            provider=PROVIDER,
            access_token_ciphertext=encrypted_access,
            refresh_token_ciphertext=encrypted_refresh,
            expires_at=expires_at,
            scopes=scopes,
            account_email=account_email,
        )
        db.add(cred)
    else:
        cred.access_token_ciphertext = encrypted_access
        if encrypted_refresh:
            cred.refresh_token_ciphertext = encrypted_refresh
        cred.expires_at = expires_at
        cred.scopes = scopes
        if account_email:
            cred.account_email = account_email
    await db.commit()
    await db.refresh(cred)
    return cred


async def get_credential(db: AsyncSession, user_id: str) -> OAuthCredential | None:
    result = await db.execute(
        select(OAuthCredential).where(
            OAuthCredential.user_id == user_id,
            OAuthCredential.provider == PROVIDER,
        )
    )
    return result.scalar_one_or_none()


async def delete_credential(db: AsyncSession, user_id: str) -> bool:
    cred = await get_credential(db, user_id)
    if cred is None:
        return False
    await db.delete(cred)
    await db.commit()
    return True


# ---------------------------------------------------------------------------
# Event sync
# ---------------------------------------------------------------------------
def _build_google_credentials(cred: OAuthCredential):
    """Reconstruct google.oauth2.credentials.Credentials from stored row."""
    from google.oauth2.credentials import Credentials

    return Credentials(
        token=decrypt(cred.access_token_ciphertext),
        refresh_token=decrypt(cred.refresh_token_ciphertext) if cred.refresh_token_ciphertext else None,
        token_uri="https://oauth2.googleapis.com/token",
        client_id=settings.GOOGLE_CLIENT_ID,
        client_secret=settings.GOOGLE_CLIENT_SECRET,
        scopes=(cred.scopes or "").split() if cred.scopes else GOOGLE_SCOPES,
    )


def _parse_event_datetime(event_time: dict, is_all_day: bool) -> datetime:
    if "dateTime" in event_time:
        dt_str = event_time["dateTime"]
        # Handle both with and without Z suffix
        dt = datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    if "date" in event_time:
        return datetime.fromisoformat(event_time["date"])
    raise ValueError("Event time has neither dateTime nor date")


async def sync_user_events(
    user_id: str,
    db: AsyncSession,
    days_back: int = 7,
    days_forward: int = 14,
) -> int:
    """Fetch events from Google Calendar and upsert into CalendarEvent.

    Returns the number of events synced. Refreshes the access token if needed.
    Raises RuntimeError if the user has no credential stored.
    """
    if not is_configured():
        raise RuntimeError("Google OAuth is not configured")

    cred = await get_credential(db, user_id)
    if cred is None:
        raise RuntimeError(f"User {user_id} has not connected Google Calendar")

    from googleapiclient.discovery import build

    google_creds = _build_google_credentials(cred)

    # Refresh if expired
    if google_creds.expired and google_creds.refresh_token:
        from google.auth.transport.requests import Request

        google_creds.refresh(Request())
        # Persist refreshed token
        cred.access_token_ciphertext = encrypt(google_creds.token)
        if google_creds.expiry:
            cred.expires_at = google_creds.expiry.replace(tzinfo=None)
        await db.commit()

    service = build("calendar", "v3", credentials=google_creds, cache_discovery=False)

    now = datetime.now(timezone.utc)
    time_min = (now - timedelta(days=days_back)).isoformat()
    time_max = (now + timedelta(days=days_forward)).isoformat()

    events_result = service.events().list(
        calendarId="primary",
        timeMin=time_min,
        timeMax=time_max,
        singleEvents=True,
        orderBy="startTime",
        maxResults=250,
    ).execute()

    items = events_result.get("items", [])
    count = 0
    for item in items:
        await _upsert_event(db, user_id=user_id, raw=item)
        count += 1

    cred.last_synced_at = datetime.utcnow()
    await db.commit()
    return count


async def _upsert_event(db: AsyncSession, user_id: str, raw: dict[str, Any]) -> None:
    start_raw = raw.get("start", {})
    end_raw = raw.get("end", {})
    is_all_day = "date" in start_raw
    try:
        start_time = _parse_event_datetime(start_raw, is_all_day)
        end_time = _parse_event_datetime(end_raw, is_all_day)
    except (ValueError, KeyError):
        return

    attendees = raw.get("attendees") or []
    attendee_emails = [a.get("email") for a in attendees if a.get("email")]
    organizer = (raw.get("organizer") or {}).get("email")

    meeting_url = None
    conference_data = raw.get("conferenceData", {})
    for entry in conference_data.get("entryPoints", []):
        if entry.get("entryPointType") == "video":
            meeting_url = entry.get("uri")
            break
    if not meeting_url and raw.get("hangoutLink"):
        meeting_url = raw.get("hangoutLink")

    provider_event_id = raw.get("id")
    if not provider_event_id:
        return

    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.user_id == user_id,
            CalendarEvent.provider == PROVIDER,
            CalendarEvent.provider_event_id == provider_event_id,
        )
    )
    existing = result.scalar_one_or_none()

    if existing is None:
        event = CalendarEvent(
            user_id=user_id,
            provider=PROVIDER,
            provider_event_id=provider_event_id,
            title=raw.get("summary") or "(no title)",
            description=raw.get("description"),
            start_time=start_time,
            end_time=end_time,
            is_all_day=is_all_day,
            location=raw.get("location"),
            meeting_url=meeting_url,
            attendees=attendee_emails or None,
            organizer=organizer,
            status=raw.get("status", "confirmed"),
        )
        db.add(event)
    else:
        existing.title = raw.get("summary") or existing.title
        existing.description = raw.get("description")
        existing.start_time = start_time
        existing.end_time = end_time
        existing.is_all_day = is_all_day
        existing.location = raw.get("location")
        existing.meeting_url = meeting_url
        existing.attendees = attendee_emails or None
        existing.organizer = organizer
        existing.status = raw.get("status", "confirmed")
        existing.synced_at = datetime.utcnow()


# ---------------------------------------------------------------------------
# Dev seed — create fake events for testing without GCP setup
# ---------------------------------------------------------------------------
async def dev_seed_events(db: AsyncSession, user_id: str) -> int:
    """Create a handful of realistic fake events for today + upcoming days.

    Used for testing calendar features without setting up real Google OAuth.
    Wipes any existing dev-seeded events for the user first (identified by
    provider_event_id prefix 'dev-seed-').
    """
    await db.execute(
        delete(CalendarEvent).where(
            CalendarEvent.user_id == user_id,
            CalendarEvent.provider_event_id.like("dev-seed-%"),
        )
    )

    now = datetime.utcnow().replace(minute=0, second=0, microsecond=0)
    today = now.replace(hour=0)

    fake = [
        {
            "id": "dev-seed-1",
            "title": "Morning sync with engineering",
            "description": "Weekly engineering standup",
            "start": today.replace(hour=9),
            "end": today.replace(hour=9, minute=30),
            "attendees": ["eng@example.com"],
            "meeting_url": "https://meet.google.com/abc-defg-hij",
        },
        {
            "id": "dev-seed-2",
            "title": "Design review — Daily Brief UI",
            "description": "Walk through the new Today dashboard with the design team",
            "start": today.replace(hour=11),
            "end": today.replace(hour=12),
            "attendees": ["design@example.com", "pm@example.com"],
            "meeting_url": None,
        },
        {
            "id": "dev-seed-3",
            "title": "Lunch",
            "description": None,
            "start": today.replace(hour=12, minute=30),
            "end": today.replace(hour=13, minute=30),
            "attendees": [],
            "meeting_url": None,
        },
        {
            "id": "dev-seed-4",
            "title": "1:1 with manager",
            "description": "Q2 goals check-in",
            "start": today.replace(hour=15),
            "end": today.replace(hour=15, minute=30),
            "attendees": ["manager@example.com"],
            "meeting_url": "https://zoom.us/j/1234567890",
        },
        {
            "id": "dev-seed-5",
            "title": "Focus block — Phase I implementation",
            "description": "Deep work on calendar integration",
            "start": (today + timedelta(days=1)).replace(hour=9),
            "end": (today + timedelta(days=1)).replace(hour=12),
            "attendees": [],
            "meeting_url": None,
        },
    ]

    count = 0
    for ev in fake:
        event = CalendarEvent(
            user_id=user_id,
            provider=PROVIDER,
            provider_event_id=ev["id"],
            title=ev["title"],
            description=ev["description"],
            start_time=ev["start"],
            end_time=ev["end"],
            is_all_day=False,
            attendees=ev["attendees"] or None,
            meeting_url=ev["meeting_url"],
            status="confirmed",
        )
        db.add(event)
        count += 1

    await db.commit()
    return count
