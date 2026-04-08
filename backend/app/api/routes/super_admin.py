from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_super_admin_user
from app.core.security import hash_password
from app.db.session import get_db
from app.models.entities import ClientStatus, Organization, User, UserRole
from app.schemas.super_admin import CreateGymAdminRequest, GymAdminSummaryResponse, SuperAdminDashboardResponse
from app.services.organizations import generate_unique_slug


router = APIRouter()


def _serialize_admin(admin_user: User) -> GymAdminSummaryResponse:
    organization = admin_user.organization
    clients = organization.clients if organization else []
    return GymAdminSummaryResponse(
        id=admin_user.id,
        full_name=admin_user.full_name,
        email=admin_user.email,
        organization_id=organization.id if organization else admin_user.organization_id or 0,
        gym_name=organization.name if organization else "Unassigned gym",
        gym_logo_url=organization.logo_url if organization else None,
        active_clients=sum(1 for client in clients if client.status == ClientStatus.ACTIVE),
        invited_clients=sum(1 for client in clients if client.status == ClientStatus.INVITED),
        created_at=admin_user.created_at,
    )


@router.get("/dashboard", response_model=SuperAdminDashboardResponse)
def dashboard(
    _user: User = Depends(get_current_super_admin_user),
    db: Session = Depends(get_db),
) -> SuperAdminDashboardResponse:
    organizations = db.scalars(
        select(Organization)
        .options(selectinload(Organization.users), selectinload(Organization.clients))
        .order_by(Organization.created_at.desc())
    ).all()

    admin_count = sum(
        1
        for organization in organizations
        for user in organization.users
        if user.role == UserRole.ADMIN
    )
    client_count = sum(len(organization.clients) for organization in organizations)
    active_client_count = sum(
        1
        for organization in organizations
        for client in organization.clients
        if client.status == ClientStatus.ACTIVE
    )
    invited_client_count = sum(
        1
        for organization in organizations
        for client in organization.clients
        if client.status == ClientStatus.INVITED
    )

    return SuperAdminDashboardResponse(
        total_gyms=len(organizations),
        total_admins=admin_count,
        total_clients=client_count,
        active_clients=active_client_count,
        invited_clients=invited_client_count,
    )


@router.get("/admins", response_model=list[GymAdminSummaryResponse])
def list_admins(
    _user: User = Depends(get_current_super_admin_user),
    db: Session = Depends(get_db),
) -> list[GymAdminSummaryResponse]:
    admins = db.scalars(
        select(User)
        .options(selectinload(User.organization).selectinload(Organization.clients))
        .where(User.role == UserRole.ADMIN)
        .order_by(User.created_at.desc())
    ).all()
    return [_serialize_admin(admin_user) for admin_user in admins]


@router.post("/admins", response_model=GymAdminSummaryResponse, status_code=status.HTTP_201_CREATED)
def create_admin(
    payload: CreateGymAdminRequest,
    _user: User = Depends(get_current_super_admin_user),
    db: Session = Depends(get_db),
) -> GymAdminSummaryResponse:
    if db.scalar(select(User.id).where(User.email == payload.email)) is not None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already in use")

    organization = Organization(
        name=payload.gym_name,
        slug=generate_unique_slug(db, payload.gym_name),
        logo_url=payload.gym_logo_url,
    )
    db.add(organization)
    db.flush()

    admin_user = User(
        full_name=payload.full_name,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role=UserRole.ADMIN,
        organization_id=organization.id,
    )
    db.add(admin_user)
    db.commit()

    created_admin = db.scalar(
        select(User)
        .options(selectinload(User.organization).selectinload(Organization.clients))
        .where(User.id == admin_user.id)
    )
    if not created_admin:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to create admin")

    return _serialize_admin(created_admin)
