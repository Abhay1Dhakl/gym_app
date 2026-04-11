from __future__ import annotations

from datetime import UTC, date, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.entities import (
    ClientProfile,
    ClientStatus,
    NotificationCategory,
    NotificationRecord,
    ProgressReport,
)


def refresh_monthly_reports(
    db: Session,
    organization_id: int | None = None,
    today: date | None = None,
) -> None:
    current_day = today or date.today()
    period_start = current_day.replace(day=1)
    statement = (
        select(ClientProfile)
        .options(
            selectinload(ClientProfile.metrics),
            selectinload(ClientProfile.checkins),
            selectinload(ClientProfile.progress_reports),
            selectinload(ClientProfile.notifications),
        )
        .where(ClientProfile.status == ClientStatus.ACTIVE)
    )
    if organization_id is not None:
        statement = statement.where(ClientProfile.organization_id == organization_id)

    clients = db.scalars(statement).all()
    changed = False
    for client in clients:
        changed |= _upsert_monthly_report(client, period_start, current_day)

    if changed:
        db.commit()


def _upsert_monthly_report(client: ClientProfile, period_start: date, period_end: date) -> bool:
    metrics = [
        item
        for item in client.metrics
        if period_start <= item.logged_at.date() <= period_end
    ]
    checkins = [
        item
        for item in client.checkins
        if period_start <= item.submitted_at.date() <= period_end
    ]

    body_weight_change = _delta(metrics, "body_weight")
    squat_gain = _delta(metrics, "squat_1rm")
    bench_gain = _delta(metrics, "bench_1rm")
    deadlift_gain = _delta(metrics, "deadlift_1rm")

    adherence_values = [
        value
        for value in (
            [metric.adherence_score for metric in metrics]
            + [checkin.adherence_score for checkin in checkins]
        )
        if value is not None
    ]
    adherence_average = (
        round(sum(adherence_values) / len(adherence_values), 1)
        if adherence_values
        else None
    )

    summary_parts = [
        _delta_copy("body weight", body_weight_change, "kg"),
        _delta_copy("squat strength", squat_gain, "kg"),
        _delta_copy("bench strength", bench_gain, "kg"),
        _delta_copy("deadlift strength", deadlift_gain, "kg"),
    ]
    summary = (
        " ".join(part for part in summary_parts if part)
        or "Progress data is building. Keep logging metrics and check-ins this month."
    )
    if adherence_average is not None:
        summary = f"{summary} Average adherence is {adherence_average}% across this month."

    report = next(
        (
            item
            for item in client.progress_reports
            if item.period_start == period_start
        ),
        None,
    )
    created = report is None
    if report is None:
        report = ProgressReport(
            period_start=period_start,
            period_end=period_end,
            summary=summary,
            body_weight_change=body_weight_change,
            squat_gain=squat_gain,
            bench_gain=bench_gain,
            deadlift_gain=deadlift_gain,
            adherence_average=adherence_average,
            checkins_completed=len(checkins),
        )
        client.progress_reports.append(report)
    else:
        report.period_end = period_end
        report.summary = summary
        report.body_weight_change = body_weight_change
        report.squat_gain = squat_gain
        report.bench_gain = bench_gain
        report.deadlift_gain = deadlift_gain
        report.adherence_average = adherence_average
        report.checkins_completed = len(checkins)

    if created:
        already_notified = any(
            notification.category == NotificationCategory.REPORT
            and notification.created_at.date() >= period_start
            for notification in client.notifications
        )
        if not already_notified:
            client.notifications.append(
                NotificationRecord(
                    organization_id=client.organization_id,
                    title="Monthly progress report updated",
                    body=f"Your {period_start.strftime('%B')} progress report is ready with fresh bodyweight, strength, and compliance trends.",
                    category=NotificationCategory.REPORT,
                )
            )

    return True


def _delta(metrics: list[object], field_name: str) -> float | None:
    values = [
        getattr(metric, field_name)
        for metric in sorted(metrics, key=lambda item: item.logged_at)
        if getattr(metric, field_name) is not None
    ]
    if len(values) < 2:
        return None
    return round(values[-1] - values[0], 1)


def _delta_copy(label: str, delta: float | None, unit: str) -> str:
    if delta is None:
        return ""
    direction = "up" if delta >= 0 else "down"
    return f"{label.title()} is {direction} {abs(delta):.1f}{unit}."


def serialize_report(report: ProgressReport | None) -> dict[str, object] | None:
    if report is None:
        return None
    generated_at = report.updated_at if report.updated_at else datetime.now(UTC)
    return {
        "id": report.id,
        "period_start": report.period_start,
        "period_end": report.period_end,
        "summary": report.summary,
        "body_weight_change": report.body_weight_change,
        "squat_gain": report.squat_gain,
        "bench_gain": report.bench_gain,
        "deadlift_gain": report.deadlift_gain,
        "adherence_average": report.adherence_average,
        "checkins_completed": report.checkins_completed,
        "generated_at": generated_at,
    }
