import os
from datetime import datetime

from sqlalchemy import desc, func, select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.meetings.service import create_meeting, finalize_meeting
from app.memory.service import MemoryLayer
from app.models.meetings import Meeting
from app.models.workspace import TreeNode


async def execute_tool(tool_name: str, args: dict, user_id: str, db: AsyncSession) -> str:
    handlers = {
        "read_file": _read_file,
        "create_file": _create_file,
        "search_files": _search_files,
        "list_folder": _list_folder,
        "remember": _remember,
        "recall": _recall,
        "forget": _forget,
        "update_profile": _update_profile,
        "get_calendar_events": _get_calendar_events,
        "find_free_slots": _find_free_slots,
        "get_goals": _get_goals,
        "get_followups": _get_followups,
        "get_decisions": _get_decisions,
        "create_goal": _create_goal,
        "update_goal_status": _update_goal_status,
        "mark_followup_done": _mark_followup_done,
        "complete_brief_task": _complete_brief_task,
        "create_meeting_doc": _create_meeting_doc,
        "finalize_meeting": _finalize_meeting,
        "list_meetings": _list_meetings,
        "summarize_meeting": _summarize_meeting,
    }
    handler = handlers.get(tool_name)
    if not handler:
        return f"Unknown tool: {tool_name}"
    return await handler(args, user_id, db)


async def _resolve_meeting(args: dict, user_id: str, db: AsyncSession) -> Meeting | None:
    meeting_id = args.get("meeting_id")
    if meeting_id:
        meeting = await db.get(Meeting, meeting_id)
        if meeting is not None and meeting.user_id == user_id:
            return meeting
    title_match = (args.get("title_match") or "").strip()
    if title_match:
        result = await db.execute(
            select(Meeting)
            .where(
                Meeting.user_id == user_id,
                func.lower(Meeting.title).like(f"%{title_match.lower()}%"),
            )
            .order_by(desc(Meeting.created_at))
            .limit(1)
        )
        return result.scalar_one_or_none()
    return None


async def _create_meeting_doc(args: dict, user_id: str, db: AsyncSession) -> str:
    title = (args.get("title") or "").strip()
    if not title:
        return "Need a meeting title to create a doc."
    scheduled_at_str = args.get("scheduled_at")
    scheduled_at: datetime | None = None
    if scheduled_at_str:
        try:
            scheduled_at = datetime.fromisoformat(scheduled_at_str.replace("Z", "+00:00"))
        except ValueError:
            scheduled_at = None
    attendees_in = args.get("attendees") or []
    attendees = [{"name": a} if isinstance(a, str) else a for a in attendees_in]

    meeting = await create_meeting(
        db,
        user_id=user_id,
        title=title,
        scheduled_at=scheduled_at,
        attendees=attendees or None,
    )
    when = (
        scheduled_at.strftime("%a %b %d, %H:%M") if scheduled_at else "no scheduled time"
    )
    return (
        f"Created meeting doc '{title}' ({when}). "
        f"Meeting ID: {meeting.id}. Doc lives under Meetings/."
    )


async def _finalize_meeting(args: dict, user_id: str, db: AsyncSession) -> str:
    meeting = await _resolve_meeting(args, user_id, db)
    if meeting is None:
        return "Could not find a meeting matching the provided ID or title."
    try:
        result = await finalize_meeting(db, user_id=user_id, meeting=meeting)
    except ValueError as exc:
        return f"Could not finalize: {exc}"
    return (
        f"Finalized '{meeting.title}'. "
        f"Extracted {result['decisions_extracted']} decisions, "
        f"{result['follow_ups_extracted']} follow-ups, "
        f"{result['goals_extracted']} goals, "
        f"{result['people_extracted']} people."
    )


async def _list_meetings(args: dict, user_id: str, db: AsyncSession) -> str:
    status = args.get("status")
    limit = int(args.get("limit") or 10)
    stmt = select(Meeting).where(Meeting.user_id == user_id)
    if status in {"draft", "finalized"}:
        stmt = stmt.where(Meeting.status == status)
    stmt = stmt.order_by(desc(Meeting.scheduled_at), desc(Meeting.created_at)).limit(limit)
    result = await db.execute(stmt)
    meetings = result.scalars().all()
    if not meetings:
        return "No meetings found."
    lines = []
    for m in meetings:
        when = m.scheduled_at.strftime("%Y-%m-%d %H:%M") if m.scheduled_at else "—"
        lines.append(f"- {when} · {m.title} · {m.status} (id: {m.id})")
    return "\n".join(lines)


async def _summarize_meeting(args: dict, user_id: str, db: AsyncSession) -> str:
    meeting = await _resolve_meeting(args, user_id, db)
    if meeting is None:
        return "Could not find a meeting matching the provided ID or title."
    if meeting.tree_node_id is None:
        return f"Meeting '{meeting.title}' has no doc."
    doc = await db.get(TreeNode, meeting.tree_node_id)
    if doc is None or doc.user_id != user_id:
        return "Meeting doc not found."
    body = doc.content or ""
    parts = [f"# {meeting.title} ({meeting.status})"]
    if meeting.scheduled_at:
        parts.append(f"When: {meeting.scheduled_at.strftime('%Y-%m-%d %H:%M')}")
    parts.append(body)
    return "\n\n".join(parts)


async def _read_file(args: dict, user_id: str, db: AsyncSession) -> str:
    filename = args.get("filename", "")
    result = await db.execute(
        select(TreeNode).where(
            TreeNode.user_id == user_id,
            TreeNode.node_type == "file",
            TreeNode.name.ilike(f"%{filename}%"),
        )
    )
    node = result.scalar_one_or_none()
    if not node:
        return f"File '{filename}' not found in workspace."

    if node.content:
        return f"Content of '{node.name}':\n\n{node.content}"

    if node.file_path and os.path.exists(node.file_path):
        try:
            from unstructured.partition.auto import partition
            elements = partition(filename=node.file_path)
            text = "\n\n".join(str(el) for el in elements)
            return f"Content of '{node.name}':\n\n{text}"
        except Exception:
            return f"Could not extract text from '{node.name}'."

    return f"File '{node.name}' has no readable content."


async def _create_file(args: dict, user_id: str, db: AsyncSession) -> str:
    name = args.get("name", "Untitled.md")
    content = args.get("content", "")
    file_type = args.get("file_type", "md")

    node = TreeNode(
        user_id=user_id,
        name=name,
        node_type="file",
        file_type=file_type,
        content=content,
    )
    db.add(node)
    await db.commit()
    await db.refresh(node)
    return f"Created file '{name}' successfully (ID: {node.id})."


async def _search_files(args: dict, user_id: str, db: AsyncSession) -> str:
    query = args.get("query", "")
    result = await db.execute(
        select(TreeNode).where(
            TreeNode.user_id == user_id,
            TreeNode.node_type == "file",
            or_(
                TreeNode.name.ilike(f"%{query}%"),
                TreeNode.content.ilike(f"%{query}%"),
            ),
        )
    )
    nodes = result.scalars().all()
    if not nodes:
        return f"No files found matching '{query}'."

    files = "\n".join(f"- {n.name} ({n.file_type or 'unknown'}, status: {n.ingestion_status or 'none'})" for n in nodes)
    return f"Found {len(nodes)} file(s) matching '{query}':\n{files}"


async def _list_folder(args: dict, user_id: str, db: AsyncSession) -> str:
    folder_name = args.get("folder_name", "")

    if folder_name:
        folder_result = await db.execute(
            select(TreeNode).where(
                TreeNode.user_id == user_id,
                TreeNode.node_type == "folder",
                TreeNode.name.ilike(f"%{folder_name}%"),
            )
        )
        folder = folder_result.scalar_one_or_none()
        if not folder:
            return f"Folder '{folder_name}' not found."
        parent_id = folder.id
    else:
        parent_id = None

    result = await db.execute(
        select(TreeNode).where(
            TreeNode.user_id == user_id,
            TreeNode.parent_id == parent_id,
        )
    )
    nodes = result.scalars().all()
    if not nodes:
        return "Folder is empty."

    items = "\n".join(
        f"- {'folder' if n.node_type == 'folder' else 'file'}: {n.name}" + (f" ({n.file_type})" if n.file_type else "")
        for n in sorted(nodes, key=lambda x: (x.node_type != 'folder', x.name))
    )
    location = folder_name or "root"
    return f"Contents of '{location}':\n{items}"


# ---------------------------------------------------------------------------
# Memory tools
# ---------------------------------------------------------------------------
_VALID_PROFILE_FIELDS = {
    "role",
    "team",
    "responsibilities",
    "working_hours",
    "timezone",
    "communication_style",
}


async def _remember(args: dict, user_id: str, db: AsyncSession) -> str:
    fact = (args.get("fact") or "").strip()
    if not fact:
        return "No fact provided to remember."
    confidence = float(args.get("confidence", 0.9))
    confidence = max(0.0, min(1.0, confidence))

    layer = MemoryLayer(user_id=user_id, db=db)
    row = await layer.write_fact(fact=fact, source="chat", confidence=confidence)
    return f"Remembered (id={row.id}): {row.fact}"


async def _recall(args: dict, user_id: str, db: AsyncSession) -> str:
    query = (args.get("query") or "").strip()
    if not query:
        return "No query provided for recall."
    try:
        limit = int(args.get("limit", 5))
    except (TypeError, ValueError):
        limit = 5
    limit = max(1, min(limit, 20))

    layer = MemoryLayer(user_id=user_id, db=db)
    facts = await layer.recall(query, limit=limit)
    if not facts:
        return "No relevant memories found."

    lines = [f"Found {len(facts)} relevant memory fact(s):"]
    for f in facts:
        lines.append(f"- (id={f.id}, confidence={f.confidence:.2f}) {f.fact}")
    return "\n".join(lines)


async def _forget(args: dict, user_id: str, db: AsyncSession) -> str:
    fact_id = (args.get("fact_id") or "").strip()
    if not fact_id:
        return "No fact_id provided."

    layer = MemoryLayer(user_id=user_id, db=db)
    ok = await layer.forget_fact(fact_id)
    return f"Forgot fact {fact_id}." if ok else f"Fact {fact_id} not found."


async def _update_profile(args: dict, user_id: str, db: AsyncSession) -> str:
    field = (args.get("field") or "").strip()
    value = args.get("value")
    if field not in _VALID_PROFILE_FIELDS:
        return f"Invalid profile field: {field}"
    if value is None:
        return "No value provided."

    layer = MemoryLayer(user_id=user_id, db=db)
    await layer.upsert_profile({field: str(value)})
    return f"Updated profile.{field} = {value}"


# ---------------------------------------------------------------------------
# Calendar tools
# ---------------------------------------------------------------------------
def _resolve_range(range_str: str) -> tuple:
    """Translate a range keyword into (start, end) datetimes (naive UTC)."""
    from datetime import datetime, timedelta

    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    keyword = (range_str or "today").strip().lower()

    if keyword == "today":
        return today_start, today_start + timedelta(days=1)
    if keyword == "tomorrow":
        return today_start + timedelta(days=1), today_start + timedelta(days=2)
    if keyword == "this_week":
        weekday = today_start.weekday()
        start = today_start - timedelta(days=weekday)
        return start, start + timedelta(days=7)
    if keyword == "next_week":
        weekday = today_start.weekday()
        start = today_start - timedelta(days=weekday) + timedelta(days=7)
        return start, start + timedelta(days=7)

    # Try ISO date
    try:
        dt = datetime.fromisoformat(keyword)
        day_start = dt.replace(hour=0, minute=0, second=0, microsecond=0)
        return day_start, day_start + timedelta(days=1)
    except ValueError:
        return today_start, today_start + timedelta(days=1)


async def _get_calendar_events(args: dict, user_id: str, db: AsyncSession) -> str:
    from app.models.connectors import CalendarEvent

    start, end = _resolve_range(args.get("range", "today"))

    result = await db.execute(
        select(CalendarEvent)
        .where(
            CalendarEvent.user_id == user_id,
            CalendarEvent.start_time >= start,
            CalendarEvent.start_time < end,
        )
        .order_by(CalendarEvent.start_time)
    )
    events = result.scalars().all()
    if not events:
        return f"No calendar events found for range '{args.get('range', 'today')}'."

    lines = [f"Found {len(events)} event(s):"]
    for ev in events:
        when = ev.start_time.strftime("%a %b %d %H:%M") + "–" + ev.end_time.strftime("%H:%M")
        attendees = ""
        if ev.attendees:
            attendees = f" | with {', '.join(ev.attendees[:5])}"
        location_or_url = ""
        if ev.meeting_url:
            location_or_url = f" | {ev.meeting_url}"
        elif ev.location:
            location_or_url = f" | {ev.location}"
        lines.append(f"- {when} — {ev.title}{attendees}{location_or_url}")
    return "\n".join(lines)


async def _find_free_slots(args: dict, user_id: str, db: AsyncSession) -> str:
    from datetime import datetime, timedelta

    from app.models.connectors import CalendarEvent
    from app.models.identity import UserProfile

    duration_min = int(args.get("duration_minutes", 30))
    duration_min = max(15, min(duration_min, 480))

    date_str = (args.get("date") or "").strip()
    try:
        base = datetime.fromisoformat(date_str) if date_str else datetime.utcnow()
    except ValueError:
        base = datetime.utcnow()

    day_start = base.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)

    # Load working hours from profile (format e.g., "09:00-18:00")
    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = profile_result.scalar_one_or_none()

    work_start_h, work_end_h = 9, 18
    if profile and profile.working_hours:
        try:
            start_part, end_part = profile.working_hours.split("-")
            work_start_h = int(start_part.split(":")[0])
            work_end_h = int(end_part.split(":")[0])
        except (ValueError, IndexError):
            pass

    window_start = day_start.replace(hour=work_start_h)
    window_end = day_start.replace(hour=work_end_h)

    # Pull events that overlap the day
    result = await db.execute(
        select(CalendarEvent)
        .where(
            CalendarEvent.user_id == user_id,
            CalendarEvent.start_time < day_end,
            CalendarEvent.end_time > day_start,
        )
        .order_by(CalendarEvent.start_time)
    )
    events = result.scalars().all()

    # Compute free intervals
    cursor = window_start
    free_slots: list[tuple[datetime, datetime]] = []
    for ev in events:
        ev_start = max(ev.start_time, window_start)
        ev_end = min(ev.end_time, window_end)
        if ev_start >= window_end or ev_end <= window_start:
            continue
        if ev_start > cursor:
            free_slots.append((cursor, ev_start))
        if ev_end > cursor:
            cursor = ev_end
    if cursor < window_end:
        free_slots.append((cursor, window_end))

    # Filter by minimum duration
    qualifying = [
        (s, e) for s, e in free_slots if (e - s).total_seconds() / 60 >= duration_min
    ]
    if not qualifying:
        return f"No free slots of {duration_min}+ minutes on {window_start.date().isoformat()}."

    lines = [f"Free slots on {window_start.date().isoformat()} ({duration_min}+ min):"]
    for s, e in qualifying:
        lines.append(f"- {s.strftime('%H:%M')} – {e.strftime('%H:%M')}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Knowledge graph tools
# ---------------------------------------------------------------------------
async def _get_goals(args: dict, user_id: str, db: AsyncSession) -> str:
    from app.models.knowledge import Goal

    status = (args.get("status") or "active").strip()
    level = (args.get("level") or "").strip() or None

    stmt = select(Goal).where(Goal.user_id == user_id, Goal.status == status)
    if level:
        stmt = stmt.where(Goal.level == level)
    stmt = stmt.order_by(Goal.priority, Goal.created_at.desc())

    result = await db.execute(stmt)
    goals = result.scalars().all()
    if not goals:
        return f"No {status} goals found."

    lines = [f"Found {len(goals)} {status} goal(s):"]
    for g in goals:
        due = f" (due {g.due_date.isoformat()})" if g.due_date else ""
        lines.append(f"- [{g.level}/P{g.priority}] {g.title}{due} (id={g.id})")
    return "\n".join(lines)


async def _get_followups(args: dict, user_id: str, db: AsyncSession) -> str:
    from app.models.knowledge import FollowUp

    status = (args.get("status") or "open").strip()

    result = await db.execute(
        select(FollowUp)
        .where(FollowUp.user_id == user_id, FollowUp.status == status)
        .order_by(FollowUp.due_date.asc().nullslast(), FollowUp.created_at.desc())
    )
    followups = result.scalars().all()
    if not followups:
        return f"No {status} follow-ups found."

    lines = [f"Found {len(followups)} {status} follow-up(s):"]
    for f in followups:
        due = f" (due {f.due_date.isoformat()})" if f.due_date else ""
        owner = f" [owner: {f.owner}]" if f.owner else ""
        lines.append(f"- {f.description}{owner}{due} (id={f.id})")
    return "\n".join(lines)


async def _get_decisions(args: dict, user_id: str, db: AsyncSession) -> str:
    from app.models.knowledge import Decision

    try:
        limit = int(args.get("limit", 10))
    except (TypeError, ValueError):
        limit = 10
    limit = max(1, min(50, limit))

    result = await db.execute(
        select(Decision)
        .where(Decision.user_id == user_id)
        .order_by(Decision.created_at.desc())
        .limit(limit)
    )
    decisions = result.scalars().all()
    if not decisions:
        return "No decisions recorded."

    lines = [f"Found {len(decisions)} decision(s):"]
    for d in decisions:
        when = f" ({d.decided_at.isoformat()})" if d.decided_at else ""
        rationale = f" — {d.rationale[:100]}" if d.rationale else ""
        lines.append(f"- {d.title}{when}{rationale} (id={d.id})")
    return "\n".join(lines)


async def _create_goal(args: dict, user_id: str, db: AsyncSession) -> str:
    from datetime import date as date_type
    from app.models.knowledge import Goal

    title = (args.get("title") or "").strip()
    if not title:
        return "No title provided for goal."

    due_date = None
    if args.get("due_date"):
        try:
            due_date = date_type.fromisoformat(args["due_date"])
        except ValueError:
            pass

    try:
        priority = max(1, min(5, int(args.get("priority", 3))))
    except (TypeError, ValueError):
        priority = 3

    goal = Goal(
        user_id=user_id,
        title=title,
        description=args.get("description"),
        level=args.get("level", "personal"),
        priority=priority,
        due_date=due_date,
        source="chat",
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)
    return f"Created goal: {goal.title} [{goal.level}/P{goal.priority}] (id={goal.id})"


async def _update_goal_status(args: dict, user_id: str, db: AsyncSession) -> str:
    from app.models.knowledge import Goal

    goal_id = (args.get("goal_id") or "").strip()
    new_status = (args.get("status") or "").strip()
    valid = {"active", "done", "blocked", "abandoned"}
    if new_status not in valid:
        return f"Invalid status '{new_status}'. Use: {', '.join(valid)}"
    if not goal_id:
        return "No goal_id provided."

    result = await db.execute(
        select(Goal).where(Goal.id == goal_id, Goal.user_id == user_id)
    )
    goal = result.scalar_one_or_none()
    if goal is None:
        return f"Goal {goal_id} not found."

    goal.status = new_status
    await db.commit()
    return f"Goal '{goal.title}' status updated to {new_status}"


async def _mark_followup_done(args: dict, user_id: str, db: AsyncSession) -> str:
    from app.models.knowledge import FollowUp

    followup_id = (args.get("followup_id") or "").strip()
    if not followup_id:
        return "No followup_id provided."

    result = await db.execute(
        select(FollowUp).where(
            FollowUp.id == followup_id,
            FollowUp.user_id == user_id,
        )
    )
    followup = result.scalar_one_or_none()
    if followup is None:
        return f"Follow-up {followup_id} not found."

    followup.status = "done"
    await db.commit()
    return f"Marked follow-up as done: {followup.description}"


async def _complete_brief_task(args: dict, user_id: str, db: AsyncSession) -> str:
    from app.models.agent_run import AgentRun

    completed = args.get("completed", True)
    task_text = (args.get("task_text") or "").strip().lower()
    task_index = args.get("task_index")

    # Find the latest successful daily brief
    result = await db.execute(
        select(AgentRun)
        .where(
            AgentRun.user_id == user_id,
            AgentRun.agent_name == "daily_brief",
            AgentRun.status == "success",
        )
        .order_by(AgentRun.started_at.desc())
        .limit(1)
    )
    run = result.scalar_one_or_none()
    if run is None:
        return "No daily brief found. Generate one first."

    priorities = (run.output_payload or {}).get("top_priorities", [])
    if not priorities:
        return "No priorities in the latest brief."

    # Resolve index from text if needed
    if task_index is not None:
        idx = int(task_index)
    elif task_text:
        # Fuzzy match: find best matching priority
        best_idx, best_score = -1, 0
        for i, p in enumerate(priorities):
            p_lower = p.lower()
            # Simple word overlap scoring
            task_words = set(task_text.split())
            p_words = set(p_lower.split())
            overlap = len(task_words & p_words)
            if overlap > best_score:
                best_score = overlap
                best_idx = i
            # Substring match
            if task_text in p_lower or p_lower in task_text:
                best_idx = i
                break
        if best_idx < 0:
            return f"Could not match '{task_text}' to any priority. Current priorities:\n" + \
                "\n".join(f"  {i}. {p}" for i, p in enumerate(priorities))
        idx = best_idx
    else:
        return "Provide either task_text or task_index to identify which priority to complete."

    if idx < 0 or idx >= len(priorities):
        return f"Invalid index {idx}. Brief has {len(priorities)} priorities (0-{len(priorities)-1})."

    completions = list(run.task_completions or [False] * len(priorities))
    while len(completions) < len(priorities):
        completions.append(False)
    completions[idx] = completed
    run.task_completions = completions
    await db.commit()

    status_word = "completed" if completed else "reopened"
    return f"Marked priority #{idx+1} as {status_word}: {priorities[idx]}"
