from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import os


BACKEND_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = BACKEND_ROOT / "data"
DATA_DIR.mkdir(exist_ok=True)


@dataclass(frozen=True)
class Settings:
    app_name: str = os.getenv("APP_NAME", "Abhay Method Platform API")
    app_env: str = os.getenv("APP_ENV", "development")
    secret_key: str = os.getenv("APP_SECRET_KEY", "change-this-in-production")
    cors_origins: str = os.getenv("APP_CORS_ORIGINS", "*")
    token_ttl_hours: int = int(os.getenv("APP_TOKEN_TTL_HOURS", "720"))
    database_url: str = os.getenv(
        "APP_DATABASE_URL",
        f"sqlite:///{(DATA_DIR / 'platform.db').as_posix()}",
    )


settings = Settings()
