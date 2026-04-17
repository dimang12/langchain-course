# RAG Backend

FastAPI backend for the RAG Assistant — handles authentication, document ingestion, embedding, retrieval, and LLM-powered chat.

## Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env  # or copy from ../.env.example
# Set OPENAI_API_KEY in .env

# Run development server
uvicorn app.main:app --reload --port 8000
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| OPENAI_API_KEY | Yes | — | OpenAI API key for embeddings + chat |
| JWT_SECRET | No | dev-secret-... | Secret for signing JWT tokens |
| DATABASE_URL | No | sqlite+aiosqlite:///./data/rag.db | Database connection string |
| CHROMA_PATH | No | ./data/chroma | ChromaDB storage path |
| UPLOAD_DIR | No | ./data/uploads | Uploaded files directory |

## API Documentation

Start the server and visit http://localhost:8000/docs for interactive Swagger UI.

## Testing

```bash
# Run all tests
pytest tests/ -v

# Run specific test file
pytest tests/test_auth.py -v
```

## Docker

```bash
# Build and run with Docker Compose
docker compose up -d

# Check logs
docker compose logs -f api

# Stop
docker compose down
```

## Project Layout

```
app/
├── main.py          # FastAPI app, CORS, rate limiting
├── config.py        # Pydantic settings
├── database.py      # SQLAlchemy async engine
├── auth/
│   ├── router.py    # Register, login, refresh
│   └── jwt_handler.py  # Token create/verify
├── chat/
│   ├── router.py    # Query, stream, history
│   ├── rag_chain.py # LangChain RAG pipeline
│   └── prompts.py   # System prompts
├── ingestion/
│   ├── router.py    # Upload, sources, delete
│   ├── processor.py # Document parsing + chunking
│   └── embedder.py  # Embedding + ChromaDB storage
└── models/
    ├── user.py         # User model
    └── conversation.py # Conversation + Message models
```
