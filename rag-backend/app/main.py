from fastapi import FastAPI

from app.auth.router import router as auth_router
from app.chat.router import router as chat_router
from app.ingestion.router import router as ingestion_router

app = FastAPI(title="RAG Backend", version="0.1.0")

app.include_router(auth_router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(chat_router, prefix="/api/v1/chat", tags=["chat"])
app.include_router(ingestion_router, prefix="/api/v1/ingestion", tags=["ingestion"])


@app.get("/health")
async def health():
    return {"status": "ok"}
