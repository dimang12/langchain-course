from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql://rag:rag@localhost:5432/rag"
    REDIS_URL: str = "redis://localhost:6379/0"
    CHROMA_PATH: str = "./data/chroma"
    UPLOAD_DIR: str = "./data/uploads"
    ANTHROPIC_API_KEY: str = ""
    OPENAI_API_KEY: str = ""

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
