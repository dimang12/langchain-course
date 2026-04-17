from fastapi import APIRouter, Depends, HTTPException
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.auth.jwt_handler import (
    create_access_token,
    create_refresh_token,
    verify_token,
)

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str

    @classmethod
    def model_validate(cls, *args, **kwargs):
        return super().model_validate(*args, **kwargs)

    def __init__(self, **data):
        super().__init__(**data)
        if not self.email or not self.email.strip():
            raise ValueError("Email is required")
        if not self.password or len(self.password) < 6:
            raise ValueError("Password must be at least 6 characters")
        if not self.name or not self.name.strip():
            raise ValueError("Name is required")


class LoginRequest(BaseModel):
    email: str
    password: str

    def __init__(self, **data):
        super().__init__(**data)
        if not self.email or not self.email.strip():
            raise ValueError("Email is required")
        if not self.password:
            raise ValueError("Password is required")


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


@router.post("/register", response_model=TokenResponse)
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == request.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        email=request.email,
        name=request.name,
        hashed_password=pwd_context.hash(request.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return TokenResponse(
        access_token=create_access_token(user.id, user.email),
        refresh_token=create_refresh_token(user.id, user.email),
    )


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == request.email))
    user = result.scalar_one_or_none()

    if not user or not pwd_context.verify(request.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    return TokenResponse(
        access_token=create_access_token(user.id, user.email),
        refresh_token=create_refresh_token(user.id, user.email),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(request: RefreshRequest):
    payload = verify_token(request.refresh_token, expected_type="refresh")

    return TokenResponse(
        access_token=create_access_token(payload["sub"], payload["email"]),
        refresh_token=create_refresh_token(payload["sub"], payload["email"]),
    )
