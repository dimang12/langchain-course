from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite+aiosqlite:///./data/rag.db"
    REDIS_URL: str = "redis://localhost:6379/0"
    CHROMA_PATH: str = "./data/chroma"
    UPLOAD_DIR: str = "./data/uploads"
    ANTHROPIC_API_KEY: str = ""
    OPENAI_API_KEY: str = ""
    JWT_SECRET: str = "dev-secret-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Credential encryption (Fernet). In prod, set to a stable base64-encoded
    # 32-byte key. In dev, a random key is generated per-process if empty,
    # which means existing encrypted rows become unreadable after restart —
    # acceptable for local development only.
    CREDENTIAL_ENCRYPTION_KEY: str = ""

    # Google OAuth (Calendar connector). Leave empty to disable the
    # connector endpoints — server still boots, endpoints return 503.
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    GOOGLE_OAUTH_REDIRECT_URI: str = "http://localhost:8000/api/v1/connectors/google/callback"

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
