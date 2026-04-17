"""REST and WebSocket endpoints for the agentic loop."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agents.daily_brief import run_daily_brief
from app.agents.notifications import hub
from app.auth.jwt_handler import get_current_user, verify_token
from app.database import get_db
from app.models.agent_run import AgentRun
from app.models.user import User

router = APIRouter()


class RatingRequest(BaseModel):
    rating: int = Field(..., ge=1, le=5)


def _agent_run_to_dict(run: AgentRun) -> dict:
    return {
        "id": run.id,
        "agent_name": run.agent_name,
        "trigger": run.trigger,
        "status": run.status,
        "output_node_id": run.output_node_id,
        "output_payload": run.output_payload,
        "error_message": run.error_message,
        "duration_ms": run.duration_ms,
        "user_rating": run.user_rating,
        "started_at": run.started_at.isoformat(),
        "completed_at": run.completed_at.isoformat() if run.completed_at else None,
    }


@router.post("/daily-brief/run")
async def trigger_daily_brief(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Manually trigger a daily brief for the authenticated user.

    Useful for testing and for "give me a brief now" UX.
    """
    run = await run_daily_brief(user_id=user.id, db=db, trigger="manual")
    return _agent_run_to_dict(run)


@router.get("/runs")
async def list_runs(
    limit: int = 50,
    agent_name: str | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AgentRun).where(AgentRun.user_id == user.id)
    if agent_name:
        stmt = stmt.where(AgentRun.agent_name == agent_name)
    stmt = stmt.order_by(AgentRun.started_at.desc()).limit(limit)

    result = await db.execute(stmt)
    runs = result.scalars().all()
    return [_agent_run_to_dict(r) for r in runs]


@router.get("/runs/{run_id}")
async def get_run(
    run_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AgentRun).where(
            AgentRun.id == run_id,
            AgentRun.user_id == user.id,
        )
    )
    run = result.scalar_one_or_none()
    if run is None:
        raise HTTPException(status_code=404, detail="Agent run not found")
    return _agent_run_to_dict(run)


@router.post("/runs/{run_id}/rate")
async def rate_run(
    run_id: str,
    payload: RatingRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AgentRun).where(
            AgentRun.id == run_id,
            AgentRun.user_id == user.id,
        )
    )
    run = result.scalar_one_or_none()
    if run is None:
        raise HTTPException(status_code=404, detail="Agent run not found")

    run.user_rating = payload.rating
    await db.commit()
    await db.refresh(run)
    return _agent_run_to_dict(run)


@router.websocket("/notifications/ws")
async def notifications_ws(websocket: WebSocket) -> None:
    """Per-user notification channel.

    Protocol:
    1. Client connects
    2. Client sends the JWT access token as the first text frame
    3. Server validates, accepts, and begins forwarding events for that user
    4. Server sends JSON events as they occur (e.g., {"type":"brief_ready", ...})
    5. Client can send ping frames to keep alive; server ignores non-token frames
    """
    await websocket.accept()
    try:
        token = await websocket.receive_text()
        try:
            payload = verify_token(token, expected_type="access")
            user_id = payload["sub"]
        except Exception:
            await websocket.send_json({"type": "error", "message": "invalid_token"})
            await websocket.close(code=4401)
            return

        # Re-register the already-accepted connection in the hub
        # (we don't use hub.connect because it would accept again)
        async with hub._lock:  # type: ignore[attr-defined]
            hub._connections.setdefault(user_id, set()).add(websocket)  # type: ignore[attr-defined]

        await websocket.send_json({"type": "connected", "user_id": user_id})

        try:
            while True:
                # Keep the connection open; ignore inbound frames
                await websocket.receive_text()
        except WebSocketDisconnect:
            pass
        finally:
            await hub.disconnect(user_id, websocket)
    except WebSocketDisconnect:
        pass
