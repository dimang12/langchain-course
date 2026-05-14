"""K1 Prioritizer Agent.

Replaces the daily brief with evidence-cited Top-3 priorities.

For each open Todo, the LLM scores on:
- Goal alignment (Todo.goal_id → Goal.priority)
- Deadline pressure (Todo.due_date proximity)
- Calendar fit (does the day have a free block ≥ estimated_minutes?)
- Dependency / unblocking signal

Output: exactly 3 ranked priorities, each with a one-sentence rationale and a
list of evidence refs (e.g. ["goal:abc", "meeting:def", "followup:xyz"]) so the
UI can render clickable evidence chips.

Side effects:
- Sets `Todo.is_today_priority = True` for the 3 picked; clears it on others.
- Persists structured `recommendations` JSON on the AgentRun row.
- Writes a markdown brief into the workspace under `Daily Briefs/YYYY-MM-DD.md`.
"""

from __future__ import annotations

import json
import logging
import time
from datetime import date, datetime, time as dtime, timedelta, timezone
from typing import Any

from openai import AsyncOpenAI
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agents.notifications import hub
from app.config import settings
from app.memory.service import MemoryLayer
from app.models.agent_run import AgentRun
from app.models.connectors import CalendarEvent
from app.models.identity import UserProfile
from app.models.knowledge import FollowUp, Goal
from app.models.meetings import Meeting
from app.models.todos import Todo
from app.models.workspace import TreeNode

logger = logging.getLogger(__name__)

PRIORITIZER_SYSTEM_PROMPT = """You are a focused AI coworker selecting the user's
TOP 3 priorities for today. You ground every choice in evidence the user can verify.

OUTPUT — strict JSON matching this schema, no extra fields:
{
  "priorities": [
    {
      "todo_id": "string or null",
      "title": "string (the task)",
      "rank": 1|2|3,
      "rationale": "one sentence — WHY this is top-3 today",
      "evidence": ["goal:<id>", "followup:<id>", "meeting:<id>", "calendar:<event_id>"],
      "estimated_minutes": null or integer,
      "suggested_block": "HH:MM-HH:MM or null"
    }
  ],
  "deferred": ["one-sentence reasons why a tempting item was NOT picked"],
  "context_snapshot": "2-3 sentences on the current state of work",
  "one_insight": "one non-obvious observation worth acting on"
}

HARD RULES:
- Exactly 3 priorities, ranked 1-3. No more, no fewer.
- Every priority MUST have at least one evidence ref. If you cannot cite, do not pick it.
- Evidence refs must use IDs from the provided context — never invent IDs.
- `todo_id` MUST be one of the provided Open Todo IDs (or null if the priority is from a goal/followup without a backing todo).
- `suggested_block` must come from the Free Time Blocks list. Do not invent times.
- If `estimated_minutes` is set on a todo, prefer free blocks ≥ that duration.
- Skip [DONE] items from yesterday — they are finished.
- Be terse. One sentence per rationale. No filler.
- The `one_insight` should feel earned: a pattern across todos / goals / meetings / calendar.
"""


# ---------------------------------------------------------------------------
# Context loading
# ---------------------------------------------------------------------------
async def _load_open_todos(db: AsyncSession, user_id: str) -> list[Todo]:
    result = await db.execute(
        select(Todo)
        .where(Todo.user_id == user_id, Todo.completed_at.is_(None))
        .order_by(Todo.due_date.asc().nullslast(), Todo.priority)
        .limit(40)
    )
    return list(result.scalars().all())


async def _load_active_goals(db: AsyncSession, user_id: str) -> list[Goal]:
    result = await db.execute(
        select(Goal)
        .where(Goal.user_id == user_id, Goal.status == "active")
        .order_by(Goal.priority)
        .limit(20)
    )
    return list(result.scalars().all())


async def _load_open_followups(db: AsyncSession, user_id: str) -> list[FollowUp]:
    result = await db.execute(
        select(FollowUp)
        .where(FollowUp.user_id == user_id, FollowUp.status == "open")
        .order_by(FollowUp.due_date.asc().nullslast())
        .limit(15)
    )
    return list(result.scalars().all())


async def _load_todays_events(db: AsyncSession, user_id: str) -> list[CalendarEvent]:
    now = datetime.utcnow()
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)
    result = await db.execute(
        select(CalendarEvent)
        .where(
            CalendarEvent.user_id == user_id,
            CalendarEvent.start_time >= day_start,
            CalendarEvent.start_time < day_end,
        )
        .order_by(CalendarEvent.start_time)
    )
    return list(result.scalars().all())


async def _load_recent_meetings(db: AsyncSession, user_id: str) -> list[Meeting]:
    cutoff = datetime.utcnow() - timedelta(hours=36)
    result = await db.execute(
        select(Meeting)
        .where(
            Meeting.user_id == user_id,
            Meeting.finalized_at.isnot(None),
            Meeting.finalized_at >= cutoff,
        )
        .order_by(Meeting.finalized_at.desc())
        .limit(8)
    )
    return list(result.scalars().all())


async def _load_prior_run(db: AsyncSession, user_id: str, current_run_id: str) -> AgentRun | None:
    result = await db.execute(
        select(AgentRun)
        .where(
            AgentRun.user_id == user_id,
            AgentRun.agent_name == "prioritizer",
            AgentRun.status == "success",
            AgentRun.id != current_run_id,
        )
        .order_by(AgentRun.started_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


# ---------------------------------------------------------------------------
# Free-block computation
# ---------------------------------------------------------------------------
def _compute_free_blocks(
    events: list[CalendarEvent],
    work_start: dtime,
    work_end: dtime,
    today: date,
    min_minutes: int = 30,
) -> list[tuple[datetime, datetime]]:
    """Return list of (start, end) datetimes for free blocks within working hours."""
    day_start = datetime.combine(today, work_start)
    day_end = datetime.combine(today, work_end)
    busy = sorted(
        [(e.start_time, e.end_time) for e in events if not e.is_all_day],
        key=lambda x: x[0],
    )
    free: list[tuple[datetime, datetime]] = []
    cursor = day_start
    for start, end in busy:
        s = max(start, day_start)
        e = min(end, day_end)
        if s > cursor:
            free.append((cursor, s))
        if e > cursor:
            cursor = e
    if cursor < day_end:
        free.append((cursor, day_end))
    return [(s, e) for (s, e) in free if (e - s).total_seconds() / 60 >= min_minutes]


def _parse_working_hours(profile: UserProfile | None) -> tuple[dtime, dtime]:
    default = (dtime(9, 0), dtime(18, 0))
    if profile is None or not profile.working_hours:
        return default
    raw = profile.working_hours.strip()
    if "-" not in raw:
        return default
    a, b = raw.split("-", 1)
    try:
        h1, m1 = a.strip().split(":")
        h2, m2 = b.strip().split(":")
        return dtime(int(h1), int(m1)), dtime(int(h2), int(m2))
    except (ValueError, IndexError):
        return default


def _fmt_block(b: tuple[datetime, datetime]) -> str:
    return f"{b[0].strftime('%H:%M')}-{b[1].strftime('%H:%M')}"


# ---------------------------------------------------------------------------
# Markdown rendering
# ---------------------------------------------------------------------------
def _render_brief_markdown(date_str: str, payload: dict) -> str:
    lines: list[str] = [f"# Daily Brief — {date_str}", ""]
    priorities = payload.get("priorities") or []
    if priorities:
        lines.append("## Top Priorities")
        for p in priorities:
            rank = p.get("rank", "?")
            title = p.get("title", "(no title)")
            block = p.get("suggested_block")
            line = f"{rank}. **{title}**"
            if block:
                line += f"  _({block})_"
            lines.append(line)
            rationale = p.get("rationale")
            if rationale:
                lines.append(f"   _{rationale}_")
            evidence = p.get("evidence") or []
            if evidence:
                lines.append(f"   <sub>evidence: {' · '.join(evidence)}</sub>")
            lines.append("")
    snapshot = payload.get("context_snapshot")
    if snapshot:
        lines.extend(["## Context", snapshot, ""])
    insight = payload.get("one_insight")
    if insight:
        lines.extend(["## One Insight", f"> {insight}", ""])
    deferred = payload.get("deferred") or []
    if deferred:
        lines.append("## Deferred (and why)")
        for d in deferred:
            lines.append(f"- {d}")
        lines.append("")
    lines.append("---")
    lines.append(f"*Prioritizer · {datetime.now(timezone.utc).isoformat(timespec='seconds')}*")
    return "\n".join(lines)


async def _find_or_create_folder(db: AsyncSession, user_id: str, name: str) -> TreeNode:
    result = await db.execute(
        select(TreeNode).where(
            TreeNode.user_id == user_id,
            TreeNode.node_type == "folder",
            TreeNode.parent_id.is_(None),
            TreeNode.name == name,
        )
    )
    folder = result.scalar_one_or_none()
    if folder is not None:
        return folder
    folder = TreeNode(user_id=user_id, name=name, node_type="folder")
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    return folder


# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------
async def run_prioritizer(
    user_id: str,
    db: AsyncSession,
    trigger: str = "manual",
) -> AgentRun:
    """Execute the Prioritizer for one user."""
    started = time.monotonic()
    run = AgentRun(
        user_id=user_id,
        agent_name="prioritizer",
        trigger=trigger,
        status="running",
        started_at=datetime.utcnow(),
    )
    db.add(run)
    await db.commit()
    await db.refresh(run)

    try:
        memory = MemoryLayer(user_id=user_id, db=db)
        profile = await memory.get_profile()
        core_block = await memory.build_core_block()

        open_todos = await _load_open_todos(db, user_id)
        active_goals = await _load_active_goals(db, user_id)
        open_followups = await _load_open_followups(db, user_id)
        todays_events = await _load_todays_events(db, user_id)
        recent_meetings = await _load_recent_meetings(db, user_id)
        prior_run = await _load_prior_run(db, user_id, run.id)

        today = datetime.utcnow().date()
        ws, we = _parse_working_hours(profile)
        free_blocks = _compute_free_blocks(todays_events, ws, we, today)

        # Build LLM-readable context with explicit IDs so evidence refs resolve.
        todos_lines = [
            f"- id={t.id} | {t.title}"
            + (f" | goal={t.goal_id}" if t.goal_id else "")
            + (f" | due={t.due_date.isoformat()}" if t.due_date else "")
            + (f" | est={t.estimated_minutes}m" if t.estimated_minutes else "")
            + f" | priority={t.priority}"
            for t in open_todos
        ] or ["- (no open todos)"]

        goals_lines = [
            f"- id={g.id} | [{g.level}/P{g.priority}] {g.title}"
            + (f" | due={g.due_date.isoformat()}" if g.due_date else "")
            for g in active_goals
        ] or ["- (no active goals)"]

        followups_lines = [
            f"- id={f.id} | {f.description}"
            + (f" | owner={f.owner}" if f.owner else "")
            + (f" | due={f.due_date.isoformat()}" if f.due_date else "")
            for f in open_followups
        ] or ["- (no open follow-ups)"]

        events_lines = [
            f"- id={e.id} | {e.start_time.strftime('%H:%M')}-{e.end_time.strftime('%H:%M')} | {e.title}"
            for e in todays_events
        ] or ["- (no meetings today)"]

        meetings_lines = [
            f"- id={m.id} | {m.title} (decisions={m.decisions_extracted}, action_items={m.follow_ups_extracted})"
            for m in recent_meetings
        ] or ["- (no recently finalized meetings)"]

        free_lines = [f"- {_fmt_block(b)} ({int((b[1]-b[0]).total_seconds()/60)}m)" for b in free_blocks] or [
            "- (no free blocks within working hours)"
        ]

        prior_lines: list[str] = []
        if prior_run and prior_run.output_payload:
            prior_priorities = prior_run.output_payload.get("priorities") or []
            completions = prior_run.task_completions or [False] * len(prior_priorities)
            for i, p in enumerate(prior_priorities):
                done = completions[i] if i < len(completions) else False
                tag = "DONE" if done else "NOT DONE"
                title = p.get("title", "(no title)") if isinstance(p, dict) else str(p)
                prior_lines.append(f"- [{tag}] {title}")

        prompt_parts: list[str] = [
            f"Today is {today.isoformat()}. Working hours: {ws.strftime('%H:%M')}-{we.strftime('%H:%M')}.",
            "",
            core_block or "## User Profile\n(not configured)",
            "",
            "## Open Todos",
            *todos_lines,
            "",
            "## Active Goals",
            *goals_lines,
            "",
            "## Open Follow-Ups",
            *followups_lines,
            "",
            "## Today's Calendar",
            *events_lines,
            "",
            "## Free Time Blocks (within working hours)",
            *free_lines,
            "",
            "## Recently Finalized Meetings (last 36h)",
            *meetings_lines,
        ]
        if prior_lines:
            prompt_parts.extend([
                "",
                "## Yesterday's Priorities (do NOT repeat [DONE] items)",
                *prior_lines,
            ])

        prompt_parts.append("")
        prompt_parts.append("Pick exactly 3 priorities for today. Output JSON matching the schema.")
        user_prompt = "\n".join(prompt_parts)

        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": PRIORITIZER_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
            max_tokens=1500,
        )
        raw = response.choices[0].message.content or "{}"
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = {
                "priorities": [],
                "deferred": [],
                "context_snapshot": raw[:500],
                "one_insight": "",
            }

        priorities = payload.get("priorities") or []
        # Persist is_today_priority on Todos.
        priority_todo_ids = {p.get("todo_id") for p in priorities if p.get("todo_id")}
        for t in open_todos:
            new_val = t.id in priority_todo_ids
            if t.is_today_priority != new_val:
                t.is_today_priority = new_val

        # Build recommendations array for the UI.
        recommendations = [
            {
                "type": "priority",
                "todo_id": p.get("todo_id"),
                "title": p.get("title"),
                "rank": p.get("rank"),
                "rationale": p.get("rationale"),
                "evidence": p.get("evidence") or [],
                "estimated_minutes": p.get("estimated_minutes"),
                "suggested_block": p.get("suggested_block"),
            }
            for p in priorities
        ]

        today_iso = today.isoformat()
        markdown = _render_brief_markdown(today_iso, payload)
        folder = await _find_or_create_folder(db, user_id=user_id, name="Daily Briefs")
        filename = f"{today_iso}.md"
        existing_result = await db.execute(
            select(TreeNode).where(
                TreeNode.user_id == user_id,
                TreeNode.parent_id == folder.id,
                TreeNode.name == filename,
            )
        )
        existing = existing_result.scalar_one_or_none()
        if existing is not None:
            existing.content = markdown
            brief_node = existing
        else:
            brief_node = TreeNode(
                user_id=user_id,
                parent_id=folder.id,
                name=filename,
                node_type="file",
                file_type="md",
                content=markdown,
            )
            db.add(brief_node)

        run.status = "success"
        run.output_payload = payload
        run.recommendations = recommendations
        run.output_node_id = brief_node.id if brief_node.id else None
        run.duration_ms = int((time.monotonic() - started) * 1000)
        run.completed_at = datetime.utcnow()
        # Reset task_completions length to match new priorities
        run.task_completions = [False] * len(priorities)
        await db.commit()
        await db.refresh(run)

        try:
            await hub.publish(
                user_id,
                {
                    "type": "prioritizer_ready",
                    "run_id": run.id,
                    "priorities_count": len(priorities),
                },
            )
        except Exception as exc:  # noqa: BLE001
            logger.debug("notification publish failed: %s", exc)

        return run

    except Exception as exc:  # noqa: BLE001
        logger.exception("prioritizer failed for user %s: %s", user_id, exc)
        run.status = "failed"
        run.error_message = str(exc)[:1000]
        run.completed_at = datetime.utcnow()
        run.duration_ms = int((time.monotonic() - started) * 1000)
        await db.commit()
        await db.refresh(run)
        return run
