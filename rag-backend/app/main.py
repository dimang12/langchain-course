from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.database import init_db
from app.auth.router import router as auth_router
from app.chat.router import router as chat_router
from app.ingestion.router import router as ingestion_router
from app.workspace.router import router as workspace_router
from app.tools.router import router as tools_router
from app.memory.router import router as memory_router
from app.agents.router import router as agents_router
from app.agents.scheduler import start_scheduler, shutdown_scheduler
from app.connectors.router import router as connectors_router
from app.knowledge.router import router as knowledge_router
import app.models  # noqa: F401

limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    start_scheduler()
    try:
        yield
    finally:
        shutdown_scheduler()


app = FastAPI(title="RAG Backend", version="0.7.0", lifespan=lifespan)
app.state.limiter = limiter


def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded. Try again later."})


app.add_exception_handler(RateLimitExceeded, rate_limit_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(chat_router, prefix="/api/v1/chat", tags=["chat"])
app.include_router(ingestion_router, prefix="/api/v1/ingestion", tags=["ingestion"])
app.include_router(workspace_router, prefix="/api/v1/workspace", tags=["workspace"])
app.include_router(tools_router, prefix="/api/v1/tools", tags=["tools"])
app.include_router(memory_router, prefix="/api/v1/memory", tags=["memory"])
app.include_router(agents_router, prefix="/api/v1/agents", tags=["agents"])
app.include_router(connectors_router, prefix="/api/v1/connectors", tags=["connectors"])
app.include_router(knowledge_router, prefix="/api/v1/knowledge", tags=["knowledge"])


@app.get("/health")
async def health():
    return {"status": "ok"}
