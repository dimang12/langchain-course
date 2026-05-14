"""REST endpoints for the Meetings module."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import get_current_user
from app.database import get_db
from app.meetings.service import (
    create_meeting,
    finalize_meeting,
    serialize_meeting,
)
from app.models.meetings import Meeting
from app.models.user import User
from app.models.workspace import TreeNode

router = APIRouter()


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------
class CreateMeetingRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    scheduled_at: datetime | None = None
    attendees: list[dict] | None = None
    calendar_event_id: str | None = None


class UpdateMeetingRequest(BaseModel):
    title: str | None = None
    scheduled_at: datetime | None = None
    attendees: list[dict] | None = None


class FromTextRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    raw_text: str = Field(..., min_length=1)
    scheduled_at: datetime | None = None
    auto_finalize: bool = True


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
async def _get_meeting_or_404(
    meeting_id: str, user_id: str, db: AsyncSession
) -> Meeting:
    meeting = await db.get(Meeting, meeting_id)
    if meeting is None or meeting.user_id != user_id:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return meeting


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@router.post("")
async def create(
    req: CreateMeetingRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meeting = await create_meeting(
        db,
        user_id=user.id,
        title=req.title,
        scheduled_at=req.scheduled_at,
        attendees=req.attendees,
        calendar_event_id=req.calendar_event_id,
    )
    return serialize_meeting(meeting, include_content=False)


@router.get("")
async def list_meetings(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    status: str | None = Query(None, description="Filter: 'draft' | 'finalized'"),
    limit: int = Query(50, ge=1, le=200),
):
    stmt = select(Meeting).where(Meeting.user_id == user.id)
    if status:
        stmt = stmt.where(Meeting.status == status)
    stmt = stmt.order_by(desc(Meeting.scheduled_at), desc(Meeting.created_at)).limit(limit)
    result = await db.execute(stmt)
    meetings = result.scalars().all()
    return [serialize_meeting(m, include_content=False) for m in meetings]


@router.get("/{meeting_id}")
async def get_meeting(
    meeting_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meeting = await _get_meeting_or_404(meeting_id, user.id, db)
    doc_node = (
        await db.get(TreeNode, meeting.tree_node_id) if meeting.tree_node_id else None
    )
    payload = serialize_meeting(meeting, include_content=False)
    payload["content"] = doc_node.content if doc_node else None
    payload["doc_name"] = doc_node.name if doc_node else None
    return payload


@router.patch("/{meeting_id}")
async def update_meeting(
    meeting_id: str,
    req: UpdateMeetingRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meeting = await _get_meeting_or_404(meeting_id, user.id, db)
    if req.title is not None:
        meeting.title = req.title
    if req.scheduled_at is not None:
        meeting.scheduled_at = req.scheduled_at
    if req.attendees is not None:
        meeting.attendees = req.attendees
    await db.commit()
    await db.refresh(meeting)
    return serialize_meeting(meeting, include_content=False)


@router.delete("/{meeting_id}")
async def delete_meeting(
    meeting_id: str,
    purge_doc: bool = Query(False, description="Also delete the workspace doc"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meeting = await _get_meeting_or_404(meeting_id, user.id, db)
    if purge_doc and meeting.tree_node_id:
        doc = await db.get(TreeNode, meeting.tree_node_id)
        if doc is not None and doc.user_id == user.id:
            await db.delete(doc)
    await db.delete(meeting)
    await db.commit()
    return {"ok": True}


@router.post("/{meeting_id}/finalize")
async def finalize(
    meeting_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meeting = await _get_meeting_or_404(meeting_id, user.id, db)
    try:
        result = await finalize_meeting(db, user_id=user.id, meeting=meeting)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return result


@router.post("/from-text")
async def create_from_text(
    req: FromTextRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    meeting = await create_meeting(
        db,
        user_id=user.id,
        title=req.title,
        scheduled_at=req.scheduled_at,
        raw_text=req.raw_text,
    )
    finalize_result: dict | None = None
    if req.auto_finalize:
        try:
            finalize_result = await finalize_meeting(db, user_id=user.id, meeting=meeting)
        except ValueError:
            finalize_result = None
    payload = serialize_meeting(meeting, include_content=False)
    payload["finalize"] = finalize_result
    return payload
