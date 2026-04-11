from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_client_profile
from app.db.session import get_db
from app.models.entities import CheckIn, FormCheck, FormCheckStatus, Message, MetricEntry, NotificationRecord, UserRole
from app.schemas.admin import (
    ChallengeResponse,
    CheckInResponse,
    FormCheckResponse,
    InvoiceResponse,
    MessageResponse,
    MetricResponse,
    NotificationResponse,
    NutritionResponse,
    ProgramResponse,
    ProgressReportResponse,
    SubscriptionResponse,
)
from app.schemas.client import (
    ActivationHintResponse,
    CheckInCreateRequest,
    ClientDashboardResponse,
    ClientFormCheckCreateRequest,
    ClientMessageCreateRequest,
    ClientMetricCreateRequest,
)
from app.services.challenges import build_challenge_snapshot
from app.services.maintenance import run_platform_maintenance
from app.services.message_hub import message_hub
from app.services.notifications import mark_notification_read
from app.services.reports import serialize_report


router = APIRouter()


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


def _serialize_notification(notification: NotificationRecord) -> NotificationResponse:
    return NotificationResponse.model_validate(notification)


@router.get("/dashboard", response_model=ClientDashboardResponse)
def dashboard(
    profile = Depends(get_current_client_profile),
    db: Session = Depends(get_db),
) -> ClientDashboardResponse:
    run_platform_maintenance(db, organization_id=profile.organization_id)
    today_focus = profile.program.workout_days[0].focus if profile.program and profile.program.workout_days else None
    checkins = sorted(profile.checkins, key=lambda item: item.submitted_at, reverse=True)
    messages = sorted(profile.messages, key=lambda item: item.created_at, reverse=True)
    invoices = sorted(profile.invoices, key=lambda item: item.due_date)
    metrics = sorted(profile.metrics, key=lambda item: item.logged_at, reverse=True)
    progress_report = max(profile.progress_reports, key=lambda item: item.period_start, default=None)
    unread_notifications = sum(1 for item in profile.notifications if item.read_at is None)
    challenge_payload = build_challenge_snapshot(db, profile.organization_id) if profile.organization_id else None

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
        subscription=SubscriptionResponse.model_validate(profile.subscription) if profile.subscription else None,
        latest_metric=MetricResponse.model_validate(metrics[0]) if metrics else None,
        monthly_progress_report=ProgressReportResponse.model_validate(serialize_report(progress_report))
        if progress_report
        else None,
        active_challenge=ChallengeResponse.model_validate(challenge_payload)
        if challenge_payload
        else None,
        unread_notifications=unread_notifications,
        recent_checkins=[CheckInResponse.model_validate(item) for item in checkins[:4]],
        recent_messages=[MessageResponse.model_validate(item) for item in messages[:6]],
        upcoming_invoices=[InvoiceResponse.model_validate(item) for item in invoices[:4]],
        recent_form_checks=[_serialize_form_check(item) for item in sorted(profile.form_checks, key=lambda item: item.created_at, reverse=True)[:3]],
    )


@router.get("/program", response_model=ProgramResponse | None)
def get_program(profile = Depends(get_current_client_profile)) -> ProgramResponse | None:
    return ProgramResponse.model_validate(profile.program) if profile.program else None


@router.get("/nutrition", response_model=NutritionResponse | None)
def get_nutrition(profile = Depends(get_current_client_profile)) -> NutritionResponse | None:
    return NutritionResponse.model_validate(profile.nutrition_plan) if profile.nutrition_plan else None


@router.get("/subscription", response_model=SubscriptionResponse | None)
def get_subscription(profile = Depends(get_current_client_profile)) -> SubscriptionResponse | None:
    return SubscriptionResponse.model_validate(profile.subscription) if profile.subscription else None


@router.get("/metrics", response_model=list[MetricResponse])
def get_metrics(profile = Depends(get_current_client_profile)) -> list[MetricResponse]:
    return [MetricResponse.model_validate(item) for item in sorted(profile.metrics, key=lambda item: item.logged_at, reverse=True)]


@router.post("/metrics", response_model=MetricResponse, status_code=status.HTTP_201_CREATED)
def create_metric(
    payload: ClientMetricCreateRequest,
    profile = Depends(get_current_client_profile),
    db: Session = Depends(get_db),
) -> MetricResponse:
    metric = MetricEntry(
        client_id=profile.id,
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


@router.get("/checkins", response_model=list[CheckInResponse])
def get_checkins(profile = Depends(get_current_client_profile)) -> list[CheckInResponse]:
    return [CheckInResponse.model_validate(item) for item in sorted(profile.checkins, key=lambda item: item.submitted_at, reverse=True)]


@router.post("/checkins", response_model=CheckInResponse, status_code=status.HTTP_201_CREATED)
def create_checkin(
    payload: CheckInCreateRequest,
    profile = Depends(get_current_client_profile),
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
def get_messages(profile = Depends(get_current_client_profile)) -> list[MessageResponse]:
    return [MessageResponse.model_validate(item) for item in sorted(profile.messages, key=lambda item: item.created_at)]


@router.post("/messages", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def create_message(
    payload: ClientMessageCreateRequest,
    profile = Depends(get_current_client_profile),
    db: Session = Depends(get_db),
) -> MessageResponse:
    message = Message(client_id=profile.id, sender_role=UserRole.CLIENT.value, body=payload.body)
    db.add(message)
    db.commit()
    db.refresh(message)
    response = MessageResponse.model_validate(message)
    await message_hub.broadcast(profile.id, response.model_dump(mode="json"))
    return response


@router.get("/invoices", response_model=list[InvoiceResponse])
def get_invoices(profile = Depends(get_current_client_profile)) -> list[InvoiceResponse]:
    return [InvoiceResponse.model_validate(item) for item in sorted(profile.invoices, key=lambda item: item.due_date, reverse=True)]


@router.get("/progress-report", response_model=ProgressReportResponse | None)
def get_progress_report(profile = Depends(get_current_client_profile)) -> ProgressReportResponse | None:
    report = max(profile.progress_reports, key=lambda item: item.period_start, default=None)
    return ProgressReportResponse.model_validate(serialize_report(report)) if report else None


@router.get("/notifications", response_model=list[NotificationResponse])
def get_notifications(profile = Depends(get_current_client_profile)) -> list[NotificationResponse]:
    return [_serialize_notification(item) for item in sorted(profile.notifications, key=lambda item: item.created_at, reverse=True)]


@router.put("/notifications/{notification_id}/read", response_model=NotificationResponse)
def read_notification(
    notification_id: int,
    profile = Depends(get_current_client_profile),
    db: Session = Depends(get_db),
) -> NotificationResponse:
    notification = next((item for item in profile.notifications if item.id == notification_id), None)
    if notification is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
    mark_notification_read(notification)
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return _serialize_notification(notification)


@router.get("/challenge", response_model=ChallengeResponse | None)
def get_challenge(
    profile = Depends(get_current_client_profile),
    db: Session = Depends(get_db),
) -> ChallengeResponse | None:
    payload = build_challenge_snapshot(db, profile.organization_id) if profile.organization_id else None
    return ChallengeResponse.model_validate(payload) if payload else None


@router.get("/form-checks", response_model=list[FormCheckResponse])
def get_form_checks(profile = Depends(get_current_client_profile)) -> list[FormCheckResponse]:
    return [_serialize_form_check(item) for item in sorted(profile.form_checks, key=lambda item: item.created_at, reverse=True)]


@router.post("/form-checks", response_model=FormCheckResponse, status_code=status.HTTP_201_CREATED)
def create_form_check(
    payload: ClientFormCheckCreateRequest,
    profile = Depends(get_current_client_profile),
    db: Session = Depends(get_db),
) -> FormCheckResponse:
    form_check = FormCheck(
        client_id=profile.id,
        exercise_name=payload.exercise_name,
        video_url=payload.video_url,
        notes=payload.notes,
        status=FormCheckStatus.SUBMITTED,
    )
    db.add(form_check)
    db.commit()
    db.refresh(form_check)
    return _serialize_form_check(form_check)
