"""Structured entity extraction pipeline.

Takes free-form text (documents, chat transcripts, meeting notes) and extracts
structured entities — Goals, Decisions, FollowUps, People — using the LLM with
JSON mode. Deduplicates against existing rows by fuzzy title matching.
"""

from __future__ import annotations

import json
import logging
from datetime import date, datetime
from typing import Any

from openai import AsyncOpenAI
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.knowledge import Decision, FollowUp, Goal, Person

logger = logging.getLogger(__name__)

EXTRACTION_SYSTEM_PROMPT = """You are an extraction engine. Given a piece of text, extract
any structured entities you can find. Return VALID JSON matching this schema EXACTLY:

{
  "goals": [
    {"title": "string", "description": "string or null", "level": "org|team|personal", "priority": 1-5, "due_date": "YYYY-MM-DD or null"}
  ],
  "decisions": [
    {"title": "string", "rationale": "string or null", "decided_at": "YYYY-MM-DD or null"}
  ],
  "follow_ups": [
    {"description": "string", "owner": "string or null", "due_date": "YYYY-MM-DD or null"}
  ],
  "people": [
    {"name": "string", "email": "string or null", "role": "string or null", "relationship": "manager|report|peer|external|null"}
  ]
}

Rules:
- Only extract entities that are CLEARLY stated or strongly implied in the text
- Do NOT invent or hallucinate entities
- If no entities of a type exist, return an empty array for that type
- For goals, distinguish org/team/personal level based on context
- For priority, 1=critical, 3=normal, 5=nice-to-have
- For people, only include people mentioned by name with some identifying context
- Be conservative — skip ambiguous or vague references
"""


async def extract_structured(
    content: str,
    user_id: str,
    db: AsyncSession,
    source: str = "extracted",
    source_ref: str | None = None,
) -> dict[str, int]:
    """Extract entities from text and upsert into knowledge graph.

    Returns counts of newly created entities per type.
    """
    if not content or len(content.strip()) < 20:
        return {"goals": 0, "decisions": 0, "follow_ups": 0, "people": 0}

    client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

    try:
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": EXTRACTION_SYSTEM_PROMPT},
                {"role": "user", "content": content[:8000]},
            ],
            response_format={"type": "json_object"},
            temperature=0.1,
            max_tokens=2000,
        )
        raw = response.choices[0].message.content or "{}"
        data = json.loads(raw)
    except Exception as exc:
        logger.warning("Extraction LLM call failed: %s", exc)
        return {"goals": 0, "decisions": 0, "follow_ups": 0, "people": 0}

    counts = {"goals": 0, "decisions": 0, "follow_ups": 0, "people": 0}

    for g in data.get("goals") or []:
        if not g.get("title"):
            continue
        if await _goal_exists(db, user_id, g["title"]):
            continue
        goal = Goal(
            user_id=user_id,
            title=g["title"],
            description=g.get("description"),
            level=g.get("level", "personal"),
            priority=_clamp(g.get("priority", 3), 1, 5),
            due_date=_parse_date(g.get("due_date")),
            source=source,
            source_ref=source_ref,
        )
        db.add(goal)
        counts["goals"] += 1

    for d in data.get("decisions") or []:
        if not d.get("title"):
            continue
        if await _decision_exists(db, user_id, d["title"]):
            continue
        decision = Decision(
            user_id=user_id,
            title=d["title"],
            rationale=d.get("rationale"),
            decided_at=_parse_date(d.get("decided_at")),
            source=source,
            source_ref=source_ref,
        )
        db.add(decision)
        counts["decisions"] += 1

    for f in data.get("follow_ups") or []:
        if not f.get("description"):
            continue
        if await _followup_exists(db, user_id, f["description"]):
            continue
        followup = FollowUp(
            user_id=user_id,
            description=f["description"],
            owner=f.get("owner"),
            due_date=_parse_date(f.get("due_date")),
            source=source,
            source_ref=source_ref,
        )
        db.add(followup)
        counts["follow_ups"] += 1

    for p in data.get("people") or []:
        if not p.get("name"):
            continue
        if await _person_exists(db, user_id, p["name"]):
            continue
        person = Person(
            user_id=user_id,
            name=p["name"],
            email=p.get("email"),
            role=p.get("role"),
            relationship=p.get("relationship"),
            source=source,
        )
        db.add(person)
        counts["people"] += 1

    await db.commit()
    return counts


# ---------------------------------------------------------------------------
# Deduplication helpers — fuzzy by lowercased title/description
# ---------------------------------------------------------------------------
async def _goal_exists(db: AsyncSession, user_id: str, title: str) -> bool:
    result = await db.execute(
        select(Goal).where(
            Goal.user_id == user_id,
            func.lower(Goal.title) == title.strip().lower(),
        )
    )
    return result.scalar_one_or_none() is not None


async def _decision_exists(db: AsyncSession, user_id: str, title: str) -> bool:
    result = await db.execute(
        select(Decision).where(
            Decision.user_id == user_id,
            func.lower(Decision.title) == title.strip().lower(),
        )
    )
    return result.scalar_one_or_none() is not None


async def _followup_exists(db: AsyncSession, user_id: str, desc: str) -> bool:
    result = await db.execute(
        select(FollowUp).where(
            FollowUp.user_id == user_id,
            func.lower(FollowUp.description) == desc.strip().lower(),
        )
    )
    return result.scalar_one_or_none() is not None


async def _person_exists(db: AsyncSession, user_id: str, name: str) -> bool:
    result = await db.execute(
        select(Person).where(
            Person.user_id == user_id,
            func.lower(Person.name) == name.strip().lower(),
        )
    )
    return result.scalar_one_or_none() is not None


def _parse_date(val: Any) -> date | None:
    if val is None:
        return None
    try:
        return date.fromisoformat(str(val))
    except (ValueError, TypeError):
        return None


def _clamp(val: Any, lo: int, hi: int) -> int:
    try:
        return max(lo, min(hi, int(val)))
    except (TypeError, ValueError):
        return 3
