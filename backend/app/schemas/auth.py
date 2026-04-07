from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class ActivateClientRequest(BaseModel):
    invite_code: str = Field(min_length=4, max_length=32)
    email: EmailStr
    password: str = Field(min_length=8)


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: int


class MeResponse(BaseModel):
    id: int
    email: EmailStr
    role: str
    client_id: int | None = None
    client_name: str | None = None
    expires_at: datetime | None = None
