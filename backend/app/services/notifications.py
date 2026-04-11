from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.entities import (
    CheckIn,
    ClientProfile,
    ClientSubscription,
    NotificationCategory,
    NotificationRecord,
    SubscriptionStatus,
)


def _normalize_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def ensure_missing_checkin_notifications(
    db: Session,
    organization_id: int | None = None,
    now: datetime | None = None,
) -> None:
    current_time = now or datetime.now(UTC)
    stale_cutoff = current_time - timedelta(days=7)

    statement = (
        select(ClientSubscription)
        .join(ClientProfile, ClientSubscription.client_id == ClientProfile.id)
        .options(
            selectinload(ClientSubscription.client).selectinload(ClientProfile.checkins),
            selectinload(ClientSubscription.client).selectinload(ClientProfile.notifications),
        )
    )
    if organization_id is not None:
        statement = statement.where(ClientProfile.organization_id == organization_id)

    subscriptions = db.scalars(statement).all()
    changed = False
    for subscription in subscriptions:
        if subscription.status not in {SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING}:
            continue

        client = subscription.client
        if client is None:
            continue

        last_checkin = max(client.checkins, key=lambda item: item.submitted_at, default=None)
        last_checkin_at = _normalize_utc(last_checkin.submitted_at) if last_checkin else None
        if last_checkin_at and last_checkin_at >= stale_cutoff:
            continue

        recent_reminder = max(
            (
                notification
                for notification in client.notifications
                if notification.category == NotificationCategory.CHECKIN_REMINDER
            ),
            key=lambda item: item.created_at,
            default=None,
        )
        recent_reminder_at = (
            _normalize_utc(recent_reminder.created_at) if recent_reminder else None
        )
        if recent_reminder_at and recent_reminder_at >= stale_cutoff:
            continue

        client.notifications.append(
            NotificationRecord(
                organization_id=client.organization_id,
                title="Weekly check-in overdue",
                body="You have not submitted a check-in in the last 7 days. Log one now to keep coaching, metrics, and recovery feedback current.",
                category=NotificationCategory.CHECKIN_REMINDER,
            )
        )
        changed = True

    if changed:
        db.commit()


def mark_notification_read(notification: NotificationRecord) -> None:
    if notification.read_at is None:
        notification.read_at = datetime.now(UTC)
