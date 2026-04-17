# AI Coworker — Implementation Roadmap

> Evolve the RAG Knowledge Workspace from a reactive chat-with-docs tool into a proactive AI coworker that understands organizational goals, leadership priorities, and actively guides the user's daily workflow (Mon–Fri).

**Status:** Planning
**Created:** 2026-04-11
**Predecessor:** `Knowledge_Workspace_Plan.md` (Phases A–F — complete)
**Successor phases:** G, H, I, J

---

## 1. Vision

The current system is **reactive** — user asks, AI retrieves from documents, AI answers. A coworker is **proactive + persistent + contextual**. It should:

- Understand the user's role, team, and organizational goals
- Know what the user is working on this week without being asked
- Generate a daily focus brief every morning (top 3 priorities, follow-ups, overnight changes)
- Integrate with Slack, email, calendar, and meeting transcripts
- Remember facts across sessions (not just chat history)
- Act autonomously on schedules and triggers, not just on prompts
- Provide measurable signal that it's actually helping

This document is the blueprint for that evolution.

---

## 2. The 5 Capability Layers

A coworker-grade system requires 5 distinct capability layers on top of the current workspace + RAG substrate. None exist yet; all must be built.

| # | Layer | What It Adds | Current State |
|---|-------|--------------|---------------|
| 1 | **Memory** | Persistent user/org knowledge, semantic + episodic | ❌ Chat history only |
| 2 | **Context Ingestion** | Calendar, email, Slack, meeting transcripts | ❌ Manual uploads only |
| 3 | **Knowledge Graph** | Structured Goals, Projects, People, Decisions, FollowUps | ❌ Vector chunks only |
| 4 | **Agentic Loop** | Scheduled triggers, proactive behaviors, event bus | ❌ Reactive only |
| 5 | **Trust & Eval** | Measurable quality signal, regression tests | ❌ None |

**Critical principle:** Do NOT build each layer to completion before moving on. Build a thin vertical slice through all 5 layers around ONE feature, ship it, prove it, then expand.

---

## 3. The Vertical Slice — "Daily Focus Brief"

The one feature that forces us to touch all 5 layers in minimal form:

> **Every morning at 8:00am, the AI generates a personalized "Daily Focus" brief for the user: top 3 priorities, what changed overnight, follow-ups due today, and a suggested plan for the day — grounded in organizational goals.**

### How the Daily Brief exercises each layer

| Layer | What the Brief Requires |
|-------|------------------------|
| Memory | Must remember user's role, open projects, yesterday's brief, past feedback |
| Context Ingestion | Pulls from at least one external source (Calendar first) |
| Knowledge Graph | Reads structured goals (even if just a `goals.md` file initially) |
| Agentic Loop | Scheduled cron trigger runs without user prompt, writes output to workspace |
| Trust & Eval | User rates each brief 1–5, feedback loop improves prompt |

**Deliverable:** A `Daily Briefs/YYYY-MM-DD.md` file appears in the workspace tree every morning at 8am, and a WebSocket push notifies the Flutter client.

---

## 4. Architecture — Target State

```
+----------------------------------------------------------------+
|  FLUTTER FRONTEND                                              |
|                                                                |
|  [Nav Rail]  [Tree]  [Tabs: md/pdf/csv/chat]  [Floating Chat] |
|  [Today]  <-- NEW: dashboard with brief + agenda + followups  |
|  [Activity Feed] <-- NEW: agent run history + notifications   |
|  [Goals] <-- NEW: structured goals UI                          |
+----------------------------------------------------------------+
          |                    |                    |
    REST API + WS        OAuth callbacks      WebSocket push
          |                    |                    |
+----------------------------------------------------------------+
|  FASTAPI BACKEND                                               |
|                                                                |
|  +------------+  +------------+  +----------------+           |
|  | Chat + RAG |  | Workspace  |  | Tools Registry |           |
|  +------------+  +------------+  +----------------+           |
|  +------------+  +------------+  +----------------+           |
|  | Memory     |  | Agent      |  | Scheduler      |  <-- NEW |
|  | Layer      |  | Runner     |  | (APScheduler)  |           |
|  +------------+  +------------+  +----------------+           |
|  +------------+  +------------+  +----------------+           |
|  | Connectors |  | Extraction |  | Eval Harness   |  <-- NEW |
|  | (Calendar, |  | Pipeline   |  | (Promptfoo)    |           |
|  |  Gmail,    |  |            |  |                |           |
|  |  Slack)    |  |            |  |                |           |
|  +------------+  +------------+  +----------------+           |
+----------------------------------------------------------------+
          |              |              |              |
   [ChromaDB]    [PostgreSQL]    [Redis Queue]    [ChromaDB]
   (documents)   (structured     (job state,      (memory_{user_id}
                  goals, etc.)    events)          collection)
```

---

## 5. Technology Decisions

Lock these in BEFORE coding Phase G. They shape everything downstream.

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Agent framework** | **Pydantic AI** | Typed, minimal, matches FastAPI style. Avoid LangChain bloat — we already migrated away from it for chat. |
| **Memory architecture** | **Custom (~300 LOC)** | Already have ChromaDB + SQLAlchemy. Letta/Mem0 add vendor lock-in for no gain. |
| **Scheduler** | **APScheduler** | In-process, persistent job store, perfect for single-instance deployment. |
| **Structured extraction** | **Instructor library** | Pydantic-typed LLM outputs, automatic validation retries. |
| **Eval framework** | **Promptfoo** | Free, YAML-based, CI-friendly. Start early, not late. |
| **Embedding model** | **text-embedding-3-small** (keep) | Current model is sufficient until recall problems surface. |
| **Multi-tenancy** | **Add `org_id` column now, implement later** | Cheap now, expensive retrofit later. |
| **Event bus** | **In-process pub/sub first, Redis later** | Don't premature-optimize. Upgrade when needed. |
| **Secrets for OAuth** | **Fernet-encrypted in Postgres** | Refresh tokens are long-lived and high-value; never plaintext. |

---

## 6. Phase G — Memory & Identity Layer

**Goal:** The system knows who the user is, what org context they operate in, and remembers facts across sessions.

### 6.1 Data Models

```python
# app/models/identity.py

class UserProfile(Base):
    user_id: str (FK → users.id, PK)
    role: str                    # "Senior Developer", "Founder", etc.
    team: str | None
    responsibilities: Text       # Free-form
    working_hours: str           # "09:00-18:00 America/Los_Angeles"
    communication_style: str     # "terse", "detailed", "formal"
    created_at: datetime
    updated_at: datetime

class OrgContext(Base):
    id: str (UUID, PK)
    user_id: str (FK → users.id)
    org_name: str
    mission: Text
    current_quarter: str         # "Q2 2026"
    quarter_goals: Text          # Markdown list
    leadership_priorities: Text  # Markdown list
    team_okrs: Text              # Markdown list
    created_at: datetime
    updated_at: datetime

class MemoryFact(Base):
    id: str (UUID, PK)
    user_id: str (FK → users.id)
    fact: Text                   # "Dimang prefers pastel glassmorphism UI"
    source: str                  # "chat" | "inferred" | "explicit"
    confidence: float            # 0.0-1.0
    created_at: datetime
    last_accessed: datetime
    access_count: int
```

### 6.2 Memory Architecture

Following the MemGPT pattern:

```
CORE MEMORY (always in context, ~1KB)
  - UserProfile fields
  - OrgContext key goals
  - Currently active project/focus

ARCHIVAL MEMORY (searchable, unbounded)
  - MemoryFact rows in Postgres
  - Mirror: memory_{user_id} ChromaDB collection
    (vectorized facts for semantic recall)

EPISODIC MEMORY (compressed summaries)
  - Nightly job: summarize past day's chats
  - Store as MemoryFact with source="chat_summary"
```

### 6.3 Tools Added

```python
# New tools the LLM can call:

remember(fact: str, confidence: float = 0.8)
  -> Writes to MemoryFact table + ChromaDB

recall(query: str, limit: int = 5) -> list[MemoryFact]
  -> Semantic search over memory_{user_id} collection

forget(fact_id: str)
  -> Deletes fact (user-facing "forget about X")

update_profile(field: str, value: str)
  -> LLM can update UserProfile after learning new info
```

### 6.4 System Prompt Assembly

Every chat and agent run now builds its context like this:

```
[SYSTEM PROMPT TEMPLATE]

# Who you're helping
{UserProfile injected}

# Organizational context
{OrgContext injected}

# Relevant memories
{Top 5 MemoryFact rows from recall(user_query)}

# Relevant documents
{Top K chunks from ChromaDB RAG}

# Available tools
{Tool schemas}

# Conversation history
{Last N turns}
```

### 6.5 Phase G Tasks

```
Backend:
  1. Create UserProfile, OrgContext, MemoryFact models + migrations
  2. Create memory_{user_id} ChromaDB collection on user signup
  3. Implement remember(), recall(), forget(), update_profile() tools
  4. Implement MemoryLayer service (core/archival/episodic split)
  5. Update chat/rag_chain.py to inject memory into system prompt
  6. Nightly job stub: episodic summarization (triggered in Phase H)

Frontend:
  7. Settings screen: "Profile" tab (edit UserProfile fields)
  8. Settings screen: "Organization" tab (edit OrgContext)
  9. Settings screen: "Memory" tab (view/delete MemoryFact rows)
```

---

## 7. Phase H — Agentic Loop & Scheduling

**Goal:** The system acts on schedules and events, not just on user prompts. Proves the "proactive coworker" concept.

### 7.1 Scheduler

Install APScheduler with `SQLAlchemyJobStore` backed by the existing Postgres DB — jobs persist across restarts.

```python
# app/agents/scheduler.py

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.jobstores.sqlalchemy import SQLAlchemyJobStore

scheduler = AsyncIOScheduler(
    jobstores={"default": SQLAlchemyJobStore(url=DATABASE_URL)},
    timezone="America/Los_Angeles",
)

# Register jobs on app startup
scheduler.add_job(
    generate_daily_brief_for_all_users,
    trigger="cron",
    hour=8, minute=0,
    id="daily_brief",
    replace_existing=True,
)
```

### 7.2 Agent Runner

```python
# app/agents/runner.py

async def run_agent(
    agent_name: str,
    user_id: str,
    input_data: dict,
) -> AgentRunResult:
    """
    1. Load UserProfile, OrgContext, relevant memories
    2. Assemble system prompt
    3. Run Pydantic AI agent with tools
    4. Log run to AgentRun table
    5. Emit event on completion
    """
```

### 7.3 Daily Brief Agent

```python
# app/agents/daily_brief.py

class DailyBriefOutput(BaseModel):
    top_priorities: list[str]  # 3 items
    overnight_changes: list[str]
    due_today: list[FollowUp]
    suggested_plan: str  # markdown

async def generate_daily_brief(user_id: str) -> DailyBriefOutput:
    # 1. Pull context (profile, goals, calendar, open followups, yesterday's brief)
    # 2. Run Pydantic AI agent
    # 3. Write result to workspace tree: "Daily Briefs/YYYY-MM-DD.md"
    # 4. Push WebSocket notification
    # 5. Log to AgentRun
```

### 7.4 Event Bus

Simple in-process pub/sub to start. No Redis until needed.

```python
# app/agents/events.py

class EventBus:
    def subscribe(event_name: str, handler: Callable): ...
    async def publish(event_name: str, payload: dict): ...

# Events:
#   file.uploaded
#   file.embedded
#   meeting.transcript.ready
#   followup.due
#   calendar.event.starting_soon
```

### 7.5 AgentRun Log

```python
class AgentRun(Base):
    id: str (UUID, PK)
    user_id: str (FK)
    agent_name: str            # "daily_brief"
    trigger: str               # "scheduled" | "event" | "manual"
    input_payload: JSON
    output_payload: JSON
    tools_called: JSON         # list of tool_name + args
    status: str                # "running" | "success" | "failed"
    error_message: str | None
    duration_ms: int
    user_rating: int | None    # 1-5, for eval
    started_at: datetime
    completed_at: datetime
```

### 7.6 Phase H Tasks

```
Backend:
  1. Add apscheduler to requirements, wire into FastAPI lifespan
  2. Create AgentRun model + migration
  3. Implement EventBus (in-process)
  4. Implement agent runner abstraction
  5. Implement daily_brief agent with Pydantic AI
  6. Schedule daily_brief at 8:00am per user timezone
  7. WebSocket push for brief-ready notification
  8. Episodic memory summarization job (nightly at 2am)

Frontend:
  9. "Today" dashboard screen (Nav rail icon)
  10. Activity Feed screen showing AgentRun history
  11. Notification badge for brief-ready events
  12. Rating UI at end of each brief (1-5 stars)
```

---

## 8. Phase I — First Integration: Google Calendar

**Goal:** Prove the external-context-ingestion pattern with the highest-signal, lowest-noise source.

**Why Calendar first (not Slack):**
- Smallest API surface
- Highest signal density (one event = meaningful context)
- No firehose problem
- Easy OAuth flow

### 8.1 OAuth Flow

```
1. User clicks "Connect Google Calendar" in Settings
2. Redirect to Google OAuth consent screen
3. Callback to /api/v1/connectors/google/callback
4. Exchange code for tokens
5. Encrypt refresh_token with Fernet, store in OAuthCredential table
6. Initial sync: pull events for past 7 days + next 14 days
```

### 8.2 Data Model

```python
class OAuthCredential(Base):
    id: str (UUID, PK)
    user_id: str (FK)
    provider: str              # "google_calendar" | "gmail" | "slack"
    access_token: str          # encrypted
    refresh_token: str         # encrypted
    expires_at: datetime
    scopes: str
    created_at: datetime

class CalendarEvent(Base):
    id: str (UUID, PK)
    user_id: str (FK)
    provider_event_id: str     # Google's event ID
    title: str
    description: Text | None
    start_time: datetime
    end_time: datetime
    attendees: JSON            # list of emails
    location: str | None
    meeting_url: str | None
    synced_at: datetime
```

### 8.3 New Tools

```python
get_calendar_events(range: str = "today")
  -> Returns events in natural language + structured form
  -> Range: "today" | "this_week" | "next_week" | "YYYY-MM-DD"

find_free_slots(duration_minutes: int, date: str)
  -> Suggests open time blocks
```

### 8.4 Phase I Tasks

```
Backend:
  1. Add google-auth, google-api-python-client to requirements
  2. Create OAuthCredential model with Fernet encryption
  3. Create CalendarEvent model + migration
  4. Implement OAuth connector endpoints
  5. Implement CalendarSync service (periodic pull every 15 min via scheduler)
  6. Implement get_calendar_events and find_free_slots tools
  7. Update daily_brief agent to include calendar context

Frontend:
  8. Settings → Integrations tab
  9. "Connect Google Calendar" button + OAuth redirect handling
  10. Today dashboard: show today's events alongside brief
```

### 8.5 Future Integrations (Order of Priority)

Do NOT start these until Calendar is working and proven.

| Order | Integration | Why This Order |
|-------|-------------|----------------|
| 2 | **Gmail** | Second-highest signal; heavy filtering ("requires response" only) |
| 3 | **Meeting Transcripts** | Via Otter/Fireflies webhooks or Zoom API — extraction target for knowledge graph |
| 4 | **Slack** | Highest noise-to-signal ratio; build last, with aggressive filtering |

---

## 9. Phase J — Knowledge Graph (Lite)

**Goal:** Structured knowledge for goal-oriented reasoning. Vector chunks alone cannot reliably answer "what are my Q2 priorities?"

### 9.1 Data Models

```python
class Goal(Base):
    id: str (UUID, PK)
    user_id: str (FK)
    parent_id: str | None      # hierarchical (OKR → KR → task)
    level: str                 # "org" | "team" | "personal"
    title: str
    description: Text
    status: str                # "active" | "blocked" | "done" | "abandoned"
    priority: int              # 1-5
    due_date: date | None
    source: str                # "manual" | "extracted" | "meeting"
    source_ref: str | None     # TreeNode.id or AgentRun.id
    created_at: datetime

class Project(Base):
    id: str (UUID, PK)
    user_id: str (FK)
    goal_id: str | None (FK → Goal)
    name: str
    status: str
    ...

class Person(Base):
    id: str (UUID, PK)
    user_id: str (FK)
    name: str
    email: str | None
    role: str | None
    relationship: str          # "manager" | "report" | "peer" | "external"
    ...

class Decision(Base):
    id: str (UUID, PK)
    user_id: str (FK)
    title: str
    rationale: Text
    decided_at: date
    source_ref: str            # meeting transcript node_id
    related_goals: JSON        # list of Goal.id

class FollowUp(Base):
    id: str (UUID, PK)
    user_id: str (FK)
    description: str
    owner: str | None          # Person.id or free text
    due_date: date | None
    status: str                # "open" | "done" | "snoozed"
    source_ref: str
    related_goal: str | None (FK → Goal)
```

### 9.2 Extraction Pipeline

After any document, transcript, or chat with substantial content:

```python
# app/extraction/extractor.py

class ExtractionResult(BaseModel):
    goals: list[GoalExtracted]
    decisions: list[DecisionExtracted]
    followups: list[FollowUpExtracted]
    people: list[PersonExtracted]

async def extract_structured(content: str, source_ref: str, user_id: str):
    # 1. Run Instructor-wrapped LLM call with ExtractionResult schema
    # 2. Deduplicate against existing entities (fuzzy match on titles)
    # 3. Write new entities to Postgres
    # 4. Link source_ref for traceability
```

Trigger points:
- After a file is embedded (Phase B already does the trigger — add extraction step)
- After a meeting transcript is ingested
- After a chat conversation ends (summarization + extraction)

### 9.3 Hybrid Retrieval

Chat and agents now pull from BOTH vector and structured stores:

```python
# Pseudocode
async def retrieve_context(query: str, user_id: str) -> Context:
    vector_chunks = await chroma.similarity_search(query, k=5)
    active_goals = await db.query(Goal).filter_by(status="active")
    open_followups = await db.query(FollowUp).filter_by(status="open")
    relevant_decisions = await db.query(Decision).order_by(decided_at.desc()).limit(3)

    return Context(
        chunks=vector_chunks,
        goals=active_goals,
        followups=open_followups,
        decisions=relevant_decisions,
    )
```

### 9.4 New Tools

```python
get_goals(status: str = "active") -> list[Goal]
get_followups(owner: str | None = None, due_before: date | None = None) -> list[FollowUp]
get_decisions(since: date | None = None) -> list[Decision]
create_goal(title: str, description: str, priority: int, due_date: date | None)
mark_followup_done(followup_id: str)
```

### 9.5 Phase J Tasks

```
Backend:
  1. Create Goal, Project, Person, Decision, FollowUp models + migrations
  2. Install instructor library
  3. Implement extraction pipeline (Instructor + ExtractionResult schema)
  4. Wire extraction into ingestion pipeline + chat end-of-conversation hook
  5. Implement deduplication (fuzzy matching on titles/emails)
  6. Implement hybrid retrieval in rag_chain.py
  7. Implement get_goals, get_followups, etc. tools
  8. Update daily_brief to use structured goals + followups

Frontend:
  9. Nav rail icon: "Goals"
  10. Goals screen: tree view of hierarchical goals (editable)
  11. Today dashboard: show open followups
  12. Chat UI: goal/followup chips when LLM references them
```

---

## 10. Cross-Cutting — Eval & Trust

Build this alongside Phase H — do NOT defer to the end.

### 10.1 Promptfoo Harness

```yaml
# evals/daily_brief.yaml

prompts:
  - file://prompts/daily_brief.txt

providers:
  - openai:gpt-4o-mini

tests:
  - description: "Brief respects user's stated priorities"
    vars:
      profile: "Solo developer building RAG workspace"
      goals: "Ship v1 of workspace by end of Q2"
      calendar: "..."
    assert:
      - type: contains
        value: "workspace"
      - type: llm-rubric
        value: "Brief mentions the Q2 v1 ship deadline and gives concrete tasks"

  - description: "Brief does not hallucinate meetings"
    vars: {...}
    assert:
      - type: javascript
        value: "!output.includes('meeting') || calendarContainsMeeting(output)"
```

### 10.2 User Rating Loop

- Every brief ends with "⭐⭐⭐⭐⭐ Rate this brief"
- Rating stored on `AgentRun.user_rating`
- Weekly report: average rating, regression alerts
- Failed briefs (rating ≤ 2) become eval test cases automatically

### 10.3 Observability

- Log every agent run with: input, output, tools called, duration, rating
- Expose `/api/v1/admin/runs` dashboard endpoint
- Track per-tool latency and failure rate

---

## 11. First Week Plan (Executable Monday Morning)

| Day | Goal | Deliverable |
|-----|------|-------------|
| **Mon** | Start Phase G | UserProfile + OrgContext models, Settings UI, system prompt injection. "AI knows who I am." |
| **Tue** | Continue Phase G | Semantic memory store + `remember()` / `recall()` tools. "AI saves and recalls facts." |
| **Wed** | Start Phase H | APScheduler wired in + `generate_daily_brief()` job writes to workspace tree. "Daily brief appears in tree at 8am." |
| **Thu** | Start Phase I | Google Calendar OAuth + `get_calendar_events` tool. "Brief includes today's calendar." |
| **Fri** | Iterate | Use the brief for real. Take notes on what's broken. Log findings. |

**End of week success signal:** On Saturday morning, you open the app, see 5 brief files in `Daily Briefs/`, and at least 2 of them told you something useful you wouldn't have otherwise noticed.

---

## 12. Anti-Patterns to Avoid

| Anti-Pattern | Why It Fails |
|-------------|-------------|
| Build Slack integration first | Highest noise, hardest signal extraction, lowest ROI for time spent |
| Use LangChain agents | Already migrated away from LangChain; don't re-introduce the bloat |
| Parallel integrations before one proves value | Scope explosion, nothing ships |
| Skip eval harness until "later" | You lose the ability to detect regressions; prompt drift kills the system silently |
| Build all 5 layers fully before shipping | 3-month dead zone with no user value |
| Store OAuth refresh tokens in plaintext | Non-negotiable security failure |
| Forget the `org_id` column on new tables | Expensive retrofit when multi-tenancy arrives |
| Treat the brief as "just a prompt" | It's a product. Iterate on it like one. |

---

## 13. Success Criteria

The AI coworker is successful when:

1. User opens the app on Monday morning, sees a brief they didn't ask for, and it changes what they work on
2. User can ask "what did I decide about X last month?" and get a correct, sourced answer
3. User can say "remember that I prefer terse responses" and it sticks across sessions
4. User connects Google Calendar once and never thinks about it again
5. Weekly average brief rating is ≥ 4.0/5
6. User stops opening ChatGPT for work questions because this app answers them better

---

## 14. Summary

| Phase | Name | Purpose | Duration Estimate |
|-------|------|---------|-------------------|
| **G** | Memory & Identity | Persistent knowledge layer | Week 1–2 |
| **H** | Agentic Loop & Scheduling | Proactive behavior | Week 2–3 |
| **I** | Calendar Integration | First external context source | Week 3–4 |
| **J** | Knowledge Graph (Lite) | Structured reasoning | Week 4–6 |

**Future phases (not yet planned):** Gmail, meeting transcripts, Slack, multi-tenant org support, agent teams, mobile push notifications.

This plan transforms the app from **personal knowledge workspace with AI assistance** (current state) into a **proactive AI coworker that operates alongside the user** (target state).
