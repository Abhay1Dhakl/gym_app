from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, EmailStr, Field


class WorkoutExerciseInput(BaseModel):
    name: str
    sets: str
    reps: str
    rest_seconds: int | None = None
    target: str | None = None


class WorkoutDayInput(BaseModel):
    day_index: int
    title: str
    focus: str
    notes: str | None = None
    exercises: list[WorkoutExerciseInput]


class ProgramUpdateRequest(BaseModel):
    title: str
    phase: str
    goal: str
    summary: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    workout_days: list[WorkoutDayInput]


class NutritionUpdateRequest(BaseModel):
    calories: int
    protein: int
    carbs: int
    fats: int
    water_liters: float | None = None
    notes: str | None = None


class CreateClientRequest(BaseModel):
    full_name: str
    contact_email: EmailStr | None = None
    phone: str | None = None
    goal: str
    notes: str | None = None


class InvoiceCreateRequest(BaseModel):
    title: str
    amount_cents: int = Field(gt=0)
    due_date: date
    status: str = "pending"
    billing_period_start: date | None = None
    billing_period_end: date | None = None


class MessageCreateRequest(BaseModel):
    body: str = Field(min_length=1)


class SubscriptionUpdateRequest(BaseModel):
    plan_name: str
    monthly_price_cents: int = Field(gt=0)
    status: str = "active"
    started_at: date | None = None
    next_invoice_date: date | None = None
    notes: str | None = None


class MetricCreateRequest(BaseModel):
    body_weight: float | None = None
    squat_1rm: float | None = None
    bench_1rm: float | None = None
    deadlift_1rm: float | None = None
    adherence_score: int | None = Field(default=None, ge=0, le=100)
    energy_score: int | None = Field(default=None, ge=1, le=5)
    notes: str | None = None


class TemplateCreateFromClientRequest(BaseModel):
    client_id: int
    title: str | None = None


class TemplateApplyRequest(BaseModel):
    client_id: int
    start_date: date | None = None


class ChallengeCreateRequest(BaseModel):
    title: str
    description: str | None = None
    metric_type: str
    start_date: date
    end_date: date
    unit_label: str | None = None


class FormCheckReviewRequest(BaseModel):
    coach_feedback: str = Field(min_length=1)


class FormCheckCreateRequest(BaseModel):
    exercise_name: str
    video_url: str = Field(min_length=1)
    notes: str | None = None


class WorkoutExerciseResponse(BaseModel):
    id: int
    name: str
    sets: str
    reps: str
    rest_seconds: int | None
    target: str | None

    model_config = {"from_attributes": True}


class WorkoutDayResponse(BaseModel):
    id: int
    day_index: int
    title: str
    focus: str
    notes: str | None
    exercises: list[WorkoutExerciseResponse]

    model_config = {"from_attributes": True}


class ProgramResponse(BaseModel):
    id: int
    title: str
    phase: str
    goal: str
    summary: str | None
    start_date: date | None
    end_date: date | None
    workout_days: list[WorkoutDayResponse]

    model_config = {"from_attributes": True}


class ProgramTemplateExerciseResponse(BaseModel):
    id: int
    name: str
    sets: str
    reps: str
    rest_seconds: int | None
    target: str | None

    model_config = {"from_attributes": True}


class ProgramTemplateDayResponse(BaseModel):
    id: int
    day_index: int
    title: str
    focus: str
    notes: str | None
    exercises: list[ProgramTemplateExerciseResponse]

    model_config = {"from_attributes": True}


class ProgramTemplateResponse(BaseModel):
    id: int
    title: str
    phase: str
    goal: str
    summary: str | None
    duration_weeks: int
    workout_days: list[ProgramTemplateDayResponse]

    model_config = {"from_attributes": True}


class NutritionResponse(BaseModel):
    id: int
    calories: int
    protein: int
    carbs: int
    fats: int
    water_liters: float | None
    notes: str | None

    model_config = {"from_attributes": True}


class SubscriptionResponse(BaseModel):
    id: int
    plan_name: str
    monthly_price_cents: int
    status: str
    started_at: date
    next_invoice_date: date
    canceled_at: date | None
    notes: str | None

    model_config = {"from_attributes": True}


class CheckInResponse(BaseModel):
    id: int
    submitted_at: datetime
    body_weight: float | None
    sleep_score: int | None
    stress_score: int | None
    adherence_score: int | None
    notes: str | None

    model_config = {"from_attributes": True}


class MetricResponse(BaseModel):
    id: int
    logged_at: datetime
    body_weight: float | None
    squat_1rm: float | None
    bench_1rm: float | None
    deadlift_1rm: float | None
    adherence_score: int | None
    energy_score: int | None
    notes: str | None

    model_config = {"from_attributes": True}


class MessageResponse(BaseModel):
    id: int
    sender_role: str
    body: str
    created_at: datetime

    model_config = {"from_attributes": True}


class InvoiceResponse(BaseModel):
    id: int
    title: str
    amount_cents: int
    due_date: date
    billing_period_start: date | None
    billing_period_end: date | None
    status: str

    model_config = {"from_attributes": True}


class ProgressReportResponse(BaseModel):
    id: int
    period_start: date
    period_end: date
    summary: str
    body_weight_change: float | None
    squat_gain: float | None
    bench_gain: float | None
    deadlift_gain: float | None
    adherence_average: float | None
    checkins_completed: int
    generated_at: datetime


class NotificationResponse(BaseModel):
    id: int
    title: str
    body: str
    category: str
    read_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class ChallengeLeaderboardEntryResponse(BaseModel):
    client_id: int
    client_name: str
    score: float
    display_score: str
    rank: int


class ChallengeResponse(BaseModel):
    id: int
    title: str
    description: str | None
    metric_type: str
    start_date: date
    end_date: date
    unit_label: str | None
    leaderboard: list[ChallengeLeaderboardEntryResponse] = Field(default_factory=list)

    model_config = {"from_attributes": True}


class FormCheckResponse(BaseModel):
    id: int
    exercise_name: str
    video_url: str
    notes: str | None
    coach_feedback: str | None
    status: str
    reviewed_at: datetime | None
    submitted_at: datetime


class ClientSummaryResponse(BaseModel):
    id: int
    full_name: str
    contact_email: str | None
    phone: str | None
    goal: str
    status: str
    invite_code: str
    latest_checkin_at: datetime | None = None
    invoice_status: str | None = None
    subscription_status: str | None = None


class ClientDetailResponse(BaseModel):
    id: int
    full_name: str
    contact_email: str | None
    phone: str | None
    goal: str
    notes: str | None
    status: str
    invite_code: str
    program: ProgramResponse | None = None
    nutrition_plan: NutritionResponse | None = None
    subscription: SubscriptionResponse | None = None
    checkins: list[CheckInResponse]
    metrics: list[MetricResponse]
    messages: list[MessageResponse]
    invoices: list[InvoiceResponse]
    latest_progress_report: ProgressReportResponse | None = None
    form_checks: list[FormCheckResponse]


class AdminDashboardResponse(BaseModel):
    organization_name: str | None = None
    organization_logo_url: str | None = None
    total_clients: int
    active_clients: int
    invited_clients: int
    overdue_invoices: int
    active_subscriptions: int
    missing_checkin_notifications: int
    template_count: int
    latest_checkins: list[CheckInResponse]
    recent_messages: list[MessageResponse]
    active_challenge: ChallengeResponse | None = None
