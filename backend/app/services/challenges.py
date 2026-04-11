from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.entities import (
    ChallengeMetricType,
    CheckIn,
    ClientProfile,
    CommunityChallenge,
    MetricEntry,
    Organization,
)


@dataclass(frozen=True)
class LeaderboardEntry:
    client_id: int
    client_name: str
    score: float
    display_score: str
    rank: int


def ensure_default_challenge(db: Session, organization: Organization, today: date | None = None) -> None:
    current_day = today or date.today()
    existing = db.scalar(
        select(CommunityChallenge.id).where(CommunityChallenge.organization_id == organization.id)
    )
    if existing is not None:
        return

    db.add(
        CommunityChallenge(
            organization_id=organization.id,
            title=f"{current_day.strftime('%B')} Consistency Ladder",
            description="Rank clients by average adherence to reinforce consistent execution and habit follow-through.",
            metric_type=ChallengeMetricType.ADHERENCE_AVERAGE,
            start_date=current_day.replace(day=1),
            end_date=current_day.replace(day=28),
            unit_label="avg adherence",
        )
    )
    db.commit()


def get_active_challenge(
    db: Session,
    organization_id: int,
    today: date | None = None,
) -> CommunityChallenge | None:
    current_day = today or date.today()
    return db.scalar(
        select(CommunityChallenge)
        .where(
            CommunityChallenge.organization_id == organization_id,
            CommunityChallenge.start_date <= current_day,
            CommunityChallenge.end_date >= current_day,
        )
        .order_by(CommunityChallenge.created_at.desc())
    )


def build_challenge_snapshot(
    db: Session,
    organization_id: int,
    today: date | None = None,
) -> dict[str, object] | None:
    challenge = get_active_challenge(db, organization_id, today=today)
    if challenge is None:
        return None

    leaderboard = compute_leaderboard(db, challenge)
    return {
        "id": challenge.id,
        "title": challenge.title,
        "description": challenge.description,
        "metric_type": challenge.metric_type.value,
        "start_date": challenge.start_date,
        "end_date": challenge.end_date,
        "unit_label": challenge.unit_label,
        "leaderboard": [
            {
                "client_id": item.client_id,
                "client_name": item.client_name,
                "score": item.score,
                "display_score": item.display_score,
                "rank": item.rank,
            }
            for item in leaderboard
        ],
    }


def compute_leaderboard(db: Session, challenge: CommunityChallenge) -> list[LeaderboardEntry]:
    clients = db.scalars(
        select(ClientProfile)
        .options(selectinload(ClientProfile.checkins), selectinload(ClientProfile.metrics))
        .where(ClientProfile.organization_id == challenge.organization_id)
    ).all()

    ranked = []
    for client in clients:
        score = _score_client(client, challenge.metric_type, challenge.start_date, challenge.end_date)
        display_score = _format_score(score, challenge.metric_type, challenge.unit_label)
        ranked.append((client, score, display_score))

    ranked.sort(key=lambda item: item[1], reverse=True)
    return [
        LeaderboardEntry(
            client_id=client.id,
            client_name=client.full_name,
            score=round(score, 1),
            display_score=display_score,
            rank=index + 1,
        )
        for index, (client, score, display_score) in enumerate(ranked)
    ]


def _score_client(
    client: ClientProfile,
    metric_type: ChallengeMetricType,
    start_date: date,
    end_date: date,
) -> float:
    checkins = [
        item for item in client.checkins if start_date <= item.submitted_at.date() <= end_date
    ]
    metrics = [
        item for item in client.metrics if start_date <= item.logged_at.date() <= end_date
    ]

    if metric_type == ChallengeMetricType.CHECKIN_STREAK:
        return float(len(checkins))
    if metric_type == ChallengeMetricType.ADHERENCE_AVERAGE:
        values = [item.adherence_score for item in checkins if item.adherence_score is not None]
        return float(sum(values) / len(values)) if values else 0.0
    if metric_type == ChallengeMetricType.SQUAT_GAIN:
        return _metric_delta(metrics, "squat_1rm")
    if metric_type == ChallengeMetricType.DEADLIFT_GAIN:
        return _metric_delta(metrics, "deadlift_1rm")
    return 0.0


def _metric_delta(metrics: list[MetricEntry], field_name: str) -> float:
    values = [
        getattr(metric, field_name)
        for metric in sorted(metrics, key=lambda item: item.logged_at)
        if getattr(metric, field_name) is not None
    ]
    if len(values) < 2:
        return 0.0
    return float(values[-1] - values[0])


def _format_score(
    score: float,
    metric_type: ChallengeMetricType,
    unit_label: str | None,
) -> str:
    if metric_type == ChallengeMetricType.CHECKIN_STREAK:
        return f"{int(score)} check-ins"
    if metric_type == ChallengeMetricType.ADHERENCE_AVERAGE:
        return f"{score:.1f}%"
    suffix = unit_label or "kg"
    return f"{score:.1f} {suffix}"
