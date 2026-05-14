WORKSPACE_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the content of a file in the user's workspace by its name or ID",
            "parameters": {
                "type": "object",
                "properties": {
                    "filename": {"type": "string", "description": "The name of the file to read"}
                },
                "required": ["filename"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_file",
            "description": "Create a new file in the user's workspace with the given name and content",
            "parameters": {
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "Name for the new file (e.g., 'Summary.md')"},
                    "content": {"type": "string", "description": "Content to write to the file"},
                    "file_type": {"type": "string", "description": "File extension type (md, txt)", "default": "md"}
                },
                "required": ["name", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "search_files",
            "description": "Search for files in the workspace by name or content keyword",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Search query to find matching files"}
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "list_folder",
            "description": "List all files and folders in the workspace root or a specific folder",
            "parameters": {
                "type": "object",
                "properties": {
                    "folder_name": {"type": "string", "description": "Name of folder to list, or empty for root", "default": ""}
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "remember",
            "description": (
                "Save a durable fact about the user, their preferences, projects, "
                "team, or working context for future conversations. Use when the user "
                "tells you something you should remember across sessions."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "fact": {
                        "type": "string",
                        "description": "The fact to remember, written as a single concise sentence.",
                    },
                    "confidence": {
                        "type": "number",
                        "description": "How confident you are in this fact, from 0.0 to 1.0.",
                        "default": 0.9,
                    },
                },
                "required": ["fact"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "recall",
            "description": (
                "Search durable memory for facts relevant to a query. Returns previously "
                "saved facts about the user, their preferences, projects, and context."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Natural language query to search memory.",
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of facts to return.",
                        "default": 5,
                    },
                },
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "forget",
            "description": (
                "Delete a previously saved memory fact by its ID. Use when the user "
                "explicitly asks you to forget something."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "fact_id": {
                        "type": "string",
                        "description": "The ID of the fact to forget.",
                    }
                },
                "required": ["fact_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "update_profile",
            "description": (
                "Update a field on the user's profile (role, team, responsibilities, "
                "working_hours, timezone, communication_style). Use when the user "
                "tells you something that should persist as a profile attribute."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "field": {
                        "type": "string",
                        "enum": [
                            "role",
                            "team",
                            "responsibilities",
                            "working_hours",
                            "timezone",
                            "communication_style",
                        ],
                        "description": "Which profile field to update.",
                    },
                    "value": {
                        "type": "string",
                        "description": "The new value for the field.",
                    },
                },
                "required": ["field", "value"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_calendar_events",
            "description": (
                "Fetch the user's calendar events for a given range. Use when the "
                "user asks about their meetings, schedule, or what's coming up. "
                "Ranges: 'today', 'tomorrow', 'this_week', 'next_week', or a specific "
                "ISO date like '2026-04-15'."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "range": {
                        "type": "string",
                        "description": "Range keyword or ISO date.",
                        "default": "today",
                    }
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "find_free_slots",
            "description": (
                "Find open time blocks in the user's calendar for a given day. "
                "Respects the user's working hours from their profile."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "date": {
                        "type": "string",
                        "description": "ISO date (YYYY-MM-DD), defaults to today.",
                    },
                    "duration_minutes": {
                        "type": "integer",
                        "description": "Minimum length of a free slot to report.",
                        "default": 30,
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_goals",
            "description": "List the user's goals. Filter by status (active/done/blocked) and level (org/team/personal).",
            "parameters": {
                "type": "object",
                "properties": {
                    "status": {"type": "string", "description": "Filter by status.", "default": "active"},
                    "level": {"type": "string", "description": "Filter by level (org, team, personal), or omit for all."},
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_followups",
            "description": "List open follow-up items that need attention. Includes owner, due date, and related goal.",
            "parameters": {
                "type": "object",
                "properties": {
                    "status": {"type": "string", "description": "Filter (open, done, snoozed).", "default": "open"},
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_decisions",
            "description": "List recent decisions with rationale. Useful for 'what did we decide about X?'",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {"type": "integer", "description": "Max decisions to return.", "default": 10},
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "create_goal",
            "description": "Create a new goal or objective for the user. Use when the user states a new goal or priority.",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Goal title."},
                    "description": {"type": "string", "description": "Optional detail."},
                    "level": {"type": "string", "enum": ["org", "team", "personal"], "default": "personal"},
                    "priority": {"type": "integer", "description": "1 (critical) to 5 (nice-to-have).", "default": 3},
                    "due_date": {"type": "string", "description": "ISO date YYYY-MM-DD or null."},
                },
                "required": ["title"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "update_goal_status",
            "description": "Update a goal's status. Use when the user says they finished, blocked, or abandoned a goal.",
            "parameters": {
                "type": "object",
                "properties": {
                    "goal_id": {"type": "string", "description": "The goal ID."},
                    "status": {"type": "string", "enum": ["active", "done", "blocked", "abandoned"], "description": "New status."},
                },
                "required": ["goal_id", "status"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "mark_followup_done",
            "description": "Mark a follow-up item as completed by its ID.",
            "parameters": {
                "type": "object",
                "properties": {
                    "followup_id": {"type": "string", "description": "The follow-up ID."},
                },
                "required": ["followup_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "create_meeting_doc",
            "description": (
                "Create a structured meeting document in the workspace under the "
                "Meetings/ folder. Use when the user wants to start taking notes "
                "for a meeting or capture an upcoming meeting's agenda."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Meeting title (e.g., 'Q2 Planning Sync')."},
                    "scheduled_at": {
                        "type": "string",
                        "description": "ISO datetime (YYYY-MM-DDTHH:MM) when the meeting occurs. Optional.",
                    },
                    "attendees": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of attendee names or emails. Optional.",
                    },
                },
                "required": ["title"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "finalize_meeting",
            "description": (
                "Finalize a draft meeting: parse the Notes section, extract "
                "Decisions, FollowUps, and People into the knowledge graph, and "
                "rewrite the doc with the structured outcomes. Use when the user "
                "says they're done with the meeting or wants to 'wrap up'."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "meeting_id": {"type": "string", "description": "Meeting ID. Optional if title_match is provided."},
                    "title_match": {"type": "string", "description": "Fuzzy match against meeting titles. Optional if meeting_id is provided."},
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_meetings",
            "description": "List recent meetings with title, status, and date. Use when the user asks about past or upcoming meetings.",
            "parameters": {
                "type": "object",
                "properties": {
                    "status": {"type": "string", "enum": ["draft", "finalized"], "description": "Filter by status. Optional."},
                    "limit": {"type": "integer", "description": "Max meetings to return.", "default": 10},
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "summarize_meeting",
            "description": "Return the Notes + Decisions + Action Items of a meeting as a readable summary.",
            "parameters": {
                "type": "object",
                "properties": {
                    "meeting_id": {"type": "string", "description": "Meeting ID. Optional if title_match is provided."},
                    "title_match": {"type": "string", "description": "Fuzzy match against meeting titles. Optional if meeting_id is provided."},
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "complete_brief_task",
            "description": (
                "Mark one or more daily brief priorities as completed. Use when "
                "the user says they finished a task from today's brief. Accepts "
                "task text to fuzzy-match against current priorities, or a specific index (0-based)."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "task_text": {
                        "type": "string",
                        "description": "Text of the task to mark complete (fuzzy matched against priorities).",
                    },
                    "task_index": {
                        "type": "integer",
                        "description": "0-based index of the priority to mark complete (use if text matching is ambiguous).",
                    },
                    "completed": {
                        "type": "boolean",
                        "description": "True to mark complete, false to undo.",
                        "default": True,
                    },
                },
                "required": [],
            },
        },
    },
]

TOOLS_INFO = [
    {"name": "read_file", "description": "Read the content of a workspace file", "icon": "description"},
    {"name": "create_file", "description": "Create a new file in workspace", "icon": "note_add"},
    {"name": "search_files", "description": "Search files by name or content", "icon": "search"},
    {"name": "list_folder", "description": "List contents of a folder", "icon": "folder_open"},
    {"name": "remember", "description": "Save a durable fact to memory", "icon": "bookmark_add"},
    {"name": "recall", "description": "Search durable memory for relevant facts", "icon": "psychology"},
    {"name": "forget", "description": "Delete a memory fact by ID", "icon": "delete_outline"},
    {"name": "update_profile", "description": "Update a user profile field", "icon": "person"},
    {"name": "get_calendar_events", "description": "Fetch calendar events", "icon": "calendar_today"},
    {"name": "find_free_slots", "description": "Find open time blocks", "icon": "schedule"},
    {"name": "get_goals", "description": "List active goals", "icon": "flag"},
    {"name": "get_followups", "description": "List open follow-ups", "icon": "checklist"},
    {"name": "get_decisions", "description": "List recent decisions", "icon": "gavel"},
    {"name": "create_goal", "description": "Create a new goal", "icon": "add_task"},
    {"name": "update_goal_status", "description": "Update goal status", "icon": "edit"},
    {"name": "mark_followup_done", "description": "Mark follow-up as done", "icon": "check_circle"},
    {"name": "complete_brief_task", "description": "Mark brief priority as done", "icon": "task_alt"},
    {"name": "create_meeting_doc", "description": "Start a structured meeting doc", "icon": "groups"},
    {"name": "finalize_meeting", "description": "Extract decisions and follow-ups from meeting notes", "icon": "auto_awesome"},
    {"name": "list_meetings", "description": "List recent meetings", "icon": "event_note"},
    {"name": "summarize_meeting", "description": "Summarize a meeting", "icon": "summarize"},
]
