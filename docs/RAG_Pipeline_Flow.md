# RAG Pipeline Flow

How documents go from upload to intelligent answers.

## Overview

```
UPLOAD          PROCESS              STORE           QUERY
  |                |                   |               |
  v                v                   v               v
[File] --> [Parse + Chunk] --> [Embed Vectors] --> [Search + LLM]
 .docx    800-token chunks   ChromaDB          Top 5 chunks
 .pdf     150 overlap        1536-dim vectors  + GPT-4o-mini
 .txt     metadata tagged    per-user collection  --> Answer
```

---

## Phase 1: Document Upload

```
User selects file (Flutter)
        |
        v
POST /api/v1/ingestion/upload
        |
        v
+-------------------------+
|  Save file to disk      |
|  data/uploads/{user}/   |
|  Create sources.json    |
|  Status: "pending"      |
+-----------+-------------+
            |
            v
   BackgroundTask triggered
```

**What happens:**
1. Flutter app opens a file picker (supports PDF, DOCX, TXT, HTML)
2. File is sent as multipart POST with JWT authentication
3. Backend saves the file to `data/uploads/{user_id}/`
4. A source entry is created in `sources.json` with status `"pending"`
5. A background task is triggered for processing

**Code:** `app/ingestion/router.py` → `POST /upload`

---

## Phase 2: Document Processing (Background)

### Step 2a: Parse

```
+---------------------------------------------+
|  PROCESSOR (app/ingestion/processor.py)     |
|                                             |
|  1. Parse file (PDF, DOCX, TXT, HTML)       |
|     -> unstructured.partition.auto          |
|                                             |
|  2. Join all elements into raw text         |
+---------------------------------------------+
```

The `unstructured` library automatically detects the file format and extracts text content. It handles:
- **PDF** — text extraction, OCR fallback
- **DOCX** — Word document parsing
- **TXT** — plain text reading
- **HTML** — tag stripping, content extraction

### Step 2b: Chunk

```
+---------------------------------------------+
|  3. Split into chunks                       |
|     -> RecursiveCharacterTextSplitter       |
|     -> chunk_size: 800 tokens               |
|     -> overlap: 150 tokens                  |
|     -> separators: ["\n\n", "\n", ". ", " "]|
|                                             |
|  Each chunk gets metadata:                  |
|    {source: "file.docx", user_id: "abc"}    |
|                                             |
|  Example: 1 document --> 52 chunks          |
+---------------------------------------------+
```

**Why chunk?**
- LLMs have context limits — we can't send the entire document
- Smaller chunks allow more precise retrieval
- 800 tokens (~600 words) balances precision and context
- 150-token overlap ensures no information is lost at boundaries

**Chunking example:**
```
Original document (4000 tokens):
[===============================================]

After chunking (800 tokens, 150 overlap):
[Chunk 1: tokens 0-800    ]
         [Chunk 2: tokens 650-1450  ]
                  [Chunk 3: tokens 1300-2100 ]
                           [Chunk 4: tokens 1950-2750]
                                    [Chunk 5: tokens 2600-3400]
                                             [Chunk 6: tokens 3250-4000]
```

### Step 2c: Embed & Store

```
+---------------------------------------------+
|  EMBEDDER (app/ingestion/embedder.py)       |
|                                             |
|  For each chunk:                            |
|    text --> OpenAI text-embedding-3-small    |
|          --> 1536-dimension vector           |
|                                             |
|  Store vectors in ChromaDB                  |
|    Collection: "user_{user_id}"             |
|    Path: data/chroma/                       |
|                                             |
|  Status updated: "complete"                 |
+---------------------------------------------+
```

**What is an embedding?**
An embedding converts text into a list of numbers (a vector) that captures the *meaning* of the text. Similar texts have similar vectors.

```
"Vibe coding is AI-driven development"
    --> [0.023, -0.041, 0.087, 0.015, ...] (1536 numbers)

"AI helps developers write code"
    --> [0.021, -0.038, 0.091, 0.012, ...] (similar vector!)

"The weather is sunny today"
    --> [-0.082, 0.054, -0.031, 0.067, ...] (very different vector)
```

**Storage:** Each user gets their own ChromaDB collection (`user_{user_id}`), ensuring complete data isolation between users.

---

## Phase 3: Query & Retrieval

```
User asks: "What is Vibe Coding?" (Flutter)
        |
        v
POST /api/v1/chat/query
        |
        v
+---------------------------------------------+
|  RAG CHAIN (app/chat/rag_chain.py)          |
|                                             |
|  Step 1: EMBED THE QUESTION                 |
|  "What is Vibe Coding?"                     |
|      --> OpenAI text-embedding-3-small      |
|      --> [0.023, -0.041, 0.087, ...] (1536d)|
|                                             |
|  Step 2: VECTOR SEARCH (Retrieval)          |
|  Compare question vector against all        |
|  stored chunk vectors using cosine          |
|  similarity. Return top 5 matches.          |
|                                             |
|  ChromaDB --> 5 most relevant chunks:       |
|  +-----------------------------------+      |
|  | Chunk 12: "Vibe coding is an       |     |
|  | AI-driven development workflow..." |      |
|  +-----------------------------------+      |
|  | Chunk 15: "The process involves    |     |
|  | a conversation loop between..."    |      |
|  +-----------------------------------+      |
|  | Chunk 8: "This approach allows     |     |
|  | for scalable and safe..."          |      |
|  +-----------------------------------+      |
|  | Chunk 20: "CRUD JSON payloads..."  |     |
|  +-----------------------------------+      |
|  | Chunk 3: "AI focuses on            |     |
|  | structured data rather than..."    |      |
|  +-----------------------------------+      |
|                                             |
|  Step 3: AUGMENT PROMPT                     |
|  +-----------------------------------+      |
|  | System: You are a helpful AI...    |     |
|  | Context: [5 chunks above]          |     |
|  | Chat History: [last 10 messages]   |     |
|  | Question: What is Vibe Coding?     |     |
|  +-----------------------------------+      |
|                                             |
|  Step 4: GENERATE (LLM)                     |
|  Send augmented prompt --> GPT-4o-mini      |
|      --> "Vibe coding is an AI-driven       |
|          development workflow where..."      |
|                                             |
|  Step 5: RETURN RESPONSE                    |
|  {                                          |
|    "answer": "Vibe coding is...",           |
|    "sources": ["Vibe_Coding_...docx"],      |
|    "conversation_id": "abc-123"             |
|  }                                          |
+---------------------------------------------+
        |
        v
  Flutter displays answer + source chip
```

### How Vector Search Works

```
Question vector:  [0.023, -0.041, 0.087, ...]
                         |
    Cosine similarity comparison with all stored chunks:
                         |
    Chunk 12: similarity = 0.94  <-- Most relevant
    Chunk 15: similarity = 0.91  <-- Very relevant
    Chunk 8:  similarity = 0.87  <-- Relevant
    Chunk 20: similarity = 0.83  <-- Somewhat relevant
    Chunk 3:  similarity = 0.80  <-- Somewhat relevant
    ...
    Chunk 45: similarity = 0.12  <-- Not relevant (ignored)
```

The top 5 chunks with highest similarity scores are selected and sent to the LLM as context.

---

## Key Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Chunk size | 800 tokens | ~600 words per chunk |
| Chunk overlap | 150 tokens | Context preserved at boundaries |
| Embedding model | text-embedding-3-small | 1536-dimension vectors |
| Vector DB | ChromaDB | Local, per-user collections |
| Retrieval k | 5 | Top 5 most similar chunks |
| LLM | GPT-4o-mini | Generates answers from context |
| Memory | 10 messages | Conversation history window |

---

## File Locations

| Component | Path |
|-----------|------|
| Uploaded files | `data/uploads/{user_id}/` |
| Source tracking | `data/uploads/{user_id}/sources.json` |
| Vector embeddings | `data/chroma/` |
| SQLite database | `data/rag.db` |

---

## What is RAG?

**R**etrieval-**A**ugmented **G**eneration is a technique that gives an LLM access to external knowledge without retraining it.

**Without RAG:**
```
User: "What is Vibe Coding?"
LLM:  "I don't have specific information about that."
```

**With RAG:**
```
User: "What is Vibe Coding?"
System: [retrieves relevant chunks from your documents]
LLM:  "Based on your documents, Vibe coding is an AI-driven
       development workflow where developers describe their
       desired UI in natural language..."
```

The LLM doesn't memorize your documents — it reads the most relevant parts on every question, just like a human would flip to the right page in a book.
