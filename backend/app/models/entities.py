from __future__ import annotations

from datetime import date, datetime
from enum import Enum

from sqlalchemy import Date, DateTime, Enum as SqlEnum, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class UserRole(str, Enum):
    SUPER_ADMIN = "super_admin"
    ADMIN = "admin"
    CLIENT = "client"


class ClientStatus(str, Enum):
    INVITED = "invited"
    ACTIVE = "active"
    PAUSED = "paused"


class InvoiceStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    OVERDUE = "overdue"


class Organization(Base, TimestampMixin):
    __tablename__ = "organizations"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), index=True)
    slug: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    logo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)

    users: Mapped[list["User"]] = relationship(back_populates="organization")
    clients: Mapped[list["ClientProfile"]] = relationship(back_populates="organization")


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    full_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[UserRole] = mapped_column(SqlEnum(UserRole), index=True)
    is_active: Mapped[bool] = mapped_column(default=True)
    organization_id: Mapped[int | None] = mapped_column(ForeignKey("organizations.id"), index=True, nullable=True)

    organization: Mapped["Organization | None"] = relationship(back_populates="users")
    client_profile: Mapped["ClientProfile | None"] = relationship(
        back_populates="user",
        uselist=False,
    )
    session_tokens: Mapped[list["SessionToken"]] = relationship(back_populates="user")


class ClientProfile(Base, TimestampMixin):
    __tablename__ = "client_profiles"

    id: Mapped[int] = mapped_column(primary_key=True)
    full_name: Mapped[str] = mapped_column(String(255), index=True)
    contact_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(64), nullable=True)
    goal: Mapped[str] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[ClientStatus] = mapped_column(SqlEnum(ClientStatus), default=ClientStatus.INVITED)
    invite_code: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    organization_id: Mapped[int | None] = mapped_column(ForeignKey("organizations.id"), index=True, nullable=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), unique=True, nullable=True)

    organization: Mapped["Organization | None"] = relationship(back_populates="clients")
    user: Mapped["User | None"] = relationship(back_populates="client_profile")
    program: Mapped["TrainingProgram | None"] = relationship(
        back_populates="client",
        uselist=False,
        cascade="all, delete-orphan",
    )
    nutrition_plan: Mapped["NutritionPlan | None"] = relationship(
        back_populates="client",
        uselist=False,
        cascade="all, delete-orphan",
    )
    checkins: Mapped[list["CheckIn"]] = relationship(back_populates="client", cascade="all, delete-orphan")
    messages: Mapped[list["Message"]] = relationship(back_populates="client", cascade="all, delete-orphan")
    invoices: Mapped[list["Invoice"]] = relationship(back_populates="client", cascade="all, delete-orphan")


class TrainingProgram(Base, TimestampMixin):
    __tablename__ = "training_programs"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(255))
    phase: Mapped[str] = mapped_column(String(255))
    goal: Mapped[str] = mapped_column(String(255))
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)

    client: Mapped["ClientProfile"] = relationship(back_populates="program")
    workout_days: Mapped[list["WorkoutDay"]] = relationship(
        back_populates="program",
        cascade="all, delete-orphan",
        order_by="WorkoutDay.day_index",
    )


class WorkoutDay(Base, TimestampMixin):
    __tablename__ = "workout_days"

    id: Mapped[int] = mapped_column(primary_key=True)
    program_id: Mapped[int] = mapped_column(ForeignKey("training_programs.id"), index=True)
    day_index: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(255))
    focus: Mapped[str] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    program: Mapped["TrainingProgram"] = relationship(back_populates="workout_days")
    exercises: Mapped[list["WorkoutExercise"]] = relationship(
        back_populates="workout_day",
        cascade="all, delete-orphan",
    )


class WorkoutExercise(Base, TimestampMixin):
    __tablename__ = "workout_exercises"

    id: Mapped[int] = mapped_column(primary_key=True)
    workout_day_id: Mapped[int] = mapped_column(ForeignKey("workout_days.id"), index=True)
    name: Mapped[str] = mapped_column(String(255))
    sets: Mapped[str] = mapped_column(String(64))
    reps: Mapped[str] = mapped_column(String(64))
    rest_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    target: Mapped[str | None] = mapped_column(String(255), nullable=True)

    workout_day: Mapped["WorkoutDay"] = relationship(back_populates="exercises")


class NutritionPlan(Base, TimestampMixin):
    __tablename__ = "nutrition_plans"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), unique=True, index=True)
    calories: Mapped[int] = mapped_column(Integer)
    protein: Mapped[int] = mapped_column(Integer)
    carbs: Mapped[int] = mapped_column(Integer)
    fats: Mapped[int] = mapped_column(Integer)
    water_liters: Mapped[float | None] = mapped_column(Float, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    client: Mapped["ClientProfile"] = relationship(back_populates="nutrition_plan")


class CheckIn(Base, TimestampMixin):
    __tablename__ = "checkins"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), index=True)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    body_weight: Mapped[float | None] = mapped_column(Float, nullable=True)
    sleep_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    stress_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    adherence_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    client: Mapped["ClientProfile"] = relationship(back_populates="checkins")


class Message(Base, TimestampMixin):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), index=True)
    sender_role: Mapped[str] = mapped_column(String(32))
    body: Mapped[str] = mapped_column(Text)

    client: Mapped["ClientProfile"] = relationship(back_populates="messages")


class Invoice(Base, TimestampMixin):
    __tablename__ = "invoices"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), index=True)
    title: Mapped[str] = mapped_column(String(255))
    amount_cents: Mapped[int] = mapped_column(Integer)
    due_date: Mapped[date] = mapped_column(Date)
    status: Mapped[InvoiceStatus] = mapped_column(SqlEnum(InvoiceStatus), default=InvoiceStatus.PENDING)

    client: Mapped["ClientProfile"] = relationship(back_populates="invoices")


class SessionToken(Base, TimestampMixin):
    __tablename__ = "session_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)

    user: Mapped["User"] = relationship(back_populates="session_tokens")
