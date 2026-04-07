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
    TrainingProgram,
    User,
    UserRole,
    WorkoutDay,
    WorkoutExercise,
)


def _ensure_admin(db: Session) -> None:
    existing = db.scalar(select(User).where(User.email.in_(["admin@abhaymethod.local", "admin@abhaymethod.app"])))
    if existing:
        existing.email = "admin@abhaymethod.app"
        db.commit()
        return

    db.add(
        User(
            email="admin@abhaymethod.app",
            password_hash=hash_password("admin12345"),
            role=UserRole.ADMIN,
        )
    )
    db.commit()


def _ensure_demo_client(db: Session) -> None:
    existing_profile = db.scalar(select(ClientProfile).where(ClientProfile.full_name == "Maya Singh"))
    if existing_profile:
        return

    user = User(
        email="maya@example.com",
        password_hash=hash_password("client12345"),
        role=UserRole.CLIENT,
    )
    db.add(user)
    db.flush()

    profile = ClientProfile(
        full_name="Maya Singh",
        contact_email="maya@example.com",
        phone="+977-9800000000",
        goal="Lose body fat while keeping squat strength stable",
        notes="Responds well to structured nutrition and concise coaching feedback.",
        status=ClientStatus.ACTIVE,
        invite_code="MAYA-START",
        user_id=user.id,
    )

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
            WorkoutExercise(name="Chest Supported Row", sets="4", reps="8", rest_seconds=120, target="Controlled"),
        ]
    )
    program.workout_days.extend([day_one, day_two])
    profile.program = program

    profile.nutrition_plan = NutritionPlan(
        calories=2100,
        protein=175,
        carbs=210,
        fats=58,
        water_liters=3.0,
        notes="Keep weekend meals planned ahead to reduce drift.",
    )

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

    profile.messages.extend(
        [
            Message(sender_role=UserRole.CLIENT.value, body="Uploaded today's squat video. Last set felt slower."),
            Message(sender_role=UserRole.ADMIN.value, body="Depth is solid. Keep load steady and drop one back-off set."),
        ]
    )

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

    invited = ClientProfile(
        full_name="Rohan KC",
        contact_email="rohan@example.com",
        phone="+977-9811111111",
        goal="Travel-proof strength and habit consistency",
        notes="Needs a clean invite flow so he can activate his account himself.",
        status=ClientStatus.INVITED,
        invite_code="ROHAN-START" if not db.scalar(select(ClientProfile).where(ClientProfile.invite_code == "ROHAN-START")) else generate_invite_code(),
    )

    db.add_all([profile, invited])
    db.commit()


def seed_database(db: Session) -> None:
    _ensure_admin(db)
    _ensure_demo_client(db)
