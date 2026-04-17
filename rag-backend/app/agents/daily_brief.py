"""Daily Focus Brief agent.

Generates a personalized morning brief for a user, grounded in:
- Their UserProfile (role, responsibilities, working hours, comm style)
- Their OrgContext (quarter goals, leadership priorities, OKRs)
- Their archival MemoryFacts (recent + semantically relevant)
- Their recent workspace files
- Yesterday's brief (if present), for continuity

Output: a structured markdown document written to the user's workspace
under `Daily Briefs/YYYY-MM-DD.md` as a TreeNode. Notification is pushed
via the NotificationHub to any connected Flutter client.
"""

from __future__ import annotations

import json
import time
from datetime import datetime, timedelta, timezone
from typing import Any

from openai import AsyncOpenAI
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agents.notifications import hub
from app.config import settings
from app.memory.service import MemoryLayer
from app.models.agent_run import AgentRun
from app.models.connectors import CalendarEvent
from app.models.knowledge import FollowUp, Goal
from app.models.workspace import TreeNode


DAILY_BRIEF_SYSTEM_PROMPT = """You are the user's AI coworker.
Generate a focused "Daily Brief" for them — the kind a thoughtful colleague
would send at 8am, grounded in what matters most.

Your output MUST be valid JSON matching this schema:
{
  "top_priorities": ["string", "string", "string"],
  "context_snapshot": "string (2-3 sentences summarizing the current state of their work)",
  "follow_ups": ["string"],
  "suggested_plan": "string (markdown — a concrete plan for the day that INCLUDES specific calendar events by name and time)",
  "one_insight": "string (one non-obvious observation worth acting on)"
}

Rules:
- Top priorities: EXACTLY 3 items, derived from quarter goals, open work, AND today's meetings
- **suggested_plan MUST explicitly name every meeting from "Today's Calendar" with its time**
  e.g., "9:00 — Morning sync with engineering, then 2 hours of focus work before the 11:00 Design review"
- Ground every claim in the provided profile, org context, memories, calendar, or files
- Do NOT fabricate meetings, deadlines, or facts not in the context
- If today's calendar is empty, say "no meetings scheduled" — don't invent any
- Be terse. No filler. No "Good morning!" boilerplate
- The one_insight should feel earned — a non-obvious pattern across the context
"""


async def _load_todays_events(db: AsyncSession, user_id: str) -> list[dict[str, Any]]:
    """Pull calendar events happening today (UTC) for brief context."""
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
    events = result.scalars().all()
    return [
        {
            "title": e.title,
            "start": e.start_time.strftime("%H:%M"),
            "end": e.end_time.strftime("%H:%M"),
            "attendees": e.attendees or [],
            "meeting_url": e.meeting_url,
            "location": e.location,
        }
        for e in events
    ]


async def _load_recent_files(db: AsyncSession, user_id: str, limit: int = 15) -> list[dict[str, Any]]:
    result = await db.execute(
        select(TreeNode)
        .where(
            TreeNode.user_id == user_id,
            TreeNode.node_type == "file",
        )
        .order_by(TreeNode.updated_at.desc())
        .limit(limit)
    )
    nodes = result.scalars().all()
    return [
        {
            "name": n.name,
            "file_type": n.file_type,
            "updated_at": n.updated_at.isoformat(),
            "preview": (n.content or "")[:400],
        }
        for n in nodes
    ]


async def _find_or_create_folder(db: AsyncSession, user_id: str, folder_name: str) -> TreeNode:
    result = await db.execute(
        select(TreeNode).where(
            TreeNode.user_id == user_id,
            TreeNode.node_type == "folder",
            TreeNode.parent_id.is_(None),
            TreeNode.name == folder_name,
        )
    )
    folder = result.scalar_one_or_none()
    if folder is not None:
        return folder

    folder = TreeNode(
        user_id=user_id,
        name=folder_name,
        node_type="folder",
    )
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    return folder


async def _find_yesterdays_brief(db: AsyncSession, user_id: str, folder_id: str) -> str | None:
    result = await db.execute(
        select(TreeNode)
        .where(
            TreeNode.user_id == user_id,
            TreeNode.parent_id == folder_id,
            TreeNode.node_type == "file",
        )
        .order_by(TreeNode.created_at.desc())
        .limit(1)
    )
    node = result.scalar_one_or_none()
    if node is None or not node.content:
        return None
    return node.content[:2000]


def _format_brief_markdown(date_str: str, brief: dict[str, Any]) -> str:
    lines = [f"# Daily Brief — {date_str}", ""]

    lines.append("## Top Priorities")
    for i, p in enumerate(brief.get("top_priorities") or [], 1):
        lines.append(f"{i}. {p}")
    lines.append("")

    snapshot = brief.get("context_snapshot")
    if snapshot:
        lines.append("## Context Snapshot")
        lines.append(snapshot)
        lines.append("")

    followups = brief.get("follow_ups") or []
    if followups:
        lines.append("## Follow-Ups")
        for f in followups:
            lines.append(f"- {f}")
        lines.append("")

    plan = brief.get("suggested_plan")
    if plan:
        lines.append("## Suggested Plan")
        lines.append(plan)
        lines.append("")

    insight = brief.get("one_insight")
    if insight:
        lines.append("## One Insight")
        lines.append(f"> {insight}")
        lines.append("")

    lines.append("---")
    lines.append(f"*Generated by your AI coworker at {datetime.now(timezone.utc).isoformat(timespec='seconds')}*")
    return "\n".join(lines)


async def run_daily_brief(
    user_id: str,
    db: AsyncSession,
    trigger: str = "manual",
) -> AgentRun:
    """Execute the daily brief agent for a single user.

    Creates and commits an AgentRun row, builds context, calls the LLM,
    writes the brief to the workspace tree, and pushes a notification.
    """
    started = time.monotonic()

    run = AgentRun(
        user_id=user_id,
        agent_name="daily_brief",
        trigger=trigger,
        status="running",
        started_at=datetime.utcnow(),
    )
    db.add(run)
    await db.commit()
    await db.refresh(run)

    try:
        memory = MemoryLayer(user_id=user_id, db=db)

        # Gather context
        profile = await memory.get_profile()
        org = await memory.get_org_context()
        core_block = await memory.build_core_block()
        recalled_memories = await memory.recall(
            query="current priorities, goals, ongoing projects, and follow-ups",
            limit=10,
        )
        recent_files = await _load_recent_files(db, user_id=user_id, limit=15)
        todays_events = await _load_todays_events(db, user_id=user_id)

        # Structured goals + followups from knowledge graph
        goals_result = await db.execute(
            select(Goal)
            .where(Goal.user_id == user_id, Goal.status == "active")
            .order_by(Goal.priority)
            .limit(10)
        )
        active_goals = goals_result.scalars().all()

        followups_result = await db.execute(
            select(FollowUp)
            .where(FollowUp.user_id == user_id, FollowUp.status == "open")
            .order_by(FollowUp.due_date.asc().nullslast())
            .limit(10)
        )
        open_followups = followups_result.scalars().all()

        folder = await _find_or_create_folder(db, user_id=user_id, folder_name="Daily Briefs")
        yesterdays_brief = await _find_yesterdays_brief(db, user_id=user_id, folder_id=folder.id)

        memory_lines = [f"- {m.fact}" for m in recalled_memories] or ["- (no relevant memories)"]
        files_lines = [
            f"- {f['name']} ({f['file_type']}, updated {f['updated_at']}): {f['preview']}"
            for f in recent_files
        ] or ["- (no files in workspace yet)"]

        if todays_events:
            event_lines = []
            for ev in todays_events:
                attendees = f" with {', '.join(ev['attendees'][:5])}" if ev['attendees'] else ""
                event_lines.append(
                    f"- {ev['start']}-{ev['end']}: {ev['title']}{attendees}"
                )
        else:
            event_lines = ["- (no meetings today)"]

        today_iso = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        user_prompt_parts = [
            f"Today is {today_iso}.",
            "",
            core_block or "## User Profile\n(not configured)",
            "",
            "## Today's Calendar",
            *event_lines,
            "",
            "## Active Goals",
            *(
                [f"- [{g.level}/P{g.priority}] {g.title}" + (f" (due {g.due_date.isoformat()})" if g.due_date else "") for g in active_goals]
                or ["- (no goals defined yet)"]
            ),
            "",
            "## Open Follow-Ups",
            *(
                [f"- {f.description}" + (f" [owner: {f.owner}]" if f.owner else "") + (f" (due {f.due_date.isoformat()})" if f.due_date else "") for f in open_followups]
                or ["- (no open follow-ups)"]
            ),
            "",
            "## Recalled Memories",
            *memory_lines,
            "",
            "## Recent Workspace Files",
            *files_lines,
        ]
        if yesterdays_brief:
            user_prompt_parts.extend(
                [
                    "",
                    "## Yesterday's Brief (for continuity)",
                    yesterdays_brief,
                ]
            )
        user_prompt_parts.extend(
            [
                "",
                "Generate today's Daily Brief as JSON matching the schema.",
            ]
        )
        user_prompt = "\n".join(user_prompt_parts)

        # Call LLM
        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": DAILY_BRIEF_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.4,
            max_tokens=2000,
        )

        raw = response.choices[0].message.content or "{}"
        try:
            brief = json.loads(raw)
        except json.JSONDecodeError:
            brief = {
                "top_priorities": ["(brief generation returned invalid JSON)"],
                "context_snapshot": raw[:500],
                "follow_ups": [],
                "suggested_plan": "",
                "one_insight": "",
            }

        markdown = _format_brief_markdown(today_iso, brief)
        filename = f"{today_iso}.md"

        # If a brief for today already exists, update it; else create it
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
        run.output_payload = brief
        run.output_node_id = None  # set after refresh
        run.duration_ms = int((time.monotonic() - started) * 1000)
        run.completed_at = datetime.utcnow()
        await db.commit()
        await db.refresh(brief_node)
        run.output_node_id = brief_node.id
        await db.commit()
        await db.refresh(run)

        # Push notification
        await hub.publish(
            user_id,
            {
                "type": "brief_ready",
                "agent_run_id": run.id,
                "node_id": brief_node.id,
                "filename": filename,
                "generated_at": datetime.now(timezone.utc).isoformat(),
            },
        )

        return run

    except Exception as exc:  # noqa: BLE001 — capture any failure in AgentRun
        run.status = "failed"
        run.error_message = f"{type(exc).__name__}: {exc}"
        run.duration_ms = int((time.monotonic() - started) * 1000)
        run.completed_at = datetime.utcnow()
        try:
            await db.commit()
            await db.refresh(run)
        except Exception:
            pass
        return run
