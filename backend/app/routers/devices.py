from datetime import datetime, timezone
from typing import Annotated
from fastapi import APIRouter, Body, status

from app.core.dependencies import CurrentUserDep, DbSessionDep
from app.models.user import DeviceToken
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.notification import DeviceTokenRequest

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[dict],
)
async def register_device_token(
    db: DbSessionDep,
    current_user: CurrentUserDep,
    payload: Annotated[DeviceTokenRequest, Body()],
) -> dict:
    identifier_column = DeviceToken.fid if payload.fid else DeviceToken.fcm_token
    identifier = payload.fid or payload.fcm_token
    existing = db.query(DeviceToken).filter(
        DeviceToken.user_id == current_user.id,
        identifier_column == identifier,
    ).first()

    now_utc = datetime.now(timezone.utc)
    if existing:
        existing.updated_at = now_utc
    else:
        new_device = DeviceToken(
            user_id=current_user.id,
            fid=payload.fid,
            fcm_token=payload.fcm_token,
            updated_at=now_utc,
        )
        db.add(new_device)

    db.commit()
    return wrap_success({"message": "Device registered successfully"})
