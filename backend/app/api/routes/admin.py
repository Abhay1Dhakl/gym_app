from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import desc, select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_admin_user
from app.core.security import generate_invite_code
from app.db.session import get_db
from app.models.entities import (
    ChallengeMetricType,
    CheckIn,
    ClientProfile,
    ClientStatus,
    ClientSubscription,
    CommunityChallenge,
    FormCheck,
    FormCheckStatus,
    Invoice,
    InvoiceStatus,
    Message,
    MetricEntry,
    NotificationCategory,
    NotificationRecord,
    NutritionPlan,
    ProgramTemplate,
    ProgramTemplateDay,
    ProgressReport,
    SubscriptionStatus,
    TrainingProgram,
    User,
    UserRole,
    WorkoutDay,
    WorkoutExercise,
)
from app.schemas.admin import (
    AdminDashboardResponse,
    ChallengeCreateRequest,
    ChallengeResponse,
    CheckInResponse,
    ClientDetailResponse,
    ClientSummaryResponse,
    CreateClientRequest,
    FormCheckResponse,
    FormCheckReviewRequest,
    InvoiceCreateRequest,
    InvoiceResponse,
    MessageCreateRequest,
    MessageResponse,
    MetricCreateRequest,
    MetricResponse,
    NutritionResponse,
    NutritionUpdateRequest,
    ProgramResponse,
    ProgramTemplateResponse,
    ProgramUpdateRequest,
    ProgressReportResponse,
    SubscriptionResponse,
    SubscriptionUpdateRequest,
    TemplateApplyRequest,
    TemplateCreateFromClientRequest,
)
from app.services.challenges import build_challenge_snapshot
from app.services.maintenance import run_platform_maintenance
from app.services.message_hub import message_hub
from app.services.program_templates import build_cycle_dates, clone_program_to_template, get_templates_for_organization, instantiate_program_from_template
from app.services.reports import serialize_report


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
            selectinload(ClientProfile.subscription),
            selectinload(ClientProfile.checkins),
            selectinload(ClientProfile.metrics),
            selectinload(ClientProfile.messages),
            selectinload(ClientProfile.invoices),
            selectinload(ClientProfile.progress_reports),
            selectinload(ClientProfile.form_checks),
        )
        .where(ClientProfile.id == client_id, ClientProfile.organization_id == organization_id)
    )


def _serialize_subscription(subscription: ClientSubscription | None) -> SubscriptionResponse | None:
    return SubscriptionResponse.model_validate(subscription) if subscription else None


def _serialize_progress_report(report: ProgressReport | None) -> ProgressReportResponse | None:
    payload = serialize_report(report)
    return ProgressReportResponse.model_validate(payload) if payload else None


def _serialize_form_check(form_check: FormCheck) -> FormCheckResponse:
    return FormCheckResponse(
        id=form_check.id,
        exercise_name=form_check.exercise_name,
        video_url=form_check.video_url,
        notes=form_check.notes,
        coach_feedback=form_check.coach_feedback,
        status=form_check.status.value if hasattr(form_check.status, "value") else str(form_check.status),
        reviewed_at=form_check.reviewed_at,
        submitted_at=form_check.created_at,
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
        subscription_status=client.subscription.status.value if client.subscription else None,
    )


def _latest_report(client: ClientProfile) -> ProgressReport | None:
    return max(client.progress_reports, key=lambda item: item.period_start, default=None)


@router.get("/dashboard", response_model=AdminDashboardResponse)
def dashboard(
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> AdminDashboardResponse:
    organization_id = admin_user.organization_id
    run_platform_maintenance(db, organization_id=organization_id)

    clients = db.scalars(
        select(ClientProfile)
        .options(
            selectinload(ClientProfile.checkins),
            selectinload(ClientProfile.invoices),
            selectinload(ClientProfile.subscription),
            selectinload(ClientProfile.notifications),
        )
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
    active_challenge_payload = build_challenge_snapshot(db, organization_id)

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
        active_subscriptions=sum(
            1
            for client in clients
            if client.subscription and client.subscription.status.value in {"active", "trialing"}
        ),
        missing_checkin_notifications=sum(
            1
            for client in clients
            for notification in client.notifications
            if notification.category == NotificationCategory.CHECKIN_REMINDER and notification.read_at is None
        ),
        template_count=len(get_templates_for_organization(db, organization_id)),
        latest_checkins=[CheckInResponse.model_validate(item) for item in latest_checkins],
        recent_messages=[MessageResponse.model_validate(item) for item in recent_messages],
        active_challenge=ChallengeResponse.model_validate(active_challenge_payload)
        if active_challenge_payload
        else None,
    )


@router.get("/clients", response_model=list[ClientSummaryResponse])
def list_clients(
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> list[ClientSummaryResponse]:
    run_platform_maintenance(db, organization_id=admin_user.organization_id)
    clients = db.scalars(
        select(ClientProfile)
        .options(
            selectinload(ClientProfile.checkins),
            selectinload(ClientProfile.invoices),
            selectinload(ClientProfile.subscription),
        )
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
    run_platform_maintenance(db, organization_id=admin_user.organization_id)
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
        subscription=_serialize_subscription(client.subscription),
        checkins=[CheckInResponse.model_validate(item) for item in sorted(client.checkins, key=lambda item: item.submitted_at, reverse=True)],
        metrics=[MetricResponse.model_validate(item) for item in sorted(client.metrics, key=lambda item: item.logged_at, reverse=True)],
        messages=[MessageResponse.model_validate(item) for item in sorted(client.messages, key=lambda item: item.created_at)],
        invoices=[InvoiceResponse.model_validate(item) for item in sorted(client.invoices, key=lambda item: item.due_date, reverse=True)],
        latest_progress_report=_serialize_progress_report(_latest_report(client)),
        form_checks=[_serialize_form_check(item) for item in sorted(client.form_checks, key=lambda item: item.created_at, reverse=True)],
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


@router.get("/clients/{client_id}/progress-report", response_model=ProgressReportResponse | None)
def get_client_progress_report(
    client_id: int,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> ProgressReportResponse | None:
    run_platform_maintenance(db, organization_id=admin_user.organization_id)
    client = db.scalar(_client_detail_query(client_id, admin_user.organization_id))
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")
    return _serialize_progress_report(_latest_report(client))


@router.get("/templates", response_model=list[ProgramTemplateResponse])
def list_templates(
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> list[ProgramTemplateResponse]:
    templates = get_templates_for_organization(db, admin_user.organization_id)
    return [ProgramTemplateResponse.model_validate(template) for template in templates]


@router.post("/templates/from-client", response_model=ProgramTemplateResponse, status_code=status.HTTP_201_CREATED)
def create_template_from_client(
    payload: TemplateCreateFromClientRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> ProgramTemplateResponse:
    client = db.scalar(_client_detail_query(payload.client_id, admin_user.organization_id))
    if not client or not client.program:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client program not found")

    template = clone_program_to_template(
        db,
        admin_user.organization_id,
        client.program,
        payload.title or f"{client.full_name} Template",
    )
    template = db.scalar(
        select(ProgramTemplate)
        .options(
            selectinload(ProgramTemplate.workout_days).selectinload(ProgramTemplateDay.exercises)
        )
        .where(ProgramTemplate.id == template.id)
    ) or template
    return ProgramTemplateResponse.model_validate(template)


@router.post("/templates/{template_id}/apply", response_model=ProgramResponse)
def apply_template(
    template_id: int,
    payload: TemplateApplyRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> ProgramResponse:
    template = db.scalar(
        select(ProgramTemplate)
        .options(
            selectinload(ProgramTemplate.workout_days).selectinload(ProgramTemplateDay.exercises)
        )
        .where(
            ProgramTemplate.id == template_id,
            ProgramTemplate.organization_id == admin_user.organization_id,
        )
    )
    if not template:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")

    client = db.scalar(_client_detail_query(payload.client_id, admin_user.organization_id))
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    program = instantiate_program_from_template(template, client.id, payload.start_date)
    client.program = program
    db.add(client)
    db.commit()
    db.refresh(program)
    return ProgramResponse.model_validate(program)


@router.get("/challenge", response_model=ChallengeResponse | None)
def get_active_challenge(
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> ChallengeResponse | None:
    payload = build_challenge_snapshot(db, admin_user.organization_id)
    return ChallengeResponse.model_validate(payload) if payload else None


@router.post("/challenge", response_model=ChallengeResponse, status_code=status.HTTP_201_CREATED)
def create_challenge(
    payload: ChallengeCreateRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> ChallengeResponse:
    challenge = CommunityChallenge(
        organization_id=admin_user.organization_id,
        title=payload.title,
        description=payload.description,
        metric_type=ChallengeMetricType(payload.metric_type),
        start_date=payload.start_date,
        end_date=payload.end_date,
        unit_label=payload.unit_label,
    )
    db.add(challenge)
    db.commit()
    payload_dict = build_challenge_snapshot(db, admin_user.organization_id)
    if payload_dict is None or payload_dict["id"] != challenge.id:
        payload_dict = {
            "id": challenge.id,
            "title": challenge.title,
            "description": challenge.description,
            "metric_type": challenge.metric_type.value,
            "start_date": challenge.start_date,
            "end_date": challenge.end_date,
            "unit_label": challenge.unit_label,
            "leaderboard": [],
        }
    return ChallengeResponse.model_validate(payload_dict)


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

    cycle_start, cycle_end = (
        (payload.start_date, payload.end_date)
        if payload.start_date and payload.end_date
        else build_cycle_dates(payload.start_date, 4)
    )
    program = client.program or TrainingProgram(client_id=client.id, title=payload.title, phase=payload.phase, goal=payload.goal)
    program.title = payload.title
    program.phase = payload.phase
    program.goal = payload.goal
    program.summary = payload.summary
    program.start_date = cycle_start
    program.end_date = cycle_end
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


@router.put("/clients/{client_id}/subscription", response_model=SubscriptionResponse)
def upsert_subscription(
    client_id: int,
    payload: SubscriptionUpdateRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> SubscriptionResponse:
    client = db.scalar(
        select(ClientProfile)
        .options(selectinload(ClientProfile.subscription))
        .where(ClientProfile.id == client_id, ClientProfile.organization_id == admin_user.organization_id)
    )
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    subscription = client.subscription or ClientSubscription(
        client_id=client.id,
        plan_name=payload.plan_name,
        monthly_price_cents=payload.monthly_price_cents,
        started_at=payload.started_at or datetime.now(UTC).date(),
        next_invoice_date=payload.next_invoice_date or datetime.now(UTC).date(),
    )
    subscription.plan_name = payload.plan_name
    subscription.monthly_price_cents = payload.monthly_price_cents
    subscription.status = SubscriptionStatus(payload.status)
    subscription.started_at = payload.started_at or subscription.started_at
    subscription.next_invoice_date = payload.next_invoice_date or subscription.next_invoice_date
    subscription.notes = payload.notes
    client.subscription = subscription

    db.add(client)
    db.commit()
    db.refresh(subscription)
    return SubscriptionResponse.model_validate(subscription)


@router.post("/clients/{client_id}/metrics", response_model=MetricResponse, status_code=status.HTTP_201_CREATED)
def create_metric(
    client_id: int,
    payload: MetricCreateRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> MetricResponse:
    client = db.scalar(
        select(ClientProfile).where(
            ClientProfile.id == client_id,
            ClientProfile.organization_id == admin_user.organization_id,
        )
    )
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    metric = MetricEntry(
        client_id=client.id,
        logged_at=datetime.now(UTC),
        body_weight=payload.body_weight,
        squat_1rm=payload.squat_1rm,
        bench_1rm=payload.bench_1rm,
        deadlift_1rm=payload.deadlift_1rm,
        adherence_score=payload.adherence_score,
        energy_score=payload.energy_score,
        notes=payload.notes,
    )
    db.add(metric)
    db.commit()
    db.refresh(metric)
    return MetricResponse.model_validate(metric)


@router.get("/clients/{client_id}/form-checks", response_model=list[FormCheckResponse])
def list_form_checks(
    client_id: int,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> list[FormCheckResponse]:
    client = db.scalar(_client_detail_query(client_id, admin_user.organization_id))
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")
    return [_serialize_form_check(item) for item in sorted(client.form_checks, key=lambda item: item.created_at, reverse=True)]


@router.put("/clients/{client_id}/form-checks/{form_check_id}", response_model=FormCheckResponse)
def review_form_check(
    client_id: int,
    form_check_id: int,
    payload: FormCheckReviewRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> FormCheckResponse:
    client = db.scalar(_client_detail_query(client_id, admin_user.organization_id))
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    form_check = next((item for item in client.form_checks if item.id == form_check_id), None)
    if not form_check:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Form check not found")

    form_check.coach_feedback = payload.coach_feedback
    form_check.status = FormCheckStatus.REVIEWED
    form_check.reviewed_at = datetime.now(UTC)
    client.notifications.append(
        NotificationRecord(
            organization_id=client.organization_id,
            title=f"{form_check.exercise_name} form review ready",
            body="Your coach reviewed the latest exercise video and added feedback.",
            category=NotificationCategory.FORM_CHECK,
        )
    )
    db.add(client)
    db.commit()
    db.refresh(form_check)
    return _serialize_form_check(form_check)


@router.post("/clients/{client_id}/invoices", response_model=InvoiceResponse, status_code=status.HTTP_201_CREATED)
def create_invoice(
    client_id: int,
    payload: InvoiceCreateRequest,
    admin_user: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db),
) -> InvoiceResponse:
    client = db.scalar(
        select(ClientProfile)
        .options(selectinload(ClientProfile.subscription))
        .where(
            ClientProfile.id == client_id,
            ClientProfile.organization_id == admin_user.organization_id,
        )
    )
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    invoice = Invoice(
        client_id=client.id,
        subscription_id=client.subscription.id if client.subscription else None,
        title=payload.title,
        amount_cents=payload.amount_cents,
        due_date=payload.due_date,
        billing_period_start=payload.billing_period_start,
        billing_period_end=payload.billing_period_end,
        status=InvoiceStatus(payload.status),
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
