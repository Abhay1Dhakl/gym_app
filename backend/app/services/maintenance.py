from __future__ import annotations

from datetime import date

from sqlalchemy.orm import Session

from app.services.billing import sync_subscriptions
from app.services.notifications import ensure_missing_checkin_notifications
from app.services.reports import refresh_monthly_reports


def run_platform_maintenance(
    db: Session,
    organization_id: int | None = None,
    today: date | None = None,
) -> None:
    sync_subscriptions(db, organization_id=organization_id, today=today)
    ensure_missing_checkin_notifications(db, organization_id=organization_id)
    refresh_monthly_reports(db, organization_id=organization_id, today=today)
