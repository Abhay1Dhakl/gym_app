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


class MessageCreateRequest(BaseModel):
    body: str = Field(min_length=1)


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
    workout_days: list[WorkoutDayResponse]

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


class CheckInResponse(BaseModel):
    id: int
    submitted_at: datetime
    body_weight: float | None
    sleep_score: int | None
    stress_score: int | None
    adherence_score: int | None
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
    status: str

    model_config = {"from_attributes": True}


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
    checkins: list[CheckInResponse]
    messages: list[MessageResponse]
    invoices: list[InvoiceResponse]


class AdminDashboardResponse(BaseModel):
    organization_name: str | None = None
    organization_logo_url: str | None = None
    total_clients: int
    active_clients: int
    invited_clients: int
    overdue_invoices: int
    latest_checkins: list[CheckInResponse]
    recent_messages: list[MessageResponse]
