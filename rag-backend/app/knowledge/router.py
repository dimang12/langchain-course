"""REST endpoints for the Knowledge Graph (Lite)."""

from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import get_current_user
from app.database import get_db
from app.knowledge.extractor import extract_structured
from app.models.knowledge import Decision, FollowUp, Goal, Person
from app.models.user import User

router = APIRouter()


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class GoalCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=500)
    description: str | None = None
    level: str = "personal"
    priority: int = Field(3, ge=1, le=5)
    due_date: date | None = None
    parent_id: str | None = None


class GoalUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    status: str | None = None
    priority: int | None = Field(None, ge=1, le=5)
    due_date: date | None = None


class FollowUpCreate(BaseModel):
    description: str = Field(..., min_length=1, max_length=1000)
    owner: str | None = None
    due_date: date | None = None
    related_goal_id: str | None = None


class ExtractionRequest(BaseModel):
    content: str = Field(..., min_length=20, max_length=20000)
    source_ref: str | None = None


# ---------------------------------------------------------------------------
# Goals
# ---------------------------------------------------------------------------
def _goal_dict(g: Goal) -> dict:
    return {
        "id": g.id, "parent_id": g.parent_id, "level": g.level,
        "title": g.title, "description": g.description,
        "status": g.status, "priority": g.priority,
        "due_date": g.due_date.isoformat() if g.due_date else None,
        "source": g.source, "source_ref": g.source_ref,
        "created_at": g.created_at.isoformat(),
    }


@router.get("/goals")
async def list_goals(
    status: str | None = None,
    level: str | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Goal).where(Goal.user_id == user.id)
    if status:
        stmt = stmt.where(Goal.status == status)
    if level:
        stmt = stmt.where(Goal.level == level)
    stmt = stmt.order_by(Goal.priority, Goal.created_at.desc())

    result = await db.execute(stmt)
    return [_goal_dict(g) for g in result.scalars().all()]


@router.post("/goals")
async def create_goal(
    payload: GoalCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    goal = Goal(
        user_id=user.id,
        parent_id=payload.parent_id,
        title=payload.title,
        description=payload.description,
        level=payload.level,
        priority=payload.priority,
        due_date=payload.due_date,
        source="manual",
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)
    return _goal_dict(goal)


@router.put("/goals/{goal_id}")
async def update_goal(
    goal_id: str,
    payload: GoalUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Goal).where(Goal.id == goal_id, Goal.user_id == user.id)
    )
    goal = result.scalar_one_or_none()
    if goal is None:
        raise HTTPException(status_code=404, detail="Goal not found")

    for field in ("title", "description", "status", "priority", "due_date"):
        val = getattr(payload, field)
        if val is not None:
            setattr(goal, field, val)

    await db.commit()
    await db.refresh(goal)
    return _goal_dict(goal)


@router.delete("/goals/{goal_id}")
async def delete_goal(
    goal_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Goal).where(Goal.id == goal_id, Goal.user_id == user.id)
    )
    goal = result.scalar_one_or_none()
    if goal is None:
        raise HTTPException(status_code=404, detail="Goal not found")
    await db.delete(goal)
    await db.commit()
    return {"status": "deleted"}


# ---------------------------------------------------------------------------
# FollowUps
# ---------------------------------------------------------------------------
def _followup_dict(f: FollowUp) -> dict:
    return {
        "id": f.id, "description": f.description,
        "owner": f.owner, "status": f.status,
        "due_date": f.due_date.isoformat() if f.due_date else None,
        "related_goal_id": f.related_goal_id,
        "source": f.source, "source_ref": f.source_ref,
        "created_at": f.created_at.isoformat(),
    }


@router.get("/followups")
async def list_followups(
    status: str | None = "open",
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(FollowUp).where(FollowUp.user_id == user.id)
    if status:
        stmt = stmt.where(FollowUp.status == status)
    stmt = stmt.order_by(FollowUp.due_date.asc().nullslast(), FollowUp.created_at.desc())

    result = await db.execute(stmt)
    return [_followup_dict(f) for f in result.scalars().all()]


@router.post("/followups")
async def create_followup(
    payload: FollowUpCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    followup = FollowUp(
        user_id=user.id,
        description=payload.description,
        owner=payload.owner,
        due_date=payload.due_date,
        related_goal_id=payload.related_goal_id,
        source="manual",
    )
    db.add(followup)
    await db.commit()
    await db.refresh(followup)
    return _followup_dict(followup)


@router.put("/followups/{followup_id}/done")
async def mark_followup_done(
    followup_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(FollowUp).where(FollowUp.id == followup_id, FollowUp.user_id == user.id)
    )
    followup = result.scalar_one_or_none()
    if followup is None:
        raise HTTPException(status_code=404, detail="Follow-up not found")
    followup.status = "done"
    await db.commit()
    await db.refresh(followup)
    return _followup_dict(followup)


# ---------------------------------------------------------------------------
# Decisions
# ---------------------------------------------------------------------------
@router.get("/decisions")
async def list_decisions(
    limit: int = 20,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Decision)
        .where(Decision.user_id == user.id)
        .order_by(Decision.created_at.desc())
        .limit(limit)
    )
    return [
        {
            "id": d.id, "title": d.title, "rationale": d.rationale,
            "decided_at": d.decided_at.isoformat() if d.decided_at else None,
            "related_goal_ids": d.related_goal_ids,
            "source": d.source, "source_ref": d.source_ref,
            "created_at": d.created_at.isoformat(),
        }
        for d in result.scalars().all()
    ]


# ---------------------------------------------------------------------------
# People
# ---------------------------------------------------------------------------
@router.get("/people")
async def list_people(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Person)
        .where(Person.user_id == user.id)
        .order_by(Person.name)
    )
    return [
        {
            "id": p.id, "name": p.name, "email": p.email,
            "role": p.role, "relationship": p.relationship,
            "notes": p.notes,
            "created_at": p.created_at.isoformat(),
        }
        for p in result.scalars().all()
    ]


# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------
@router.post("/extract")
async def run_extraction(
    payload: ExtractionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    counts = await extract_structured(
        content=payload.content,
        user_id=user.id,
        db=db,
        source="extracted",
        source_ref=payload.source_ref,
    )
    return {"status": "extracted", "counts": counts}
