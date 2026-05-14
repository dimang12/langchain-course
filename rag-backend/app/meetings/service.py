"""Meeting business logic — create, finalize, render."""

from __future__ import annotations

import logging
import re
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.knowledge.extractor import extract_and_collect
from app.meetings.template import (
    SECTION_ACTION_ITEMS,
    SECTION_DECISIONS,
    SECTION_NOTES,
    extract_section,
    render_action_items_list,
    render_decisions_list,
    render_from_text_doc,
    render_initial_doc,
    replace_section,
    set_status,
)
from app.models.meetings import Meeting
from app.models.workspace import TreeNode

logger = logging.getLogger(__name__)

MEETINGS_FOLDER_NAME = "Meetings"


async def ensure_meetings_folder(db: AsyncSession, user_id: str) -> TreeNode:
    """Get or create the user's top-level Meetings/ folder."""
    result = await db.execute(
        select(TreeNode).where(
            TreeNode.user_id == user_id,
            TreeNode.parent_id.is_(None),
            TreeNode.name == MEETINGS_FOLDER_NAME,
            TreeNode.node_type == "folder",
        )
    )
    folder = result.scalar_one_or_none()
    if folder is not None:
        return folder
    folder = TreeNode(
        user_id=user_id,
        parent_id=None,
        name=MEETINGS_FOLDER_NAME,
        node_type="folder",
    )
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    return folder


async def create_meeting(
    db: AsyncSession,
    *,
    user_id: str,
    title: str,
    scheduled_at: datetime | None = None,
    attendees: list[dict] | None = None,
    calendar_event_id: str | None = None,
    raw_text: str | None = None,
) -> Meeting:
    """Create a meeting + paired markdown doc in the Meetings/ folder."""
    folder = await ensure_meetings_folder(db, user_id)

    meeting = Meeting(
        user_id=user_id,
        title=title,
        scheduled_at=scheduled_at,
        attendees=attendees or [],
        calendar_event_id=calendar_event_id,
        status="draft",
    )
    db.add(meeting)
    await db.flush()  # populate meeting.id

    doc_body = (
        render_from_text_doc(
            meeting_id=meeting.id,
            title=title,
            scheduled_at=scheduled_at,
            raw_text=raw_text,
        )
        if raw_text and raw_text.strip()
        else render_initial_doc(
            meeting_id=meeting.id,
            title=title,
            scheduled_at=scheduled_at,
            attendees=attendees,
        )
    )

    doc = TreeNode(
        user_id=user_id,
        parent_id=folder.id,
        name=_doc_filename(title, scheduled_at),
        node_type="file",
        file_type="md",
        content=doc_body,
    )
    db.add(doc)
    await db.flush()

    meeting.tree_node_id = doc.id
    await db.commit()
    await db.refresh(meeting)
    return meeting


async def finalize_meeting(
    db: AsyncSession,
    *,
    user_id: str,
    meeting: Meeting,
) -> dict:
    """Run extractor against the Notes section and rewrite Decisions / Action Items.

    Returns a summary dict with counts and lists.
    """
    if meeting.tree_node_id is None:
        raise ValueError("Meeting has no associated doc")

    doc_node = await db.get(TreeNode, meeting.tree_node_id)
    if doc_node is None or doc_node.user_id != user_id:
        raise ValueError("Meeting doc not found")

    doc = doc_node.content or ""
    notes_text = extract_section(doc, SECTION_NOTES)

    extracted = await extract_and_collect(
        content=notes_text,
        user_id=user_id,
        db=db,
        source="meeting",
        source_ref=f"meeting:{meeting.id}",
    )

    decisions = extracted.get("decisions", [])
    follow_ups = extracted.get("follow_ups", [])

    new_doc = replace_section(doc, SECTION_DECISIONS, render_decisions_list(decisions))
    new_doc = replace_section(new_doc, SECTION_ACTION_ITEMS, render_action_items_list(follow_ups))
    new_doc = set_status(new_doc, "finalized")

    doc_node.content = new_doc
    meeting.status = "finalized"
    meeting.finalized_at = datetime.utcnow()
    meeting.decisions_extracted = len(decisions)
    meeting.follow_ups_extracted = len(follow_ups)

    await db.commit()
    await db.refresh(meeting)

    return {
        "meeting_id": meeting.id,
        "decisions_extracted": len(decisions),
        "follow_ups_extracted": len(follow_ups),
        "goals_extracted": len(extracted.get("goals", [])),
        "people_extracted": len(extracted.get("people", [])),
        "decisions": [
            {"id": d.id, "title": d.title, "rationale": d.rationale} for d in decisions
        ],
        "follow_ups": [
            {
                "id": f.id,
                "description": f.description,
                "owner": f.owner,
                "due_date": f.due_date.isoformat() if f.due_date else None,
            }
            for f in follow_ups
        ],
    }


def serialize_meeting(meeting: Meeting, *, include_content: bool = False) -> dict:
    doc_node = meeting.tree_node if hasattr(meeting, "tree_node") else None
    payload = {
        "id": meeting.id,
        "title": meeting.title,
        "status": meeting.status,
        "scheduled_at": meeting.scheduled_at.isoformat() if meeting.scheduled_at else None,
        "finalized_at": meeting.finalized_at.isoformat() if meeting.finalized_at else None,
        "attendees": meeting.attendees or [],
        "calendar_event_id": meeting.calendar_event_id,
        "tree_node_id": meeting.tree_node_id,
        "decisions_extracted": meeting.decisions_extracted,
        "follow_ups_extracted": meeting.follow_ups_extracted,
        "todos_created": meeting.todos_created,
        "created_at": meeting.created_at.isoformat(),
        "updated_at": meeting.updated_at.isoformat(),
    }
    if include_content:
        payload["content"] = doc_node.content if doc_node else None
        payload["doc_name"] = doc_node.name if doc_node else None
    return payload


_FILENAME_FORBIDDEN = re.compile(r'[\\/:*?"<>|]')


def _doc_filename(title: str, scheduled_at: datetime | None) -> str:
    safe_title = _FILENAME_FORBIDDEN.sub("-", title).strip() or "Untitled"
    date_prefix = (scheduled_at or datetime.utcnow()).strftime("%Y-%m-%d")
    return f"{date_prefix} - {safe_title}.md"
