from __future__ import annotations

from datetime import datetime, timedelta, UTC

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import generate_invite_code, hash_password
from app.models.entities import (
    CheckIn,
    ClientProfile,
    ClientStatus,
    Invoice,
    InvoiceStatus,
    Message,
    NutritionPlan,
    Organization,
    TrainingProgram,
    User,
    UserRole,
    WorkoutDay,
    WorkoutExercise,
)
from app.services.organizations import generate_unique_slug


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


def _ensure_demo_client(db: Session, organization: Organization) -> None:
    user = db.scalar(select(User).where(User.email == "maya@example.com"))
    if user:
        user.full_name = "Maya Singh"
        user.password_hash = hash_password("client12345")
        user.role = UserRole.CLIENT
        user.organization_id = organization.id
    else:
        user = User(
            email="maya@example.com",
            full_name="Maya Singh",
            password_hash=hash_password("client12345"),
            role=UserRole.CLIENT,
            organization_id=organization.id,
        )
        db.add(user)
        db.flush()

    existing_profile = db.scalar(select(ClientProfile).where(ClientProfile.full_name == "Maya Singh"))
    if existing_profile:
        profile = existing_profile
        profile.contact_email = "maya@example.com"
        profile.phone = "+977-9800000000"
        profile.goal = "Lose body fat while keeping squat strength stable"
        profile.notes = "Responds well to structured nutrition and concise coaching feedback."
        profile.status = ClientStatus.ACTIVE
        profile.invite_code = "MAYA-START"
        profile.user_id = user.id
        profile.organization_id = organization.id
    else:
        profile = ClientProfile(
            full_name="Maya Singh",
            contact_email="maya@example.com",
            phone="+977-9800000000",
            goal="Lose body fat while keeping squat strength stable",
            notes="Responds well to structured nutrition and concise coaching feedback.",
            status=ClientStatus.ACTIVE,
            invite_code="MAYA-START",
            organization_id=organization.id,
            user_id=user.id,
        )
        db.add(profile)
        db.flush()

    if profile.program is None:
        program = TrainingProgram(
            title="Phase 2 Lower / Upper Split",
            phase="Intensification",
            goal="Keep strength stable while driving body composition change",
            summary="Four sessions with lower fatigue accessories and one conditioning finisher.",
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

    if profile.nutrition_plan is None:
        profile.nutrition_plan = NutritionPlan(
            calories=2100,
            protein=175,
            carbs=210,
            fats=58,
            water_liters=3.0,
            notes="Keep weekend meals planned ahead to reduce drift.",
        )

    if not profile.checkins:
        profile.checkins.extend(
            [
                CheckIn(
                    submitted_at=datetime.now(UTC) - timedelta(days=7),
                    body_weight=67.8,
                    sleep_score=4,
                    stress_score=3,
                    adherence_score=89,
                    notes="Busy week, but training stayed on track.",
                ),
                CheckIn(
                    submitted_at=datetime.now(UTC) - timedelta(days=1),
                    body_weight=67.2,
                    sleep_score=4,
                    stress_score=2,
                    adherence_score=92,
                    notes="Energy is improving and hunger is manageable.",
                ),
            ]
        )

    if not profile.messages:
        profile.messages.extend(
            [
                Message(sender_role=UserRole.CLIENT.value, body="Uploaded today's squat video. Last set felt slower."),
                Message(sender_role=UserRole.ADMIN.value, body="Depth is solid. Keep load steady and drop one back-off set."),
            ]
        )

    if not profile.invoices:
        profile.invoices.extend(
            [
                Invoice(
                    title="Premium Coaching - April",
                    amount_cents=42000,
                    due_date=(datetime.now(UTC) + timedelta(days=14)).date(),
                    status=InvoiceStatus.PENDING,
                )
            ]
        )

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
    else:
        invited = ClientProfile(
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
        db.add(invited)

    db.commit()


def seed_database(db: Session) -> None:
    _ensure_super_admin(db)
    organization = _ensure_default_organization(db)
    _ensure_admin(db, organization)
    _ensure_demo_client(db, organization)
