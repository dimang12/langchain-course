# Knowledge Workspace — Implementation Plan

> Transform the RAG Assistant from a simple chat app into an Obsidian-like knowledge workspace with integrated AI chatbot.

---

## 1. High-Level Architecture

```
+------------------------------------------------------------------+
|  KNOWLEDGE WORKSPACE (Flutter)                                    |
|                                                                   |
|  +--------+ +------------------+ +-----------------------------+  |
|  |  Main  | |   Sidebar        | |   Content Area              |  |
|  |  Nav   | |   (Tree View)    | |   (Tabbed Documents)        |  |
|  |  Bar   | |                  | |                             |  |
|  | [Files]| | > Architecture   | |  [Tab1] [Tab2] [Chat] [+]  |  |
|  | [Srch] | |   > Auth         | |  +---------------------------+|
|  | [Chat] | |     RAG_Flow.md  | |  |                           ||
|  | [Tools]| |   > Notes        | |  | # RAG Pipeline Flow       ||
|  | [Sett] | |     meeting.md   | |  |                           ||
|  |        | | > Daily Reports  | |  | How documents go from     ||
|  |        | |   2026-04-08.md  | |  | upload to answers...      ||
|  |        | | > Uploads        | |  |                           ||
|  |        | |   report.pdf     | |  |                           ||
|  |        | |   data.csv       | |  |                           ||
|  |        | |                  | |  |                           ||
|  |        | | [+ New] [Import] | |  |                           ||
|  +--------+ +------------------+ |  +---------------------------+|
|                                  |          [💬 ChatBot FAB]     |
|                                  +-----------------------------+  |
+------------------------------------------------------------------+
          |                    |
    REST API + WS        Tool Protocol
          |                    |
+------------------------------------------------------------------+
|  BACKEND (FastAPI)                                                |
|  [Auth] [Files/Tree] [Ingestion] [RAG] [Tools] [LLM]            |
+------------------------------------------------------------------+
          |                    |
   [ChromaDB]  [SQLite/PostgreSQL]  [External Tools via MCP/Functions]
```

---

## 2. UI Layout — Detailed Breakdown

### 2.1 Main Navigation Bar (Far Left — Icon Rail)

A narrow vertical bar with icons, similar to VS Code / Obsidian:

```
+--------+
| [📄]   |  Files (tree view) — DEFAULT
| [🔍]   |  Search
| [💬]   |  Chat (opens chat panel)
| [🔧]   |  Tools (MCP/function tools)
|        |
|        |
|        |
| [⚙️]   |  Settings
| [👤]   |  User profile / logout
+--------+
```

**Behavior:**
- Clicking an icon switches what the sidebar shows
- Files icon → tree view (default)
- Chat icon → opens chat as floating window or tab (user preference)
- Tools icon → shows available tools/integrations

### 2.2 Sidebar (Tree View Panel)

```
+------------------------+
| WORKSPACE         [≡]  |  <-- Sort menu (name, date, type)
+------------------------+
| [+ New ▾] [📥 Import]  |  <-- New (file/folder), Import button
+------------------------+
| > 📁 Architecture      |
|   > 📁 Auth            |
|     📄 RAG_Flow.md     |
|     📄 JWT_Auth.md     |
| > 📁 Daily Reports     |
|   📄 2026-04-08.md     |
| > 📁 Uploads           |  <-- Auto-populated from ingestion
|   📄 report.pdf    ✓   |  <-- ✓ = processed/embedded
|   📄 data.csv      ⏳  |  <-- ⏳ = processing
|   📄 image.png     —   |  <-- — = not embeddable
| 📄 Quick Notes.md      |
+------------------------+
| 📂 Drop files here     |  <-- Drag-and-drop zone
+------------------------+
```

**Features:**
- **New button dropdown:** New File (.md), New Folder
- **Import button:** Opens file picker (same as current upload)
- **Drag-and-drop:** Drop files onto a folder or the drop zone
- **Sort options:** By name (A-Z), date modified, file type
- **Auto-reveal:** Clicking a tab highlights the file in tree (optional toggle)
- **Right-click context menu:** Rename, Delete, Move, Copy path, Reprocess (re-embed)
- **Status icons:** ✓ embedded, ⏳ processing, ✕ failed, — not applicable
- **Collapse/expand:** Click folder to toggle, remember state

### 2.3 Content Area (Tabbed Interface)

```
+-----------------------------------------------+
| [Tab1.md ×] [report.pdf ×] [💬 Chat ×] [+]   |
+-----------------------------------------------+
|                                                |
|  Content renders based on file type:           |
|                                                |
|  .md   → Markdown rendered (with edit toggle)  |
|  .txt  → Plain text viewer                     |
|  .pdf  → PDF viewer (embedded)                 |
|  .docx → Extracted text rendered as markdown   |
|  .csv  → Table view                            |
|  Chat  → Chat interface (same as current)      |
|                                                |
+-----------------------------------------------+
```

**Features:**
- **Multiple tabs:** Open multiple files simultaneously
- **Close tabs:** Click × on tab
- **Tab reordering:** Drag tabs to reorder
- **Active tab highlight:** Current tab visually distinct
- **Chat as tab:** Chat can be opened as a tab in the content area
- **New tab (+):** Opens empty markdown file or file picker
- **Unsaved indicator:** Dot on tab title when file has unsaved changes

### 2.4 ChatBot — Dual Mode

**Mode 1: Floating Window (Default)**
```
+----------------------------------+
|  Main Content Area               |
|                                  |
|                                  |
|                  +-------------+ |
|                  | 💬 Chat     | |
|                  | ----------- | |
|                  | Hi!         | |
|                  |     Hello!  | |
|                  |             | |
|                  | [Ask...]  ⬆ | |
|                  +-------------+ |
|                       [💬]       |  <-- FAB to toggle
+----------------------------------+
```
- Draggable, resizable floating panel
- Always on top of content
- FAB (bottom-right) toggles visibility
- Remembers position and size

**Mode 2: Tab**
```
+-----------------------------------------------+
| [Tab1.md ×] [💬 Chat ×] [+]                   |
+-----------------------------------------------+
|                                                |
|  Full-width chat interface                     |
|  (same as current chat screen)                 |
|                                                |
+-----------------------------------------------+
```
- Opens as a regular tab
- Full width for comfortable chatting
- User chooses mode in Settings

**Mode Toggle:** Settings → Chat Mode → "Floating Window" / "Tab"

---

## 3. Data Model

### 3.1 Tree Node Structure

```
Backend: app/models/workspace.py

class TreeNode (SQLAlchemy):
    id: str (UUID)
    user_id: str (FK → users.id)
    parent_id: str | None (FK → tree_nodes.id, null = root)
    name: str
    type: "file" | "folder"
    file_type: str | None ("md", "pdf", "docx", "txt", "csv", null for folders)
    content: Text | None (for .md and .txt files — stored in DB)
    file_path: str | None (for uploaded binary files — path on disk)
    ingestion_status: "none" | "pending" | "processing" | "complete" | "failed" | None
    ingestion_id: str | None (links to sources.json entry)
    sort_order: int (for manual ordering)
    created_at: datetime
    updated_at: datetime
```

**Relationships:**
```
TreeNode (parent_id) → TreeNode (id)    -- self-referential tree
TreeNode (user_id)   → User (id)        -- ownership
```

**Key Design Decisions:**
- Markdown/text content stored directly in DB (fast editing)
- Binary files (PDF, DOCX) stored on disk, path in DB
- Tree structure via `parent_id` (adjacency list — simple, good enough)
- `sort_order` for manual drag reordering within a folder
- `ingestion_status` tracks whether file has been embedded into ChromaDB

### 3.2 Tab State

```
Frontend only (Riverpod state, not persisted to DB):

class TabItem:
    id: str
    nodeId: str | None (null for chat tab)
    type: "file" | "chat"
    title: str
    isModified: bool
    scrollPosition: double
```

### 3.3 Updated API Endpoints

```
EXISTING (keep):
  POST   /api/v1/auth/register
  POST   /api/v1/auth/login
  POST   /api/v1/auth/refresh
  POST   /api/v1/chat/query
  WS     /api/v1/chat/stream
  GET    /api/v1/chat/history
  GET    /api/v1/chat/history/:id
  DELETE /api/v1/chat/history/:id

NEW — Workspace Tree:
  GET    /api/v1/workspace/tree           -- Full tree for user
  POST   /api/v1/workspace/node           -- Create file or folder
  PUT    /api/v1/workspace/node/:id       -- Update (rename, move, reorder)
  DELETE /api/v1/workspace/node/:id       -- Delete node (and children)
  GET    /api/v1/workspace/node/:id       -- Get node with content
  PUT    /api/v1/workspace/node/:id/content  -- Save file content

NEW — File Upload (replaces ingestion/upload):
  POST   /api/v1/workspace/upload         -- Upload file into tree
  POST   /api/v1/workspace/node/:id/embed -- Trigger embedding for a node

NEW — Tools (MCP/Function Calling):
  GET    /api/v1/tools                    -- List available tools
  POST   /api/v1/tools/:tool_id/execute   -- Execute a tool
```

---

## 4. Feature Details

### 4.1 Tree View Operations

| Operation | How It Works |
|-----------|-------------|
| **New File** | Click [+ New] → "File" → Creates `Untitled.md` in current folder, opens in tab for editing |
| **New Folder** | Click [+ New] → "Folder" → Creates `New Folder` in current folder, name editable inline |
| **Rename** | Double-click name or right-click → Rename → Inline text edit |
| **Delete** | Right-click → Delete → Confirm dialog → Removes node + children + embeddings |
| **Move** | Drag node onto folder → PUT /workspace/node/:id with new parent_id |
| **Reorder** | Drag within same folder → Updates sort_order for affected nodes |
| **Import** | Click [Import] → File picker → Upload → Create node in current folder |
| **Drag-drop upload** | Drop file onto tree/folder → Upload + create node |

### 4.2 File Content Rendering

| File Type | Rendering | Editable |
|-----------|-----------|----------|
| `.md` | Markdown rendered (flutter_markdown) | Yes — toggle edit/preview |
| `.txt` | Plain text | Yes |
| `.pdf` | PDF viewer widget | No (read-only) |
| `.docx` | Extracted text as markdown | No (read-only) |
| `.csv` | Table/grid view | No (read-only) |
| Chat | Chat interface | N/A |

### 4.3 Upload & Embedding Flow

```
User drops file onto tree
        |
        v
POST /workspace/upload (file + parent_folder_id)
        |
        v
+----------------------------------+
| 1. Save file to disk             |
| 2. Create TreeNode in DB         |
|    (type: file, status: pending) |
| 3. Background: parse + chunk +   |
|    embed into ChromaDB           |
| 4. Update status: complete       |
+----------------------------------+
        |
        v
Tree shows: report.pdf ✓
User can now ask questions about it in Chat
```

### 4.4 Chat Integration with Workspace

The chat now has **workspace context**:
- User can reference files: "Summarize the report.pdf"
- Chat knows which files are embedded and available
- Source chips in responses link back to tree nodes (click to open in tab)
- Context menu on files: "Ask AI about this file"

### 4.5 Tool Protocol (Function Calling)

The "tool protocol" Dimang mentioned is **Function Calling** (OpenAI) or **MCP** (Model Context Protocol). This lets the LLM call external tools.

**Architecture:**
```
User: "Summarize my report and create a new note with the summary"
        |
        v
LLM receives available tools:
  - read_file(node_id) → reads file content
  - create_file(name, content, parent_id) → creates new file
  - search_files(query) → searches across workspace
  - embed_file(node_id) → triggers embedding
  - web_search(query) → searches the web
        |
        v
LLM decides to call:
  1. read_file("report-id") → gets content
  2. [LLM generates summary]
  3. create_file("Summary.md", summary, "notes-folder-id")
        |
        v
Result: New file appears in tree!
```

**Available Tools (Phase 1):**

| Tool | Description | Parameters |
|------|-------------|------------|
| `read_file` | Read content of a workspace file | `node_id` |
| `create_file` | Create new file in workspace | `name`, `content`, `parent_id` |
| `search_files` | Search file names and content | `query` |
| `list_folder` | List contents of a folder | `folder_id` |
| `embed_file` | Trigger RAG embedding for a file | `node_id` |

**Available Tools (Phase 2 — Future):**

| Tool | Description |
|------|-------------|
| `web_search` | Search the internet |
| `run_code` | Execute Python code snippets |
| `fetch_url` | Fetch and parse a URL |
| `calendar` | Read/create calendar events |

**Backend Implementation:**
```python
# app/tools/registry.py

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the content of a file in the user's workspace",
            "parameters": {
                "type": "object",
                "properties": {
                    "node_id": {"type": "string", "description": "The file node ID"}
                },
                "required": ["node_id"]
            }
        }
    },
    # ... more tools
]

# app/tools/executor.py
async def execute_tool(tool_name: str, args: dict, user_id: str) -> str:
    if tool_name == "read_file":
        return await read_file_content(args["node_id"], user_id)
    elif tool_name == "create_file":
        return await create_workspace_file(args, user_id)
    # ...
```

**RAG Chain Update:**
```python
# Updated chat flow with tools:
# 1. User asks question
# 2. Retrieve relevant chunks from ChromaDB (existing RAG)
# 3. Send to LLM with: context + tools available
# 4. If LLM calls a tool → execute it → send result back to LLM
# 5. LLM generates final response
# 6. Return answer + sources + any tool actions taken
```

---

## 5. Implementation Phases

### Phase A: Workspace Layout (Week 1-2)
**Goal:** Basic Obsidian-like shell with tree + tabs

```
Tasks:
  1. Create WorkspaceScreen (replaces ChatScreen as home)
  2. Implement NavigationRail (icon bar on left)
  3. Implement TreeView sidebar (using flutter_fancy_tree_view or custom)
  4. Implement TabBar content area
  5. Integrate existing ChatScreen as a tab option
  6. Add ChatBot FAB (floating action button) for floating mode
  7. Settings toggle: Chat mode (floating vs tab)

Backend:
  8. Create TreeNode model + migration
  9. Create workspace router (CRUD for tree nodes)
  10. GET /workspace/tree endpoint (returns full tree)

Data:
  - Migrate existing uploaded files into tree nodes
```

### Phase B: File Management (Week 2-3)
**Goal:** Full file operations in the tree

```
Tasks:
  1. New File / New Folder buttons
  2. Rename (inline editing in tree)
  3. Delete with confirmation
  4. Drag-and-drop reordering within folder
  5. Drag-and-drop moving between folders
  6. Right-click context menu
  7. File import (file picker → upload → create node)
  8. Drag-and-drop file upload onto tree
  9. Sort options (name, date, type)

Backend:
  10. POST /workspace/upload (creates node + triggers embedding)
  11. PUT /workspace/node/:id (rename, move, reorder)
  12. Wire existing ingestion pipeline to tree nodes
```

### Phase C: Content Rendering (Week 3-4)
**Goal:** Open and view files in tabs

```
Tasks:
  1. Markdown viewer/editor (toggle mode)
  2. Plain text viewer/editor
  3. PDF viewer (using flutter_pdfview or similar)
  4. DOCX rendered as markdown (backend extracts text)
  5. CSV table viewer
  6. Tab management (open, close, reorder, active state)
  7. Auto-save for editable files
  8. "Save" indicator on modified tabs

Backend:
  9. GET /workspace/node/:id (returns content)
  10. PUT /workspace/node/:id/content (saves content)
  11. Endpoint to extract text from binary files for preview
```

### Phase D: Chat Integration (Week 4-5)
**Goal:** Chat aware of workspace context

```
Tasks:
  1. Floating chat window (draggable, resizable)
  2. Chat as tab (full width)
  3. Mode toggle in settings
  4. Source chips in chat → click to open file in tab
  5. Context menu on files: "Ask AI about this"
  6. Chat knows which files are embedded

Backend:
  7. Update RAG chain to include workspace context
  8. Chat endpoint returns node_ids in sources (not just file paths)
```

### Phase E: Tool Protocol (Week 5-7)
**Goal:** LLM can perform actions via function calling

```
Tasks:
  1. Define tool registry (available tools + schemas)
  2. Implement tool executor (routes tool calls to handlers)
  3. Implement core tools: read_file, create_file, search_files, list_folder
  4. Update RAG chain to support tool use (OpenAI function calling)
  5. Show tool actions in chat UI (e.g., "Created Summary.md")
  6. Tools panel in sidebar (shows available tools, usage history)

Backend:
  7. app/tools/registry.py (tool definitions)
  8. app/tools/executor.py (tool execution)
  9. app/tools/handlers/ (individual tool implementations)
  10. Update chat router to handle tool call loops
```

### Phase F: Polish & Advanced (Week 7-8)
**Goal:** Smooth experience, edge cases

```
Tasks:
  1. Search across all files (full-text + semantic)
  2. Auto-reveal current file in tree
  3. Keyboard shortcuts (Cmd+N new file, Cmd+S save, etc.)
  4. Breadcrumb navigation in content area
  5. File type icons in tree
  6. Loading states and error handling
  7. Responsive layout (collapse sidebar on small screens)
  8. Persist workspace state (open tabs, sidebar width, chat position)
```

---

## 6. Technology Choices

| Component | Technology | Why |
|-----------|-----------|-----|
| Tree View | `flutter_fancy_tree_view` | Performant, supports drag-drop, well maintained |
| Tab Bar | Custom `TabBar` + `PageView` | Flutter built-in, flexible |
| Markdown | `flutter_markdown` (existing) | Already in project |
| PDF Viewer | `flutter_pdfview` or `syncfusion_flutter_pdfviewer` | Native PDF rendering |
| Drag-Drop | `flutter_draggable` + `DropTarget` | Flutter built-in drag system |
| Floating Chat | `Stack` + `Positioned` + `GestureDetector` | Draggable overlay widget |
| Tool Protocol | OpenAI Function Calling | Native to GPT-4o-mini, well documented |
| Rich Text Editor | `flutter_quill` (optional, Phase F) | For WYSIWYG markdown editing |

---

## 7. Data Migration

The existing system has:
- Files in `data/uploads/{user_id}/`
- Source tracking in `sources.json` per user
- Embeddings in ChromaDB collections `user_{user_id}`

**Migration strategy:**
1. Create root folder node for each existing user
2. Create file nodes for each existing source in sources.json
3. Link file_path to existing upload paths
4. Copy ingestion_status from sources.json
5. ChromaDB collections remain untouched (already per-user)
6. Delete sources.json after migration

---

## 8. File Structure (New/Modified)

```
rag-backend/
  app/
    models/
      workspace.py          # NEW — TreeNode model
    workspace/
      __init__.py           # NEW
      router.py             # NEW — Tree CRUD + upload endpoints
      service.py            # NEW — Tree operations logic
    tools/
      __init__.py           # NEW
      registry.py           # NEW — Tool definitions
      executor.py           # NEW — Tool execution router
      handlers/
        file_tools.py       # NEW — read, create, search, list
    chat/
      rag_chain.py          # MODIFIED — add tool support

rag_assistant/
  lib/
    features/
      workspace/
        screens/
          workspace_screen.dart     # NEW — Main workspace layout
        widgets/
          tree_view.dart            # NEW — File tree sidebar
          tab_bar.dart              # NEW — Content tab bar
          content_viewer.dart       # NEW — File content renderer
          floating_chat.dart        # NEW — Draggable chat overlay
          context_menu.dart         # NEW — Right-click menu
        providers/
          workspace_provider.dart   # NEW — Tree state
          tab_provider.dart         # NEW — Tab state
        models/
          tree_node_model.dart      # NEW — TreeNode data class
          tab_model.dart            # NEW — Tab data class
```

---

## 9. Summary

| Phase | What | Duration | Deliverable |
|-------|------|----------|-------------|
| **A** | Workspace Layout | Week 1-2 | Shell with tree + tabs + chat FAB |
| **B** | File Management | Week 2-3 | Full CRUD on tree, drag-drop, upload |
| **C** | Content Rendering | Week 3-4 | View/edit files in tabs (md, pdf, txt, csv) |
| **D** | Chat Integration | Week 4-5 | Floating/tab chat, workspace-aware AI |
| **E** | Tool Protocol | Week 5-7 | LLM calls tools (read, create, search files) |
| **F** | Polish | Week 7-8 | Search, shortcuts, responsive, persistence |

This transforms the app from a **chat-with-docs tool** into a **personal knowledge workspace with AI assistance** — like Obsidian + ChatGPT combined.
