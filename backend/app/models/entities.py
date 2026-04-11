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


class SubscriptionStatus(str, Enum):
    TRIALING = "trialing"
    ACTIVE = "active"
    PAUSED = "paused"
    PAST_DUE = "past_due"
    CANCELED = "canceled"


class NotificationCategory(str, Enum):
    CHECKIN_REMINDER = "checkin_reminder"
    INVOICE = "invoice"
    REPORT = "report"
    CHALLENGE = "challenge"
    FORM_CHECK = "form_check"


class FormCheckStatus(str, Enum):
    SUBMITTED = "submitted"
    REVIEWED = "reviewed"


class ChallengeMetricType(str, Enum):
    CHECKIN_STREAK = "checkin_streak"
    ADHERENCE_AVERAGE = "adherence_average"
    SQUAT_GAIN = "squat_gain"
    DEADLIFT_GAIN = "deadlift_gain"


class Organization(Base, TimestampMixin):
    __tablename__ = "organizations"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255), index=True)
    slug: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    logo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)

    users: Mapped[list["User"]] = relationship(back_populates="organization")
    clients: Mapped[list["ClientProfile"]] = relationship(back_populates="organization")
    templates: Mapped[list["ProgramTemplate"]] = relationship(
        back_populates="organization",
        cascade="all, delete-orphan",
    )
    challenges: Mapped[list["CommunityChallenge"]] = relationship(
        back_populates="organization",
        cascade="all, delete-orphan",
    )


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
    subscription: Mapped["ClientSubscription | None"] = relationship(
        back_populates="client",
        uselist=False,
        cascade="all, delete-orphan",
    )
    checkins: Mapped[list["CheckIn"]] = relationship(back_populates="client", cascade="all, delete-orphan")
    messages: Mapped[list["Message"]] = relationship(back_populates="client", cascade="all, delete-orphan")
    invoices: Mapped[list["Invoice"]] = relationship(back_populates="client", cascade="all, delete-orphan")
    metrics: Mapped[list["MetricEntry"]] = relationship(back_populates="client", cascade="all, delete-orphan")
    progress_reports: Mapped[list["ProgressReport"]] = relationship(
        back_populates="client",
        cascade="all, delete-orphan",
    )
    notifications: Mapped[list["NotificationRecord"]] = relationship(
        back_populates="client",
        cascade="all, delete-orphan",
    )
    form_checks: Mapped[list["FormCheck"]] = relationship(
        back_populates="client",
        cascade="all, delete-orphan",
    )


class TrainingProgram(Base, TimestampMixin):
    __tablename__ = "training_programs"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(255))
    phase: Mapped[str] = mapped_column(String(255))
    goal: Mapped[str] = mapped_column(String(255))
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)

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


class ProgramTemplate(Base, TimestampMixin):
    __tablename__ = "program_templates"

    id: Mapped[int] = mapped_column(primary_key=True)
    organization_id: Mapped[int] = mapped_column(ForeignKey("organizations.id"), index=True)
    title: Mapped[str] = mapped_column(String(255))
    phase: Mapped[str] = mapped_column(String(255))
    goal: Mapped[str] = mapped_column(String(255))
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    duration_weeks: Mapped[int] = mapped_column(Integer, default=4)

    organization: Mapped["Organization"] = relationship(back_populates="templates")
    workout_days: Mapped[list["ProgramTemplateDay"]] = relationship(
        back_populates="template",
        cascade="all, delete-orphan",
        order_by="ProgramTemplateDay.day_index",
    )


class ProgramTemplateDay(Base, TimestampMixin):
    __tablename__ = "program_template_days"

    id: Mapped[int] = mapped_column(primary_key=True)
    template_id: Mapped[int] = mapped_column(ForeignKey("program_templates.id"), index=True)
    day_index: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(255))
    focus: Mapped[str] = mapped_column(String(255))
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    template: Mapped["ProgramTemplate"] = relationship(back_populates="workout_days")
    exercises: Mapped[list["ProgramTemplateExercise"]] = relationship(
        back_populates="template_day",
        cascade="all, delete-orphan",
    )


class ProgramTemplateExercise(Base, TimestampMixin):
    __tablename__ = "program_template_exercises"

    id: Mapped[int] = mapped_column(primary_key=True)
    template_day_id: Mapped[int] = mapped_column(ForeignKey("program_template_days.id"), index=True)
    name: Mapped[str] = mapped_column(String(255))
    sets: Mapped[str] = mapped_column(String(64))
    reps: Mapped[str] = mapped_column(String(64))
    rest_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    target: Mapped[str | None] = mapped_column(String(255), nullable=True)

    template_day: Mapped["ProgramTemplateDay"] = relationship(back_populates="exercises")


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


class ClientSubscription(Base, TimestampMixin):
    __tablename__ = "client_subscriptions"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), unique=True, index=True)
    plan_name: Mapped[str] = mapped_column(String(255))
    monthly_price_cents: Mapped[int] = mapped_column(Integer)
    status: Mapped[SubscriptionStatus] = mapped_column(
        SqlEnum(SubscriptionStatus),
        default=SubscriptionStatus.ACTIVE,
        index=True,
    )
    started_at: Mapped[date] = mapped_column(Date)
    next_invoice_date: Mapped[date] = mapped_column(Date)
    canceled_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    client: Mapped["ClientProfile"] = relationship(back_populates="subscription")
    invoices: Mapped[list["Invoice"]] = relationship(back_populates="subscription")


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


class MetricEntry(Base, TimestampMixin):
    __tablename__ = "metric_entries"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), index=True)
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    body_weight: Mapped[float | None] = mapped_column(Float, nullable=True)
    squat_1rm: Mapped[float | None] = mapped_column(Float, nullable=True)
    bench_1rm: Mapped[float | None] = mapped_column(Float, nullable=True)
    deadlift_1rm: Mapped[float | None] = mapped_column(Float, nullable=True)
    adherence_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    energy_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    client: Mapped["ClientProfile"] = relationship(back_populates="metrics")


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
    subscription_id: Mapped[int | None] = mapped_column(
        ForeignKey("client_subscriptions.id"),
        index=True,
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(255))
    amount_cents: Mapped[int] = mapped_column(Integer)
    due_date: Mapped[date] = mapped_column(Date)
    billing_period_start: Mapped[date | None] = mapped_column(Date, nullable=True)
    billing_period_end: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[InvoiceStatus] = mapped_column(SqlEnum(InvoiceStatus), default=InvoiceStatus.PENDING)

    client: Mapped["ClientProfile"] = relationship(back_populates="invoices")
    subscription: Mapped["ClientSubscription | None"] = relationship(back_populates="invoices")


class ProgressReport(Base, TimestampMixin):
    __tablename__ = "progress_reports"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), index=True)
    period_start: Mapped[date] = mapped_column(Date, index=True)
    period_end: Mapped[date] = mapped_column(Date)
    summary: Mapped[str] = mapped_column(Text)
    body_weight_change: Mapped[float | None] = mapped_column(Float, nullable=True)
    squat_gain: Mapped[float | None] = mapped_column(Float, nullable=True)
    bench_gain: Mapped[float | None] = mapped_column(Float, nullable=True)
    deadlift_gain: Mapped[float | None] = mapped_column(Float, nullable=True)
    adherence_average: Mapped[float | None] = mapped_column(Float, nullable=True)
    checkins_completed: Mapped[int] = mapped_column(Integer, default=0)

    client: Mapped["ClientProfile"] = relationship(back_populates="progress_reports")


class NotificationRecord(Base, TimestampMixin):
    __tablename__ = "notification_records"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), index=True)
    organization_id: Mapped[int | None] = mapped_column(ForeignKey("organizations.id"), index=True, nullable=True)
    title: Mapped[str] = mapped_column(String(255))
    body: Mapped[str] = mapped_column(Text)
    category: Mapped[NotificationCategory] = mapped_column(SqlEnum(NotificationCategory), index=True)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    client: Mapped["ClientProfile"] = relationship(back_populates="notifications")


class CommunityChallenge(Base, TimestampMixin):
    __tablename__ = "community_challenges"

    id: Mapped[int] = mapped_column(primary_key=True)
    organization_id: Mapped[int] = mapped_column(ForeignKey("organizations.id"), index=True)
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    metric_type: Mapped[ChallengeMetricType] = mapped_column(SqlEnum(ChallengeMetricType), index=True)
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date] = mapped_column(Date)
    unit_label: Mapped[str | None] = mapped_column(String(64), nullable=True)

    organization: Mapped["Organization"] = relationship(back_populates="challenges")


class FormCheck(Base, TimestampMixin):
    __tablename__ = "form_checks"

    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("client_profiles.id"), index=True)
    exercise_name: Mapped[str] = mapped_column(String(255))
    video_url: Mapped[str] = mapped_column(String(1024))
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    coach_feedback: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[FormCheckStatus] = mapped_column(SqlEnum(FormCheckStatus), default=FormCheckStatus.SUBMITTED)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    client: Mapped["ClientProfile"] = relationship(back_populates="form_checks")


class SessionToken(Base, TimestampMixin):
    __tablename__ = "session_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)

    user: Mapped["User"] = relationship(back_populates="session_tokens")
