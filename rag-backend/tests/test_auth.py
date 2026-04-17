import pytest


@pytest.mark.asyncio
async def test_register_success(client):
    response = await client.post("/api/v1/auth/register", json={
        "email": "new@example.com",
        "password": "password123",
        "name": "New User",
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.asyncio
async def test_register_duplicate_email(client):
    await client.post("/api/v1/auth/register", json={
        "email": "dup@example.com",
        "password": "password123",
        "name": "User One",
    })
    response = await client.post("/api/v1/auth/register", json={
        "email": "dup@example.com",
        "password": "password456",
        "name": "User Two",
    })
    assert response.status_code == 400
    assert "already registered" in response.json()["detail"]


@pytest.mark.asyncio
async def test_login_success(client):
    await client.post("/api/v1/auth/register", json={
        "email": "login@example.com",
        "password": "password123",
        "name": "Login User",
    })
    response = await client.post("/api/v1/auth/login", json={
        "email": "login@example.com",
        "password": "password123",
    })
    assert response.status_code == 200
    assert "access_token" in response.json()


@pytest.mark.asyncio
async def test_login_wrong_password(client):
    await client.post("/api/v1/auth/register", json={
        "email": "wrong@example.com",
        "password": "password123",
        "name": "Wrong User",
    })
    response = await client.post("/api/v1/auth/login", json={
        "email": "wrong@example.com",
        "password": "wrongpassword",
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_refresh_success(client):
    reg = await client.post("/api/v1/auth/register", json={
        "email": "refresh@example.com",
        "password": "password123",
        "name": "Refresh User",
    })
    refresh_token = reg.json()["refresh_token"]
    response = await client.post("/api/v1/auth/refresh", json={
        "refresh_token": refresh_token,
    })
    assert response.status_code == 200
    assert "access_token" in response.json()


@pytest.mark.asyncio
async def test_refresh_invalid_token(client):
    response = await client.post("/api/v1/auth/refresh", json={
        "refresh_token": "invalid.token.here",
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_register_validation_short_password(client):
    response = await client.post("/api/v1/auth/register", json={
        "email": "val@example.com",
        "password": "short",
        "name": "Val User",
    })
    assert response.status_code == 422
