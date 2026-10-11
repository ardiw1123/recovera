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
    existing = (
        db.query(DeviceToken)
        .filter(
            DeviceToken.user_id == current_user.id,
            DeviceToken.fcm_token == payload.fcm_token,
        )
        .first()
    )

    now_utc = datetime.now(timezone.utc)
    if existing:
        existing.updated_at = now_utc
    else:
        new_token = DeviceToken(
            user_id=current_user.id,
            fcm_token=payload.fcm_token,
            updated_at=now_utc,
        )
        db.add(new_token)

    db.commit()
    return wrap_success({"message": "Device token registered successfully"})
