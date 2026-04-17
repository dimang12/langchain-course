"""REST endpoints for the Memory & Identity layer."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import get_current_user
from app.database import get_db
from app.memory.service import MemoryLayer
from app.models.user import User

router = APIRouter()


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------
class ProfileUpdate(BaseModel):
    role: str | None = None
    team: str | None = None
    responsibilities: str | None = None
    working_hours: str | None = None
    timezone: str | None = None
    communication_style: str | None = None


class OrgContextUpdate(BaseModel):
    org_name: str | None = None
    mission: str | None = None
    current_quarter: str | None = None
    quarter_goals: str | None = None
    leadership_priorities: str | None = None
    team_okrs: str | None = None


class FactCreate(BaseModel):
    fact: str = Field(..., min_length=1, max_length=2000)
    source: str = "manual"
    confidence: float = Field(0.9, ge=0.0, le=1.0)


class RecallRequest(BaseModel):
    query: str
    limit: int = Field(5, ge=1, le=20)


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------
@router.get("/profile")
async def get_profile(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = MemoryLayer(user_id=user.id, db=db)
    profile = await layer.get_profile()
    if profile is None:
        return {
            "user_id": user.id,
            "role": None,
            "team": None,
            "responsibilities": None,
            "working_hours": None,
            "timezone": "UTC",
            "communication_style": None,
        }
    return {
        "user_id": profile.user_id,
        "role": profile.role,
        "team": profile.team,
        "responsibilities": profile.responsibilities,
        "working_hours": profile.working_hours,
        "timezone": profile.timezone,
        "communication_style": profile.communication_style,
        "updated_at": profile.updated_at.isoformat(),
    }


@router.put("/profile")
async def update_profile(
    payload: ProfileUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = MemoryLayer(user_id=user.id, db=db)
    fields = {k: v for k, v in payload.model_dump().items() if v is not None}
    profile = await layer.upsert_profile(fields)
    return {
        "user_id": profile.user_id,
        "role": profile.role,
        "team": profile.team,
        "responsibilities": profile.responsibilities,
        "working_hours": profile.working_hours,
        "timezone": profile.timezone,
        "communication_style": profile.communication_style,
        "updated_at": profile.updated_at.isoformat(),
    }


# ---------------------------------------------------------------------------
# Org context
# ---------------------------------------------------------------------------
@router.get("/org")
async def get_org(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = MemoryLayer(user_id=user.id, db=db)
    org = await layer.get_org_context()
    if org is None:
        return {
            "user_id": user.id,
            "org_name": None,
            "mission": None,
            "current_quarter": None,
            "quarter_goals": None,
            "leadership_priorities": None,
            "team_okrs": None,
        }
    return {
        "id": org.id,
        "user_id": org.user_id,
        "org_name": org.org_name,
        "mission": org.mission,
        "current_quarter": org.current_quarter,
        "quarter_goals": org.quarter_goals,
        "leadership_priorities": org.leadership_priorities,
        "team_okrs": org.team_okrs,
        "updated_at": org.updated_at.isoformat(),
    }


@router.put("/org")
async def update_org(
    payload: OrgContextUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = MemoryLayer(user_id=user.id, db=db)
    fields = {k: v for k, v in payload.model_dump().items() if v is not None}
    org = await layer.upsert_org_context(fields)
    return {
        "id": org.id,
        "user_id": org.user_id,
        "org_name": org.org_name,
        "mission": org.mission,
        "current_quarter": org.current_quarter,
        "quarter_goals": org.quarter_goals,
        "leadership_priorities": org.leadership_priorities,
        "team_okrs": org.team_okrs,
        "updated_at": org.updated_at.isoformat(),
    }


# ---------------------------------------------------------------------------
# Facts (archival memory)
# ---------------------------------------------------------------------------
@router.get("/facts")
async def list_facts(
    limit: int = 100,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = MemoryLayer(user_id=user.id, db=db)
    facts = await layer.list_facts(limit=limit)
    return [
        {
            "id": f.id,
            "fact": f.fact,
            "source": f.source,
            "confidence": f.confidence,
            "access_count": f.access_count,
            "created_at": f.created_at.isoformat(),
            "last_accessed": f.last_accessed.isoformat(),
        }
        for f in facts
    ]


@router.post("/facts")
async def create_fact(
    payload: FactCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = MemoryLayer(user_id=user.id, db=db)
    fact = await layer.write_fact(
        fact=payload.fact,
        source=payload.source,
        confidence=payload.confidence,
    )
    return {
        "id": fact.id,
        "fact": fact.fact,
        "source": fact.source,
        "confidence": fact.confidence,
        "created_at": fact.created_at.isoformat(),
    }


@router.post("/facts/recall")
async def recall_facts(
    payload: RecallRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = MemoryLayer(user_id=user.id, db=db)
    facts = await layer.recall(payload.query, limit=payload.limit)
    return [
        {
            "id": f.id,
            "fact": f.fact,
            "source": f.source,
            "confidence": f.confidence,
        }
        for f in facts
    ]


@router.delete("/facts/{fact_id}")
async def delete_fact(
    fact_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    layer = MemoryLayer(user_id=user.id, db=db)
    ok = await layer.forget_fact(fact_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Fact not found")
    return {"status": "deleted", "id": fact_id}
