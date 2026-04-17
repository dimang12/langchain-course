import pytest
from unittest.mock import AsyncMock, patch, MagicMock


@pytest.mark.asyncio
async def test_chat_query_unauthenticated(client):
    response = await client.post("/api/v1/chat/query", json={"question": "hi"})
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_chat_query_success(auth_client):
    mock_retriever = MagicMock()
    mock_retriever.ainvoke = AsyncMock(return_value=[])

    mock_vectorstore = MagicMock()
    mock_vectorstore.as_retriever.return_value = mock_retriever

    mock_chain_instance = MagicMock()
    mock_chain_instance.vectorstore = mock_vectorstore

    mock_completion = MagicMock()
    mock_completion.choices = [MagicMock()]
    mock_completion.choices[0].message.tool_calls = None
    mock_completion.choices[0].message.content = "Hello! How can I help?"

    with patch("app.chat.router.RAGChain", return_value=mock_chain_instance), \
         patch("openai.AsyncOpenAI") as MockOpenAI:
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_completion)
        MockOpenAI.return_value = mock_client

        response = await auth_client.post("/api/v1/chat/query", json={"question": "hi"})

    assert response.status_code == 200
    data = response.json()
    assert "answer" in data
    assert "conversation_id" in data
    assert "tool_actions" in data


@pytest.mark.asyncio
async def test_chat_history_empty(auth_client):
    response = await auth_client.get("/api/v1/chat/history")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_chat_history_unauthenticated(client):
    response = await client.get("/api/v1/chat/history")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_chat_delete_nonexistent(auth_client):
    response = await auth_client.delete("/api/v1/chat/history/nonexistent-id")
    assert response.status_code == 404
