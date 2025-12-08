from pydantic import BaseModel
from functools import lru_cache
import os
from dotenv import load_dotenv

load_dotenv()

# TODO: 테스트/운영 서버에서는 default 값들 무조건 바꿔야 함
class Settings(BaseModel):
    mongo_uri: str = os.getenv("MONGO_URI", "mongodb://115.145.134.180:9013/")
    mongo_db: str = os.getenv("DB_NAME", "flutter_test")
    jwt_secret: str = os.getenv("JWT_SECRET", "CHANGE_ME_SECRET")
    jwt_refresh_secret: str = os.getenv("JWT_REFRESH_SECRET", "CHANGE_ME_REFRESH")
    access_token_expire_minutes: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
    refresh_token_expire_days: int = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "7"))
    email_verification_expire_minutes: int = int(os.getenv("EMAIL_VERIFICATION_EXPIRE_MINUTES", "30"))
    reset_token_expire_minutes: int = int(os.getenv("RESET_TOKEN_EXPIRE_MINUTES", "30"))
    api_port: int = int(os.getenv("API_PORT", "8050"))
    cors_origins: list[str] = os.getenv("CORS_ORIGINS", "http://localhost:56000,http://127.0.0.1:56000,http://localhost:*").split(",")

    smtp_host: str | None = os.getenv("SMTP_HOST")
    smtp_port: int | None = int(os.getenv("SMTP_PORT", "0")) if os.getenv("SMTP_PORT") else None
    smtp_user: str | None = os.getenv("SMTP_USER")
    smtp_password: str | None = os.getenv("SMTP_PASSWORD")
    email_from: str | None = os.getenv("EMAIL_FROM")

    # OpenAI 프록시용 설정 (키는 환경변수에서만 로드)
    openai_api_key: str | None = os.getenv("OPENAI_API_KEY")
    openai_model: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    openai_embedding_model: str = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-large")
    openai_api_base: str = os.getenv("OPENAI_API_BASE", "https://api.openai.com/v1")

@lru_cache
def get_settings() -> Settings:
    return Settings()
