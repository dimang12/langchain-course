import pytest
from unittest.mock import patch, MagicMock
import io


@pytest.mark.asyncio
async def test_ingestion_upload_unauthenticated(client):
    response = await client.post("/api/v1/ingestion/upload")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_ingestion_sources_empty(auth_client):
    response = await auth_client.get("/api/v1/ingestion/sources")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_ingestion_upload_success(auth_client):
    with patch("app.ingestion.router._process_document"):
        file_content = b"This is a test document with some content."
        response = await auth_client.post(
            "/api/v1/ingestion/upload",
            files={"file": ("test.txt", io.BytesIO(file_content), "text/plain")},
        )
    assert response.status_code == 200
    data = response.json()
    assert "job_id" in data
    assert data["filename"] == "test.txt"


@pytest.mark.asyncio
async def test_ingestion_sources_after_upload(auth_client):
    with patch("app.ingestion.router._process_document"):
        file_content = b"Test document."
        await auth_client.post(
            "/api/v1/ingestion/upload",
            files={"file": ("doc.txt", io.BytesIO(file_content), "text/plain")},
        )
    response = await auth_client.get("/api/v1/ingestion/sources")
    assert response.status_code == 200
    sources = response.json()
    assert len(sources) >= 1
    assert sources[0]["filename"] == "doc.txt"


@pytest.mark.asyncio
async def test_ingestion_delete_nonexistent(auth_client):
    response = await auth_client.delete("/api/v1/ingestion/sources/fake-id")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_ingestion_status_nonexistent(auth_client):
    response = await auth_client.get("/api/v1/ingestion/status/fake-id")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_ingestion_sources_unauthenticated(client):
    response = await client.get("/api/v1/ingestion/sources")
    assert response.status_code in (401, 403)
