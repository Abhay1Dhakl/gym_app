from __future__ import annotations

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select

from app.api.deps import load_user_for_token
from app.db.session import SessionLocal
from app.models.entities import ClientProfile, UserRole
from app.services.message_hub import message_hub


router = APIRouter()


def _can_join_client_conversation(
    client_id: int,
    access_token: str | None,
) -> tuple[bool, str | None]:
    if not access_token:
        return False, "Missing access token"

    db = SessionLocal()
    try:
        user, _session_token = load_user_for_token(db, access_token)

        if user.role == UserRole.ADMIN:
            client_exists = db.scalar(
                select(ClientProfile.id).where(
                    ClientProfile.id == client_id,
                    ClientProfile.organization_id == user.organization_id,
                )
            )
            return (client_exists is not None, None if client_exists is not None else "Conversation not found")

        if user.role == UserRole.CLIENT:
            client_exists = db.scalar(
                select(ClientProfile.id).where(
                    ClientProfile.id == client_id,
                    ClientProfile.user_id == user.id,
                )
            )
            return (client_exists is not None, None if client_exists is not None else "Conversation not found")

        return False, "Forbidden"
    except Exception as exc:
        detail = getattr(exc, "detail", "Unauthorized")
        return False, str(detail)
    finally:
        db.close()


@router.websocket("/messages/{client_id}")
async def stream_messages(
    websocket: WebSocket,
    client_id: int,
    access_token: str | None = Query(default=None),
) -> None:
    allowed, reason = _can_join_client_conversation(client_id, access_token)
    if not allowed:
        await websocket.close(
            code=status.WS_1008_POLICY_VIOLATION,
            reason=reason,
        )
        return

    await message_hub.connect(client_id, websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await message_hub.disconnect(client_id, websocket)
