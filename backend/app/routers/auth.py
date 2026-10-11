from typing import Annotated
from fastapi import APIRouter, Body, status

from app.core.dependencies import CurrentUserDep, DbSessionDep
from app.schemas.auth import LoginRequest, LogoutRequest, RefreshRequest, RegisterRequest, TokenResponse
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.services.auth_service import login_user, logout_user, refresh_access_token, register_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=ResponseEnvelope[TokenResponse],
)
async def register(
    db: DbSessionDep,
    payload: Annotated[RegisterRequest, Body()],
) -> dict:
    result = register_user(db, payload)
    return wrap_success(result.model_dump())


@router.post(
    "/login",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[TokenResponse],
)
async def login(
    db: DbSessionDep,
    payload: Annotated[LoginRequest, Body()],
) -> dict:
    result = login_user(db, payload)
    return wrap_success(result.model_dump())


@router.post(
    "/refresh",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[TokenResponse],
)
async def refresh_token(
    db: DbSessionDep,
    payload: Annotated[RefreshRequest, Body()],
) -> dict:
    result = refresh_access_token(db, payload.refresh_token)
    return wrap_success(result.model_dump())


@router.post(
    "/logout",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[dict],
)
async def logout(
    db: DbSessionDep,
    current_user: CurrentUserDep,
    payload: Annotated[LogoutRequest | None, Body()] = None,
) -> dict:
    raw_token = payload.refresh_token if payload else None
    logout_user(db, current_user.id, raw_token)
    return wrap_success({"message": "Successfully logged out and session revoked"})
