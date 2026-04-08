from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import generate_session_token, hash_password, hash_token, token_expiry, verify_password
from app.db.session import get_db
from app.models.entities import ClientProfile, ClientStatus, SessionToken, User, UserRole
from app.schemas.auth import ActivateClientRequest, AuthResponse, LoginRequest, MeResponse


router = APIRouter()


def _serialize_auth(user: User, access_token: str) -> AuthResponse:
    organization = user.organization
    return AuthResponse(
        access_token=access_token,
        role=user.role.value,
        user_id=user.id,
        full_name=user.full_name,
        organization_id=organization.id if organization else user.organization_id,
        organization_name=organization.name if organization else None,
        organization_logo_url=organization.logo_url if organization else None,
    )


def _issue_token(db: Session, user: User) -> AuthResponse:
    token = generate_session_token()
    db.execute(delete(SessionToken).where(SessionToken.user_id == user.id))
    session_token = SessionToken(user_id=user.id, token_hash=hash_token(token), expires_at=token_expiry())
    db.add(session_token)
    db.commit()
    db.refresh(user)
    return _serialize_auth(user, token)


@router.post("/login", response_model=AuthResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> AuthResponse:
    user = db.scalar(select(User).where(User.email == payload.email))
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is inactive")
    return _issue_token(db, user)


@router.post("/client/activate", response_model=AuthResponse)
def activate_client(payload: ActivateClientRequest, db: Session = Depends(get_db)) -> AuthResponse:
    profile = db.scalar(select(ClientProfile).where(ClientProfile.invite_code == payload.invite_code.upper()))
    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invite code not found")
    if profile.user_id is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invite code already used")
    if db.scalar(select(User).where(User.email == payload.email)):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already in use")

    user = User(
        email=payload.email,
        full_name=profile.full_name,
        password_hash=hash_password(payload.password),
        role=UserRole.CLIENT,
        organization_id=profile.organization_id,
    )
    db.add(user)
    db.flush()

    profile.user_id = user.id
    profile.contact_email = payload.email
    profile.status = ClientStatus.ACTIVE
    db.commit()
    db.refresh(user)
    return _issue_token(db, user)


@router.get("/me", response_model=MeResponse)
def me(auth: tuple[User, SessionToken] = Depends(get_current_user)) -> MeResponse:
    user, session_token = auth
    profile = user.client_profile
    organization = user.organization
    return MeResponse(
        id=user.id,
        email=user.email,
        role=user.role.value,
        full_name=user.full_name,
        organization_id=organization.id if organization else user.organization_id,
        organization_name=organization.name if organization else None,
        organization_logo_url=organization.logo_url if organization else None,
        client_id=profile.id if profile else None,
        client_name=profile.full_name if profile else None,
        expires_at=session_token.expires_at,
    )
