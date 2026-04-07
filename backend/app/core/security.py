from __future__ import annotations

from datetime import datetime, timedelta, UTC
import hashlib
import secrets

import bcrypt

from app.core.config import settings


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


def generate_session_token() -> str:
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def token_expiry() -> datetime:
    return datetime.now(UTC) + timedelta(hours=settings.token_ttl_hours)


def generate_invite_code() -> str:
    return secrets.token_hex(4).upper()
