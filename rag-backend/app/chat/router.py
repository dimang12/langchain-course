import json
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from app.chat.rag_chain import RAGChain

router = APIRouter()


class QueryRequest(BaseModel):
    question: str
    user_id: str = "default"


@router.post("/query")
async def query(request: QueryRequest):
    rag = RAGChain(user_id=request.user_id)
    result = await rag.query(request.question)
    return result


@router.websocket("/stream")
async def stream(websocket: WebSocket):
    await websocket.accept()
    try:
        user_id = await websocket.receive_text()
        rag = RAGChain(user_id=user_id)

        while True:
            query = await websocket.receive_text()
            async for chunk in rag.stream(query):
                await websocket.send_text(
                    json.dumps({"type": "token", "data": chunk})
                )
            await websocket.send_text(
                json.dumps({"type": "done"})
            )
    except WebSocketDisconnect:
        pass
