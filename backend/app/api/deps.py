from __future__ import annotations

from datetime import datetime, UTC

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.security import hash_token
from app.db.session import get_db
from app.models.entities import ClientProfile, Organization, SessionToken, TrainingProgram, User, UserRole, WorkoutDay


bearer_scheme = HTTPBearer(auto_error=False)


def _normalize_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def load_user_for_token(db: Session, token: str) -> tuple[User, SessionToken]:
    hashed = hash_token(token)
    statement = (
        select(SessionToken)
        .options(
            selectinload(SessionToken.user).selectinload(User.client_profile),
            selectinload(SessionToken.user).selectinload(User.organization),
        )
        .where(SessionToken.token_hash == hashed)
    )
    session_token = db.scalar(statement)
    if not session_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid access token")
    if _normalize_utc(session_token.expires_at) < datetime.now(UTC):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Access token expired")
    return session_token.user, session_token


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> tuple[User, SessionToken]:
    if credentials is None or not credentials.credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing access token")
    return load_user_for_token(db, credentials.credentials)


def require_role(role: UserRole):
    def dependency(auth: tuple[User, SessionToken] = Depends(get_current_user)) -> User:
        user, _session_token = auth
        if user.role != role:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return user

    return dependency


def get_current_super_admin_user(user: User = Depends(require_role(UserRole.SUPER_ADMIN))) -> User:
    return user


def get_current_admin_user(
    auth: tuple[User, SessionToken] = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    user, _session_token = auth
    if user.role != UserRole.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    scoped_user = db.scalar(
        select(User).options(selectinload(User.organization)).where(User.id == user.id)
    ) or user
    if scoped_user.organization_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin account is not linked to a gym organization",
        )
    return scoped_user


def get_current_client_profile(
    user: User = Depends(require_role(UserRole.CLIENT)),
    db: Session = Depends(get_db),
) -> ClientProfile:
    statement = (
        select(ClientProfile)
        .options(
            selectinload(ClientProfile.organization),
            selectinload(ClientProfile.program)
            .selectinload(TrainingProgram.workout_days)
            .selectinload(WorkoutDay.exercises),
            selectinload(ClientProfile.nutrition_plan),
            selectinload(ClientProfile.checkins),
            selectinload(ClientProfile.messages),
            selectinload(ClientProfile.invoices),
        )
        .where(ClientProfile.user_id == user.id)
    )
    if user.organization_id is not None:
        statement = statement.where(ClientProfile.organization_id == user.organization_id)

    profile = db.scalar(statement)
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client profile not found")
    return profile
