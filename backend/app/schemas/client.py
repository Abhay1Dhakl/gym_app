from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel

from app.schemas.admin import (
    ChallengeResponse,
    CheckInResponse,
    FormCheckCreateRequest,
    FormCheckResponse,
    InvoiceResponse,
    MessageResponse,
    MetricCreateRequest,
    MetricResponse,
    NotificationResponse,
    NutritionResponse,
    ProgramResponse,
    ProgressReportResponse,
    SubscriptionResponse,
)


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
    subscription: SubscriptionResponse | None
    latest_metric: MetricResponse | None = None
    monthly_progress_report: ProgressReportResponse | None = None
    active_challenge: ChallengeResponse | None = None
    unread_notifications: int = 0
    recent_checkins: list[CheckInResponse]
    recent_messages: list[MessageResponse]
    upcoming_invoices: list[InvoiceResponse]
    recent_form_checks: list[FormCheckResponse]


class CheckInCreateRequest(BaseModel):
    body_weight: float | None = None
    sleep_score: int | None = None
    stress_score: int | None = None
    adherence_score: int | None = None
    notes: str | None = None


class ClientMetricCreateRequest(MetricCreateRequest):
    pass


class ClientMessageCreateRequest(BaseModel):
    body: str


class ClientFormCheckCreateRequest(FormCheckCreateRequest):
    pass


class ActivationHintResponse(BaseModel):
    invite_code: str
    client_name: str
    contact_email: str | None
    goal: str
    created_at: datetime
