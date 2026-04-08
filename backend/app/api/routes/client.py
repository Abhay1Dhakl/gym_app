from __future__ import annotations

from datetime import datetime, UTC

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_client_profile
from app.db.session import get_db
from app.models.entities import CheckIn, ClientProfile, Message, UserRole
from app.schemas.admin import CheckInResponse, InvoiceResponse, MessageResponse, NutritionResponse, ProgramResponse
from app.schemas.client import CheckInCreateRequest, ClientDashboardResponse, ClientMessageCreateRequest


router = APIRouter()


@router.get("/dashboard", response_model=ClientDashboardResponse)
def dashboard(profile: ClientProfile = Depends(get_current_client_profile)) -> ClientDashboardResponse:
    today_focus = profile.program.workout_days[0].focus if profile.program and profile.program.workout_days else None
    checkins = sorted(profile.checkins, key=lambda item: item.submitted_at, reverse=True)
    messages = sorted(profile.messages, key=lambda item: item.created_at, reverse=True)
    invoices = sorted(profile.invoices, key=lambda item: item.due_date)

    return ClientDashboardResponse(
        client_id=profile.id,
        client_name=profile.full_name,
        organization_name=profile.organization.name if profile.organization else None,
        organization_logo_url=profile.organization.logo_url if profile.organization else None,
        goal=profile.goal,
        status=profile.status.value,
        today_focus=today_focus,
        program=ProgramResponse.model_validate(profile.program) if profile.program else None,
        nutrition_plan=NutritionResponse.model_validate(profile.nutrition_plan) if profile.nutrition_plan else None,
        recent_checkins=[CheckInResponse.model_validate(item) for item in checkins[:4]],
        recent_messages=[MessageResponse.model_validate(item) for item in messages[:6]],
        upcoming_invoices=[InvoiceResponse.model_validate(item) for item in invoices[:4]],
    )


@router.get("/program", response_model=ProgramResponse | None)
def get_program(profile: ClientProfile = Depends(get_current_client_profile)) -> ProgramResponse | None:
    return ProgramResponse.model_validate(profile.program) if profile.program else None


@router.get("/nutrition", response_model=NutritionResponse | None)
def get_nutrition(profile: ClientProfile = Depends(get_current_client_profile)) -> NutritionResponse | None:
    return NutritionResponse.model_validate(profile.nutrition_plan) if profile.nutrition_plan else None


@router.get("/checkins", response_model=list[CheckInResponse])
def get_checkins(profile: ClientProfile = Depends(get_current_client_profile)) -> list[CheckInResponse]:
    return [CheckInResponse.model_validate(item) for item in sorted(profile.checkins, key=lambda item: item.submitted_at, reverse=True)]


@router.post("/checkins", response_model=CheckInResponse, status_code=status.HTTP_201_CREATED)
def create_checkin(
    payload: CheckInCreateRequest,
    profile: ClientProfile = Depends(get_current_client_profile),
    db: Session = Depends(get_db),
) -> CheckInResponse:
    checkin = CheckIn(
        client_id=profile.id,
        submitted_at=datetime.now(UTC),
        body_weight=payload.body_weight,
        sleep_score=payload.sleep_score,
        stress_score=payload.stress_score,
        adherence_score=payload.adherence_score,
        notes=payload.notes,
    )
    db.add(checkin)
    db.commit()
    db.refresh(checkin)
    return CheckInResponse.model_validate(checkin)


@router.get("/messages", response_model=list[MessageResponse])
def get_messages(profile: ClientProfile = Depends(get_current_client_profile)) -> list[MessageResponse]:
    return [MessageResponse.model_validate(item) for item in sorted(profile.messages, key=lambda item: item.created_at)]


@router.post("/messages", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def create_message(
    payload: ClientMessageCreateRequest,
    profile: ClientProfile = Depends(get_current_client_profile),
    db: Session = Depends(get_db),
) -> MessageResponse:
    message = Message(client_id=profile.id, sender_role=UserRole.CLIENT.value, body=payload.body)
    db.add(message)
    db.commit()
    db.refresh(message)
    return MessageResponse.model_validate(message)


@router.get("/invoices", response_model=list[InvoiceResponse])
def get_invoices(profile: ClientProfile = Depends(get_current_client_profile)) -> list[InvoiceResponse]:
    return [InvoiceResponse.model_validate(item) for item in sorted(profile.invoices, key=lambda item: item.due_date)]
