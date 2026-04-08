from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class CreateGymAdminRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str = Field(min_length=8)
    gym_name: str
    gym_logo_url: str | None = None


class GymAdminSummaryResponse(BaseModel):
    id: int
    full_name: str | None = None
    email: EmailStr
    organization_id: int
    gym_name: str
    gym_logo_url: str | None = None
    active_clients: int
    invited_clients: int
    created_at: datetime


class SuperAdminDashboardResponse(BaseModel):
    total_gyms: int
    total_admins: int
    total_clients: int
    active_clients: int
    invited_clients: int
