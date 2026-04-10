from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_admin_user
from app.core.security import generate_invite_code
from app.db.session import get_db
from app.models.entities import (
    CheckIn,
    ClientProfile,
    ClientStatus,
    Invoice,
    InvoiceStatus,
    Message,
    NutritionPlan,
    TrainingProgram,
    User,
    UserRole,
    WorkoutDay,
    WorkoutExercise,
)
from app.services.message_hub import message_hub
from app.schemas.admin import (
    AdminDashboardResponse,
    CheckInResponse,
    ClientDetailResponse,
    ClientSummaryResponse,
    CreateClientRequest,
    InvoiceCreateRequest,
    InvoiceResponse,
    MessageCreateRequest,
    MessageResponse,
    NutritionResponse,
    NutritionUpdateRequest,
    ProgramResponse,
    ProgramUpdateRequest,
)


router = APIRouter()


def _client_detail_query(client_id: int, organization_id: int):
    return (
        select(ClientProfile)
        .options(
            selectinload(ClientProfile.organization),
            selectinload(ClientProfile.program)
            .selectinload(TrainingProgram.workout_days)
            .selectinload(WorkoutDay.exercises),
            selectinload(ClientProfile.nutrition_plan),
            selectinload(ClientProfile.checkins),
            selectinload(ClientProfile.messages),
            selectinload(ClientProfile.invoices),
        )
        .where(ClientProfile.id == client_id, ClientProfile.organization_id == organization_id)
    )


def _serialize_client_summary(client: ClientProfile) -> ClientSummaryResponse:
    latest_checkin = max(client.checkins, key=lambda item: item.submitted_at, default=None)
    latest_invoice = max(client.invoices, key=lambda item: item.due_date, default=None)
    return ClientSummaryResponse(
        id=client.id,
        full_name=client.full_name,
        contact_email=client.contact_email,
        phone=client.phone,
        goal=client.goal,
        status=client.status.value if hasattr(client.status, "value") else str(client.status),
        invite_code=client.invite_code,
        latest_checkin_at=latest_checkin.submitted_at if latest_checkin else None,
        invoice_status=latest_invoice.status.value if latest_invoice else None,
    )


@router.get("/dashboard", response_model=AdminDashboardResponse)
def dashboard(
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> AdminDashboardResponse:
    organization_id = admin_user.organization_id
    clients = db.scalars(
        select(ClientProfile)
        .options(selectinload(ClientProfile.checkins), selectinload(ClientProfile.invoices))
        .where(ClientProfile.organization_id == organization_id)
        .order_by(ClientProfile.created_at.desc())
    ).all()
    latest_checkins = db.scalars(
        select(CheckIn)
        .join(ClientProfile, CheckIn.client_id == ClientProfile.id)
        .where(ClientProfile.organization_id == organization_id)
        .order_by(desc(CheckIn.submitted_at))
        .limit(5)
    ).all()
    recent_messages = db.scalars(
        select(Message)
        .join(ClientProfile, Message.client_id == ClientProfile.id)
        .where(ClientProfile.organization_id == organization_id)
        .order_by(desc(Message.created_at))
        .limit(5)
    ).all()

    return AdminDashboardResponse(
        organization_name=admin_user.organization.name if admin_user.organization else None,
        organization_logo_url=admin_user.organization.logo_url if admin_user.organization else None,
        total_clients=len(clients),
        active_clients=sum(1 for client in clients if client.status == ClientStatus.ACTIVE),
        invited_clients=sum(1 for client in clients if client.status == ClientStatus.INVITED),
        overdue_invoices=sum(
            1
            for client in clients
            for invoice in client.invoices
            if invoice.status == InvoiceStatus.OVERDUE
        ),
        latest_checkins=[CheckInResponse.model_validate(item) for item in latest_checkins],
        recent_messages=[MessageResponse.model_validate(item) for item in recent_messages],
    )


@router.get("/clients", response_model=list[ClientSummaryResponse])
def list_clients(
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> list[ClientSummaryResponse]:
    clients = db.scalars(
        select(ClientProfile)
        .options(selectinload(ClientProfile.checkins), selectinload(ClientProfile.invoices))
        .where(ClientProfile.organization_id == admin_user.organization_id)
        .order_by(ClientProfile.created_at.desc())
    ).all()
    return [_serialize_client_summary(client) for client in clients]


@router.post("/clients", response_model=ClientSummaryResponse, status_code=status.HTTP_201_CREATED)
def create_client(
    payload: CreateClientRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> ClientSummaryResponse:
    invite_code = generate_invite_code()
    while db.scalar(select(ClientProfile).where(ClientProfile.invite_code == invite_code)):
        invite_code = generate_invite_code()

    client = ClientProfile(
        full_name=payload.full_name,
        contact_email=payload.contact_email,
        phone=payload.phone,
        goal=payload.goal,
        notes=payload.notes,
        invite_code=invite_code,
        status=ClientStatus.INVITED,
        organization_id=admin_user.organization_id,
    )
    db.add(client)
    db.commit()
    db.refresh(client)
    return _serialize_client_summary(client)


@router.get("/clients/{client_id}", response_model=ClientDetailResponse)
def get_client_detail(
    client_id: int,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> ClientDetailResponse:
    client = db.scalar(_client_detail_query(client_id, admin_user.organization_id))
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    return ClientDetailResponse(
        id=client.id,
        full_name=client.full_name,
        contact_email=client.contact_email,
        phone=client.phone,
        goal=client.goal,
        notes=client.notes,
        status=client.status.value,
        invite_code=client.invite_code,
        program=ProgramResponse.model_validate(client.program) if client.program else None,
        nutrition_plan=NutritionResponse.model_validate(client.nutrition_plan) if client.nutrition_plan else None,
        checkins=[CheckInResponse.model_validate(item) for item in sorted(client.checkins, key=lambda item: item.submitted_at, reverse=True)],
        messages=[MessageResponse.model_validate(item) for item in sorted(client.messages, key=lambda item: item.created_at)],
        invoices=[InvoiceResponse.model_validate(item) for item in sorted(client.invoices, key=lambda item: item.due_date, reverse=True)],
    )


@router.get("/clients/{client_id}/messages", response_model=list[MessageResponse])
def get_client_messages(
    client_id: int,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> list[MessageResponse]:
    client = db.scalar(
        select(ClientProfile)
        .options(selectinload(ClientProfile.messages))
        .where(
            ClientProfile.id == client_id,
            ClientProfile.organization_id == admin_user.organization_id,
        )
    )
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    return [
        MessageResponse.model_validate(item)
        for item in sorted(client.messages, key=lambda item: item.created_at)
    ]


@router.put("/clients/{client_id}/program", response_model=ProgramResponse)
def upsert_program(
    client_id: int,
    payload: ProgramUpdateRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> ProgramResponse:
    client = db.scalar(_client_detail_query(client_id, admin_user.organization_id))
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    program = client.program or TrainingProgram(client_id=client.id, title=payload.title, phase=payload.phase, goal=payload.goal)
    program.title = payload.title
    program.phase = payload.phase
    program.goal = payload.goal
    program.summary = payload.summary
    program.workout_days.clear()

    for day_payload in payload.workout_days:
        day = WorkoutDay(
            day_index=day_payload.day_index,
            title=day_payload.title,
            focus=day_payload.focus,
            notes=day_payload.notes,
        )
        for exercise_payload in day_payload.exercises:
            day.exercises.append(
                WorkoutExercise(
                    name=exercise_payload.name,
                    sets=exercise_payload.sets,
                    reps=exercise_payload.reps,
                    rest_seconds=exercise_payload.rest_seconds,
                    target=exercise_payload.target,
                )
            )
        program.workout_days.append(day)

    client.program = program
    db.add(client)
    db.commit()
    db.refresh(program)
    return ProgramResponse.model_validate(program)


@router.put("/clients/{client_id}/nutrition", response_model=NutritionResponse)
def upsert_nutrition(
    client_id: int,
    payload: NutritionUpdateRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> NutritionResponse:
    client = db.scalar(
        select(ClientProfile)
        .options(selectinload(ClientProfile.nutrition_plan))
        .where(ClientProfile.id == client_id, ClientProfile.organization_id == admin_user.organization_id)
    )
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    plan = client.nutrition_plan or NutritionPlan(client_id=client.id, calories=payload.calories, protein=payload.protein, carbs=payload.carbs, fats=payload.fats)
    plan.calories = payload.calories
    plan.protein = payload.protein
    plan.carbs = payload.carbs
    plan.fats = payload.fats
    plan.water_liters = payload.water_liters
    plan.notes = payload.notes
    client.nutrition_plan = plan

    db.add(client)
    db.commit()
    db.refresh(plan)
    return NutritionResponse.model_validate(plan)


@router.post("/clients/{client_id}/invoices", response_model=InvoiceResponse, status_code=status.HTTP_201_CREATED)
def create_invoice(
    client_id: int,
    payload: InvoiceCreateRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> InvoiceResponse:
    client = db.scalar(
        select(ClientProfile).where(
            ClientProfile.id == client_id,
            ClientProfile.organization_id == admin_user.organization_id,
        )
    )
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    invoice = Invoice(
        client_id=client.id,
        title=payload.title,
        amount_cents=payload.amount_cents,
        due_date=payload.due_date,
        status=payload.status,
    )
    db.add(invoice)
    db.commit()
    db.refresh(invoice)
    return InvoiceResponse.model_validate(invoice)


@router.post("/clients/{client_id}/messages", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def create_message(
    client_id: int,
    payload: MessageCreateRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> MessageResponse:
    client = db.scalar(
        select(ClientProfile).where(
            ClientProfile.id == client_id,
            ClientProfile.organization_id == admin_user.organization_id,
        )
    )
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    message = Message(client_id=client.id, sender_role=UserRole.ADMIN.value, body=payload.body)
    db.add(message)
    db.commit()
    db.refresh(message)
    response = MessageResponse.model_validate(message)
    await message_hub.broadcast(client.id, response.model_dump(mode="json"))
    return response
