from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel

from app.schemas.admin import CheckInResponse, InvoiceResponse, MessageResponse, NutritionResponse, ProgramResponse


class ClientDashboardResponse(BaseModel):
    client_id: int
    client_name: str
    organization_name: str | None = None
    organization_logo_url: str | None = None
    goal: str
    status: str
    today_focus: str | None
    program: ProgramResponse | None
    nutrition_plan: NutritionResponse | None
    recent_checkins: list[CheckInResponse]
    recent_messages: list[MessageResponse]
    upcoming_invoices: list[InvoiceResponse]


class CheckInCreateRequest(BaseModel):
    body_weight: float | None = None
    sleep_score: int | None = None
    stress_score: int | None = None
    adherence_score: int | None = None
    notes: str | None = None


class ClientMessageCreateRequest(BaseModel):
    body: str


class ActivationHintResponse(BaseModel):
    invite_code: str
    client_name: str
    contact_email: str | None
    goal: str
    created_at: datetime
