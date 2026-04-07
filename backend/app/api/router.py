from fastapi import APIRouter

from app.api.routes import admin, auth, client, health


api_router = APIRouter()
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(client.router, prefix="/client", tags=["client"])
