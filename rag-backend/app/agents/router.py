"""REST and WebSocket endpoints for the agentic loop."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from datetime import datetime

from app.agents.daily_brief import run_daily_brief
from app.agents.notifications import hub
from app.agents.prioritizer import run_prioritizer
from app.auth.jwt_handler import get_current_user, verify_token
from app.database import get_db
from app.models.agent_run import AgentRun
from app.models.todos import Todo
from app.models.user import User

router = APIRouter()


class RatingRequest(BaseModel):
    rating: int = Field(..., ge=1, le=5)


class TaskCompletionRequest(BaseModel):
    completed: bool = True


def _agent_run_to_dict(run: AgentRun) -> dict:
    return {
        "id": run.id,
        "agent_name": run.agent_name,
        "trigger": run.trigger,
        "status": run.status,
        "output_node_id": run.output_node_id,
        "output_payload": run.output_payload,
        "recommendations": run.recommendations,
        "error_message": run.error_message,
        "duration_ms": run.duration_ms,
        "user_rating": run.user_rating,
        "task_completions": run.task_completions,
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


@router.post("/prioritizer/run")
async def trigger_prioritizer(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Manually run the Prioritizer agent — produces Top-3 with evidence refs."""
    run = await run_prioritizer(user_id=user.id, db=db, trigger="manual")
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


@router.patch("/runs/{run_id}/tasks/{task_index}")
async def toggle_task_completion(
    run_id: str,
    task_index: int,
    payload: TaskCompletionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Toggle completion of a specific priority in a brief or prioritizer run.

    For Prioritizer runs where the priority maps to a `Todo` (via `todo_id`),
    we also update `Todo.completed_at` so checking a priority finishes the
    underlying task. AgentRun.task_completions stays in sync either way.
    """
    result = await db.execute(
        select(AgentRun).where(
            AgentRun.id == run_id,
            AgentRun.user_id == user.id,
        )
    )
    run = result.scalar_one_or_none()
    if run is None:
        raise HTTPException(status_code=404, detail="Agent run not found")

    payload_dict = run.output_payload or {}
    # Prioritizer format: structured priorities. Legacy daily_brief: flat list.
    structured_priorities = payload_dict.get("priorities") or []
    legacy_priorities = payload_dict.get("top_priorities") or []
    total = len(structured_priorities) if structured_priorities else len(legacy_priorities)
    if task_index < 0 or task_index >= total:
        raise HTTPException(status_code=400, detail="Invalid task index")

    completions = list(run.task_completions or [False] * total)
    while len(completions) < total:
        completions.append(False)
    completions[task_index] = payload.completed
    run.task_completions = completions

    # Cascade to the underlying Todo when the priority references one.
    if structured_priorities:
        item = structured_priorities[task_index]
        todo_id = item.get("todo_id") if isinstance(item, dict) else None
        if todo_id:
            todo = await db.get(Todo, todo_id)
            if todo is not None and todo.user_id == user.id:
                todo.completed_at = datetime.utcnow() if payload.completed else None

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
