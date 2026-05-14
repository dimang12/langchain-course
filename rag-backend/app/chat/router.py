import json
import logging
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import get_current_user, verify_token
from app.database import get_db
from app.models.user import User
from app.models.conversation import Conversation, Message
from app.chat.rag_chain import RAGChain

logger = logging.getLogger(__name__)
router = APIRouter()


class QueryRequest(BaseModel):
    question: str
    conversation_id: str | None = None


@router.post("/query")
async def query(
    request: QueryRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from openai import AsyncOpenAI
    from app.tools.registry import WORKSPACE_TOOLS
    from app.tools.executor import execute_tool
    from app.config import settings
    from app.chat.prompts import SYSTEM_PROMPT
    from app.memory.service import MemoryLayer
    from app.models.knowledge import FollowUp, Goal

    if request.conversation_id:
        result = await db.execute(
            select(Conversation).where(
                Conversation.id == request.conversation_id,
                Conversation.user_id == user.id,
            )
        )
        conversation = result.scalar_one_or_none()
        if not conversation:
            raise HTTPException(status_code=404, detail="Conversation not found")
    else:
        conversation = Conversation(user_id=user.id, title=request.question[:50])
        db.add(conversation)
        await db.commit()
        await db.refresh(conversation)

    user_msg = Message(
        conversation_id=conversation.id,
        role="user",
        content=request.question,
    )
    db.add(user_msg)

    client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

    rag = RAGChain(user_id=user.id)
    retriever = rag.vectorstore.as_retriever(search_kwargs={"k": 5})
    docs = await retriever.ainvoke(request.question)
    context = "\n\n".join(doc.page_content for doc in docs)
    sources = list(dict.fromkeys(doc.metadata.get("source", "unknown") for doc in docs))

    memory = MemoryLayer(user_id=user.id, db=db)
    memory_block = await memory.build_context_for_query(request.question)

    # Active goals + open followups from knowledge graph
    goals_result = await db.execute(
        select(Goal)
        .where(Goal.user_id == user.id, Goal.status == "active")
        .order_by(Goal.priority)
        .limit(10)
    )
    active_goals = goals_result.scalars().all()

    followups_result = await db.execute(
        select(FollowUp)
        .where(FollowUp.user_id == user.id, FollowUp.status == "open")
        .order_by(FollowUp.due_date.asc().nullslast())
        .limit(10)
    )
    open_followups = followups_result.scalars().all()

    knowledge_lines: list[str] = []
    if active_goals:
        knowledge_lines.append("## Active Goals")
        for g in active_goals:
            due = f" (due {g.due_date.isoformat()})" if g.due_date else ""
            knowledge_lines.append(f"- [{g.level}/P{g.priority}] {g.title}{due}")
    if open_followups:
        knowledge_lines.append("\n## Open Follow-Ups")
        for f in open_followups:
            due = f" (due {f.due_date.isoformat()})" if f.due_date else ""
            owner = f" [{f.owner}]" if f.owner else ""
            knowledge_lines.append(f"- {f.description}{owner}{due}")

    system_content_parts = [SYSTEM_PROMPT]
    if memory_block:
        system_content_parts.append(memory_block)
    if knowledge_lines:
        system_content_parts.append("\n".join(knowledge_lines))
    if context:
        system_content_parts.append(f"## Relevant Document Context\n{context}")

    messages = [
        {"role": "system", "content": "\n\n".join(system_content_parts)},
        {"role": "user", "content": request.question},
    ]

    tool_actions = []

    try:
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            tools=WORKSPACE_TOOLS,
            tool_choice="auto",
            max_tokens=4096,
            temperature=0.3,
        )

        msg = response.choices[0].message
        max_rounds = 10

        while msg.tool_calls and max_rounds > 0:
            max_rounds -= 1
            messages.append(msg)
            for tool_call in msg.tool_calls:
                args = json.loads(tool_call.function.arguments)
                logger.info("Tool call: %s(%s)", tool_call.function.name, args)
                try:
                    tool_result = await execute_tool(
                        tool_call.function.name, args, user.id, db
                    )
                except Exception as tool_err:
                    logger.exception("Tool %s failed", tool_call.function.name)
                    tool_result = f"Error executing {tool_call.function.name}: {tool_err}"
                tool_actions.append({
                    "tool": tool_call.function.name,
                    "args": args,
                    "result": tool_result[:200],
                })
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": tool_result,
                })

            response = await client.chat.completions.create(
                model="gpt-4o-mini",
                messages=messages,
                tools=WORKSPACE_TOOLS,
                tool_choice="auto",
                max_tokens=4096,
                temperature=0.3,
            )
            msg = response.choices[0].message

        answer = msg.content or "I couldn't generate a response."
    except Exception as e:
        logger.exception("Chat query failed")
        answer = f"Sorry, something went wrong: {e}"

    assistant_msg = Message(
        conversation_id=conversation.id,
        role="assistant",
        content=answer,
        sources=sources,
    )
    db.add(assistant_msg)
    await db.commit()

    return {
        "answer": answer,
        "sources": sources,
        "conversation_id": conversation.id,
        "tool_actions": tool_actions,
    }


@router.get("/history")
async def get_history(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation)
        .where(Conversation.user_id == user.id)
        .order_by(Conversation.updated_at.desc())
    )
    conversations = result.scalars().all()
    return [
        {
            "id": c.id,
            "title": c.title,
            "created_at": c.created_at.isoformat(),
            "updated_at": c.updated_at.isoformat(),
        }
        for c in conversations
    ]


@router.get("/history/{conversation_id}")
async def get_conversation(
    conversation_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == user.id,
        )
    )
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    msg_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.created_at)
    )
    messages = msg_result.scalars().all()

    return {
        "id": conversation.id,
        "title": conversation.title,
        "messages": [
            {
                "id": m.id,
                "role": m.role,
                "content": m.content,
                "sources": m.sources,
                "created_at": m.created_at.isoformat(),
            }
            for m in messages
        ],
    }


@router.delete("/history/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == user.id,
        )
    )
    conversation = result.scalar_one_or_none()
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")

    await db.delete(conversation)
    await db.commit()
    return {"status": "deleted"}


@router.websocket("/stream")
async def stream(websocket: WebSocket):
    await websocket.accept()
    try:
        token = await websocket.receive_text()
        payload = verify_token(token, expected_type="access")
        user_id = payload["sub"]

        rag = RAGChain(user_id=user_id)

        while True:
            query_text = await websocket.receive_text()
            async for chunk in rag.stream(query_text):
                await websocket.send_text(
                    json.dumps({"type": "token", "data": chunk})
                )
            await websocket.send_text(
                json.dumps({"type": "done"})
            )
    except WebSocketDisconnect:
        pass
