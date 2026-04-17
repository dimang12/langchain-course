# RAG Assistant

A cross-platform personalized AI assistant powered by Retrieval-Augmented Generation (RAG). Upload your documents and ask questions — the AI answers using your personal knowledge base.

## Architecture

```
FLUTTER FRONT-END (Single Codebase)
[Web]  [Android]  [iOS]  [macOS]  [Windows]
            |
      REST API + WebSocket
            |
PYTHON BACK-END (FastAPI)
[Auth]  [Ingestion]  [Embedding]  [Retrieval]  [LLM]
            |
[ChromaDB]      [PostgreSQL]      [Redis]
```

- **Frontend:** Flutter (Dart) — single codebase for 5 platforms
- **Backend:** FastAPI with LangChain RAG pipeline
- **LLM:** OpenAI GPT-4o-mini
- **Embeddings:** OpenAI text-embedding-3-small
- **Vector Store:** ChromaDB
- **Database:** SQLite (dev) / PostgreSQL (production)
- **Auth:** JWT with bcrypt password hashing

## Quick Start

### Prerequisites

- Python 3.10+
- Flutter SDK 3.22+
- Docker (optional, for production deployment)

### Backend Setup

```bash
cd rag-backend

# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp ../.env.example .env
# Edit .env and add your OPENAI_API_KEY

# Start the server
uvicorn app.main:app --reload --port 8000
```

The API is available at http://localhost:8000 with Swagger docs at http://localhost:8000/docs.

### Flutter Setup

```bash
cd rag_assistant

# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Run on macOS
flutter run -d macos
```

### Docker Deployment

```bash
# Configure production environment
cp rag-backend/.env.production.example rag-backend/.env
# Edit .env with your API keys

# Deploy with Docker
./scripts/deploy.sh
```

## Project Structure

```
langchain-course/
├── rag-backend/          # Python FastAPI backend
│   ├── app/
│   │   ├── main.py       # FastAPI app entry point
│   │   ├── config.py     # Environment settings
│   │   ├── database.py   # SQLAlchemy async setup
│   │   ├── auth/         # JWT authentication
│   │   ├── chat/         # RAG chat endpoints
│   │   ├── ingestion/    # Document upload & processing
│   │   └── models/       # SQLAlchemy models
│   ├── tests/            # Pytest integration tests
│   ├── Dockerfile
│   └── docker-compose.yml
├── rag_assistant/        # Flutter cross-platform app
│   ├── lib/
│   │   ├── core/         # API client, WebSocket, constants
│   │   ├── features/     # Auth, Chat, Data Sources, Settings
│   │   └── shared/       # Theme, reusable widgets
│   └── pubspec.yaml
├── scripts/              # Build & deploy scripts
└── .env.example          # Environment template
```

## API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/v1/auth/register | Create account |
| POST | /api/v1/auth/login | Login, get JWT tokens |
| POST | /api/v1/auth/refresh | Refresh access token |

### Chat
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/v1/chat/query | Send question, get RAG response |
| WS | /api/v1/chat/stream | Streaming chat via WebSocket |
| GET | /api/v1/chat/history | List conversations |
| GET | /api/v1/chat/history/:id | Get conversation messages |
| DELETE | /api/v1/chat/history/:id | Delete conversation |

### Data Ingestion
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/v1/ingestion/upload | Upload document |
| GET | /api/v1/ingestion/sources | List data sources |
| DELETE | /api/v1/ingestion/sources/:id | Delete source |
| GET | /api/v1/ingestion/status/:id | Check processing status |
| POST | /api/v1/ingestion/reindex | Re-process all sources |

## Testing

```bash
cd rag-backend
pytest tests/ -v
```

20 integration tests covering auth, chat, ingestion, and health endpoints. No API keys required — external services are mocked.

## Flutter Platforms

| Platform | Build Command | Output |
|----------|--------------|--------|
| Web | `flutter build web --release` | `build/web/` |
| Android | `flutter build appbundle --release` | `.aab` file |
| iOS | `flutter build ipa --release` | `.ipa` file |
| macOS | `flutter build macos --release` | `.app` bundle |
| Windows | `flutter build windows --release` | `.exe` |

## License

MIT
