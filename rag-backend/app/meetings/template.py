"""Markdown templates and section parsing for meeting documents.

The doc is the source of truth for free-form notes; the finalize pipeline
rewrites the Decisions and Action Items sections but never touches Notes.
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Iterable


SECTION_NOTES = "Notes"
SECTION_DECISIONS = "Decisions"
SECTION_ACTION_ITEMS = "Action Items"
SECTION_AGENDA = "Agenda"
SECTION_OPEN_QUESTIONS = "Open Questions"

_PLACEHOLDER_DECISIONS = "<!-- Will be auto-filled when you click Finalize -->"
_PLACEHOLDER_ACTIONS = "<!-- Will be auto-filled when you click Finalize → FollowUps -->"
_PLACEHOLDER_NOTES = "<!-- Type your notes during the meeting -->"


def render_initial_doc(
    *,
    meeting_id: str,
    title: str,
    scheduled_at: datetime | None,
    attendees: Iterable[dict] | None,
) -> str:
    """Render a blank draft meeting doc."""
    when_pretty = _format_when(scheduled_at)
    attendees_csv = _format_attendees(attendees)
    return (
        f"# {title}\n"
        f"\n"
        f"**When:** {when_pretty}  \n"
        f"**Attendees:** {attendees_csv}  \n"
        f"**Status:** draft\n"
        f"\n"
        f"## {SECTION_AGENDA}\n"
        f"- \n"
        f"\n"
        f"## {SECTION_NOTES}\n"
        f"{_PLACEHOLDER_NOTES}\n"
        f"\n"
        f"## {SECTION_DECISIONS}\n"
        f"{_PLACEHOLDER_DECISIONS}\n"
        f"\n"
        f"## {SECTION_ACTION_ITEMS}\n"
        f"{_PLACEHOLDER_ACTIONS}\n"
        f"\n"
        f"## {SECTION_OPEN_QUESTIONS}\n"
        f"- \n"
        f"\n"
        f"---\n"
        f"*Meeting ID: {meeting_id}*\n"
    )


def render_from_text_doc(
    *,
    meeting_id: str,
    title: str,
    scheduled_at: datetime | None,
    raw_text: str,
) -> str:
    """Render a meeting doc seeded with raw pasted text in the Notes section."""
    when_pretty = _format_when(scheduled_at)
    return (
        f"# {title}\n"
        f"\n"
        f"**When:** {when_pretty}  \n"
        f"**Status:** draft\n"
        f"\n"
        f"## {SECTION_AGENDA}\n"
        f"- \n"
        f"\n"
        f"## {SECTION_NOTES}\n"
        f"{raw_text.strip()}\n"
        f"\n"
        f"## {SECTION_DECISIONS}\n"
        f"{_PLACEHOLDER_DECISIONS}\n"
        f"\n"
        f"## {SECTION_ACTION_ITEMS}\n"
        f"{_PLACEHOLDER_ACTIONS}\n"
        f"\n"
        f"## {SECTION_OPEN_QUESTIONS}\n"
        f"- \n"
        f"\n"
        f"---\n"
        f"*Meeting ID: {meeting_id}*\n"
    )


def extract_section(doc: str, section_name: str) -> str:
    """Return the text content under `## {section_name}` up to the next `## ` header.

    Returns empty string if the section is missing or only contains placeholder text.
    """
    pattern = re.compile(
        rf"^##\s+{re.escape(section_name)}\s*\n(.*?)(?=^##\s+|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(doc)
    if not match:
        return ""
    body = match.group(1).strip()
    if not body or body.startswith("<!--"):
        return ""
    return body


def replace_section(doc: str, section_name: str, new_body: str) -> str:
    """Replace the body of `## {section_name}` with new_body. Adds trailing newline."""
    pattern = re.compile(
        rf"(^##\s+{re.escape(section_name)}\s*\n)(.*?)(?=^##\s+|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    replacement_body = new_body.rstrip() + "\n\n"

    def _sub(m: re.Match) -> str:
        return f"{m.group(1)}{replacement_body}"

    if pattern.search(doc):
        return pattern.sub(_sub, doc, count=1)
    # Section missing — append at end (before the meeting id footer if present)
    addition = f"\n## {section_name}\n{replacement_body}"
    if "*Meeting ID:" in doc:
        return doc.replace("---\n*Meeting ID:", f"{addition}---\n*Meeting ID:", 1)
    return doc + addition


def set_status(doc: str, new_status: str) -> str:
    """Update the **Status:** front matter line."""
    return re.sub(
        r"^\*\*Status:\*\*\s+\w+",
        f"**Status:** {new_status}",
        doc,
        count=1,
        flags=re.MULTILINE,
    )


def render_decisions_list(decisions: list) -> str:
    if not decisions:
        return "_No decisions extracted from notes._"
    lines: list[str] = []
    for d in decisions:
        title = getattr(d, "title", None) or "(untitled)"
        rationale = getattr(d, "rationale", None)
        if rationale:
            lines.append(f"- **{title}** — {rationale}")
        else:
            lines.append(f"- **{title}**")
    return "\n".join(lines)


def render_action_items_list(follow_ups: list) -> str:
    if not follow_ups:
        return "_No action items extracted from notes._"
    lines: list[str] = []
    for f in follow_ups:
        desc = getattr(f, "description", None) or "(no description)"
        owner = getattr(f, "owner", None)
        due = getattr(f, "due_date", None)
        meta_parts: list[str] = []
        if owner:
            meta_parts.append(f"@{owner}")
        if due:
            meta_parts.append(f"due {due.isoformat() if hasattr(due, 'isoformat') else due}")
        meta = f" _{' • '.join(meta_parts)}_" if meta_parts else ""
        lines.append(f"- [ ] {desc}{meta}")
    return "\n".join(lines)


def _format_when(scheduled_at: datetime | None) -> str:
    if scheduled_at is None:
        return "(not scheduled)"
    return scheduled_at.strftime("%A, %b %d %Y · %H:%M")


def _format_attendees(attendees: Iterable[dict] | None) -> str:
    if not attendees:
        return "(none)"
    names = []
    for a in attendees:
        name = a.get("name") or a.get("email") or ""
        if name:
            names.append(name)
    return ", ".join(names) if names else "(none)"
