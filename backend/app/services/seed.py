from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import generate_invite_code, hash_password
from app.models.entities import (
    CheckIn,
    ClientProfile,
    ClientStatus,
    ClientSubscription,
    CommunityChallenge,
    FormCheck,
    FormCheckStatus,
    Message,
    MetricEntry,
    NutritionPlan,
    Organization,
    ProgramTemplate,
    SubscriptionStatus,
    TrainingProgram,
    User,
    UserRole,
    WorkoutDay,
    WorkoutExercise,
)
from app.services.challenges import ensure_default_challenge
from app.services.maintenance import run_platform_maintenance
from app.services.organizations import generate_unique_slug
from app.services.program_templates import build_cycle_dates, ensure_template_library


def _ensure_super_admin(db: Session) -> None:
    existing = db.scalar(
        select(User).where(User.email.in_(["superadmin@platform.local", "superadmin@platform.app"]))
    )
    if existing:
        existing.email = "superadmin@platform.app"
        existing.full_name = "Platform Super Admin"
        existing.password_hash = hash_password("superadmin12345")
        existing.role = UserRole.SUPER_ADMIN
        existing.organization_id = None
        db.commit()
        return

    db.add(
        User(
            email="superadmin@platform.app",
            full_name="Platform Super Admin",
            password_hash=hash_password("superadmin12345"),
            role=UserRole.SUPER_ADMIN,
        )
    )
    db.commit()


def _ensure_default_organization(db: Session) -> Organization:
    organization = db.scalar(select(Organization).where(Organization.slug == "abhay-method-gym"))
    if organization:
        organization.name = "Abhay Method Gym"
        if not organization.logo_url:
            organization.logo_url = "https://placehold.co/200x200/111827/F8FAFC?text=AM"
        db.commit()
        return organization

    organization = Organization(
        name="Abhay Method Gym",
        slug="abhay-method-gym"
        if db.scalar(select(Organization.id).where(Organization.slug == "abhay-method-gym")) is None
        else generate_unique_slug(db, "Abhay Method Gym"),
        logo_url="https://placehold.co/200x200/111827/F8FAFC?text=AM",
    )
    db.add(organization)
    db.commit()
    db.refresh(organization)
    return organization


def _ensure_admin(db: Session, organization: Organization) -> None:
    existing = db.scalar(select(User).where(User.email.in_(["admin@abhaymethod.local", "admin@abhaymethod.app"])))
    if existing:
        existing.email = "admin@abhaymethod.app"
        existing.full_name = "Abhay Gym Owner"
        existing.password_hash = hash_password("admin12345")
        existing.role = UserRole.ADMIN
        existing.organization_id = organization.id
        db.commit()
        return

    db.add(
        User(
            email="admin@abhaymethod.app",
            full_name="Abhay Gym Owner",
            password_hash=hash_password("admin12345"),
            role=UserRole.ADMIN,
            organization_id=organization.id,
        )
    )
    db.commit()


def _ensure_active_client(
    db: Session,
    organization: Organization,
    *,
    email: str,
    password: str,
    full_name: str,
    goal: str,
    phone: str,
    notes: str,
    invite_code: str,
    bodyweight_pair: tuple[float, float],
    strength_pair: tuple[tuple[float, float], tuple[float, float], tuple[float, float]],
    checkin_notes: tuple[str, str],
    messages: tuple[tuple[str, str], ...],
    form_check_payload: tuple[str, str, str, str | None, str],
) -> ClientProfile:
    user = db.scalar(select(User).where(User.email == email))
    if user:
        user.full_name = full_name
        user.password_hash = hash_password(password)
        user.role = UserRole.CLIENT
        user.organization_id = organization.id
    else:
        user = User(
            email=email,
            full_name=full_name,
            password_hash=hash_password(password),
            role=UserRole.CLIENT,
            organization_id=organization.id,
        )
        db.add(user)
        db.flush()

    profile = db.scalar(select(ClientProfile).where(ClientProfile.user_id == user.id))
    if profile is None:
        profile = ClientProfile(
            full_name=full_name,
            contact_email=email,
            phone=phone,
            goal=goal,
            notes=notes,
            status=ClientStatus.ACTIVE,
            invite_code=invite_code,
            organization_id=organization.id,
            user_id=user.id,
        )
        db.add(profile)
        db.flush()
    else:
        profile.full_name = full_name
        profile.contact_email = email
        profile.phone = phone
        profile.goal = goal
        profile.notes = notes
        profile.status = ClientStatus.ACTIVE
        profile.invite_code = invite_code
        profile.organization_id = organization.id

    _ensure_program(profile, goal)
    _ensure_nutrition(profile)
    _ensure_subscription(profile)
    _ensure_metrics(profile, bodyweight_pair, strength_pair, notes)
    _ensure_checkins(profile, bodyweight_pair, checkin_notes)
    _ensure_messages(profile, messages)
    _ensure_form_check(profile, form_check_payload)
    return profile


def _ensure_program(profile: ClientProfile, goal: str) -> None:
    start_date, end_date = build_cycle_dates(date.today() - timedelta(days=14), 4)
    if profile.program is None:
        program = TrainingProgram(
            title="Phase 2 Lower / Upper Split",
            phase="Intensification",
            goal=goal,
            summary="Four sessions with lower fatigue accessories and one conditioning finisher.",
            start_date=start_date,
            end_date=end_date,
        )
        day_one = WorkoutDay(day_index=1, title="Lower Strength", focus="Front squat + posterior chain")
        day_one.exercises.extend(
            [
                WorkoutExercise(name="Front Squat", sets="5", reps="3", rest_seconds=180, target="82% 1RM"),
                WorkoutExercise(name="Romanian Deadlift", sets="4", reps="6", rest_seconds=150, target="RPE 7.5"),
            ]
        )
        day_two = WorkoutDay(day_index=2, title="Upper Push / Pull", focus="Bench press + back volume")
        day_two.exercises.extend(
            [
                WorkoutExercise(name="Bench Press", sets="4", reps="5", rest_seconds=150, target="78% 1RM"),
                WorkoutExercise(
                    name="Chest Supported Row",
                    sets="4",
                    reps="8",
                    rest_seconds=120,
                    target="Controlled",
                ),
            ]
        )
        program.workout_days.extend([day_one, day_two])
        profile.program = program
    else:
        profile.program.goal = goal
        profile.program.start_date = start_date
        profile.program.end_date = end_date


def _ensure_nutrition(profile: ClientProfile) -> None:
    if profile.nutrition_plan is None:
        profile.nutrition_plan = NutritionPlan(
            calories=2100,
            protein=175,
            carbs=210,
            fats=58,
            water_liters=3.0,
            notes="Keep weekend meals planned ahead to reduce drift.",
        )


def _ensure_subscription(profile: ClientProfile) -> None:
    today = date.today()
    if profile.subscription is None:
        profile.subscription = ClientSubscription(
            plan_name="Premium Coaching Membership",
            monthly_price_cents=42000,
            status=SubscriptionStatus.ACTIVE,
            started_at=today - timedelta(days=60),
            next_invoice_date=today,
            notes="Includes weekly coaching, program updates, nutrition review, and form feedback.",
        )
    else:
        profile.subscription.plan_name = "Premium Coaching Membership"
        profile.subscription.monthly_price_cents = 42000
        if profile.subscription.status == SubscriptionStatus.CANCELED:
            profile.subscription.status = SubscriptionStatus.ACTIVE
        profile.subscription.started_at = today - timedelta(days=60)
        if profile.subscription.next_invoice_date < today:
            profile.subscription.next_invoice_date = today
        profile.subscription.notes = "Includes weekly coaching, program updates, nutrition review, and form feedback."


def _ensure_metrics(
    profile: ClientProfile,
    bodyweight_pair: tuple[float, float],
    strength_pair: tuple[tuple[float, float], tuple[float, float], tuple[float, float]],
    notes: str,
) -> None:
    if profile.metrics:
        return

    profile.metrics.extend(
        [
            MetricEntry(
                logged_at=datetime.now(UTC) - timedelta(days=28),
                body_weight=bodyweight_pair[0],
                squat_1rm=strength_pair[0][0],
                bench_1rm=strength_pair[1][0],
                deadlift_1rm=strength_pair[2][0],
                adherence_score=87,
                energy_score=3,
                notes=f"Cycle baseline. {notes}",
            ),
            MetricEntry(
                logged_at=datetime.now(UTC) - timedelta(days=2),
                body_weight=bodyweight_pair[1],
                squat_1rm=strength_pair[0][1],
                bench_1rm=strength_pair[1][1],
                deadlift_1rm=strength_pair[2][1],
                adherence_score=92,
                energy_score=4,
                notes="Latest performance review checkpoint.",
            ),
        ]
    )


def _ensure_checkins(
    profile: ClientProfile,
    bodyweight_pair: tuple[float, float],
    checkin_notes: tuple[str, str],
) -> None:
    if profile.checkins:
        return

    profile.checkins.extend(
        [
            CheckIn(
                submitted_at=datetime.now(UTC) - timedelta(days=7),
                body_weight=bodyweight_pair[0],
                sleep_score=4,
                stress_score=3,
                adherence_score=89,
                notes=checkin_notes[0],
            ),
            CheckIn(
                submitted_at=datetime.now(UTC) - timedelta(days=1),
                body_weight=bodyweight_pair[1],
                sleep_score=4,
                stress_score=2,
                adherence_score=92,
                notes=checkin_notes[1],
            ),
        ]
    )


def _ensure_messages(profile: ClientProfile, messages: tuple[tuple[str, str], ...]) -> None:
    if profile.messages:
        return

    for sender_role, body in messages:
        profile.messages.append(Message(sender_role=sender_role, body=body))


def _ensure_form_check(
    profile: ClientProfile,
    payload: tuple[str, str, str, str | None, str],
) -> None:
    if profile.form_checks:
        return

    exercise_name, video_url, notes, feedback, status = payload
    profile.form_checks.append(
        FormCheck(
            exercise_name=exercise_name,
            video_url=video_url,
            notes=notes,
            coach_feedback=feedback,
            status=FormCheckStatus(status),
            reviewed_at=datetime.now(UTC) - timedelta(days=1)
            if feedback
            else None,
        )
    )


def _ensure_invited_client(db: Session, organization: Organization) -> None:
    invited = db.scalar(select(ClientProfile).where(ClientProfile.full_name == "Rohan KC"))
    if invited:
        invited.contact_email = "rohan@example.com"
        invited.phone = "+977-9811111111"
        invited.goal = "Travel-proof strength and habit consistency"
        invited.notes = "Needs a clean invite flow so he can activate his account himself."
        invited.status = ClientStatus.INVITED
        invited.organization_id = organization.id
        if invited.user_id is None:
            invited.invite_code = "ROHAN-START"
        return

    db.add(
        ClientProfile(
            full_name="Rohan KC",
            contact_email="rohan@example.com",
            phone="+977-9811111111",
            goal="Travel-proof strength and habit consistency",
            notes="Needs a clean invite flow so he can activate his account himself.",
            status=ClientStatus.INVITED,
            invite_code="ROHAN-START"
            if not db.scalar(select(ClientProfile).where(ClientProfile.invite_code == "ROHAN-START"))
            else generate_invite_code(),
            organization_id=organization.id,
        )
    )


def seed_database(db: Session) -> None:
    _ensure_super_admin(db)
    organization = _ensure_default_organization(db)
    _ensure_admin(db, organization)

    _ensure_active_client(
        db,
        organization,
        email="maya@example.com",
        password="client12345",
        full_name="Maya Singh",
        goal="Lose body fat while keeping squat strength stable",
        phone="+977-9800000000",
        notes="Responds well to structured nutrition and concise coaching feedback.",
        invite_code="MAYA-START",
        bodyweight_pair=(67.8, 67.2),
        strength_pair=((110.0, 116.0), (62.0, 65.0), (138.0, 145.0)),
        checkin_notes=(
            "Busy week, but training stayed on track.",
            "Energy is improving and hunger is manageable.",
        ),
        messages=(
            (UserRole.CLIENT.value, "Uploaded today's squat video. Last set felt slower."),
            (UserRole.ADMIN.value, "Depth is solid. Keep load steady and drop one back-off set."),
        ),
        form_check_payload=(
            "Front Squat",
            "https://example.com/videos/maya-front-squat.mp4",
            "Top set from week 3. Knees feel better than last month.",
            "Bracing looks better. Stay patient out of the hole and keep the elbows higher.",
            FormCheckStatus.REVIEWED.value,
        ),
    )
    _ensure_active_client(
        db,
        organization,
        email="aarav@example.com",
        password="client12345",
        full_name="Aarav Shah",
        goal="Add upper-body size while keeping deadlift momentum",
        phone="+977-9812222222",
        notes="Handles volume well, but recovery drops fast when sleep slips.",
        invite_code="AARAV-START",
        bodyweight_pair=(78.4, 79.6),
        strength_pair=((132.0, 136.0), (88.0, 92.0), (172.0, 180.0)),
        checkin_notes=(
            "Session quality was strong but recovery lagged after travel.",
            "Sleep is back on track and upper body pump work feels excellent.",
        ),
        messages=(
            (UserRole.ADMIN.value, "Keep your bench accessories crisp and stop one rep short of grindy sets."),
            (UserRole.CLIENT.value, "Will do. Uploading my last deadlift video tomorrow."),
        ),
        form_check_payload=(
            "Deadlift",
            "https://example.com/videos/aarav-deadlift.mp4",
            "Last top triple from Friday.",
            None,
            FormCheckStatus.SUBMITTED.value,
        ),
    )
    _ensure_invited_client(db, organization)

    db.commit()

    ensure_template_library(db, organization)
    ensure_default_challenge(db, organization)
    run_platform_maintenance(db, organization_id=organization.id)
