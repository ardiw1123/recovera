from typing import Annotated
from fastapi import APIRouter, Path, status

from app.core.dependencies import CurrentUserDep, DbSessionDep
from app.core.exceptions import AppException
from app.models.notification import Notification
from app.schemas.envelope import ResponseEnvelope, wrap_success
from app.schemas.notification import NotificationResponse

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get(
    "",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[list[NotificationResponse]],
)
async def list_notifications(
    db: DbSessionDep,
    current_user: CurrentUserDep,
) -> dict:
    notifs = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .all()
    )

    formatted = [
        NotificationResponse(
            id=n.id,
            title=n.title,
            body=n.body,
            type=n.type,
            is_read=n.is_read,
            created_at=n.created_at.isoformat(),
        ).model_dump()
        for n in notifs
    ]
    return wrap_success(formatted)


@router.patch(
    "/{notification_id}/read",
    status_code=status.HTTP_200_OK,
    response_model=ResponseEnvelope[NotificationResponse],
)
async def mark_notification_read(
    db: DbSessionDep,
    current_user: CurrentUserDep,
    notification_id: Annotated[int, Path(ge=1, description="Notification ID")],
) -> dict:
    notif = db.query(Notification).filter(Notification.id == notification_id).first()
    if not notif:
        raise AppException(
            code="NOTIFICATION_NOT_FOUND",
            message=f"Notification #{notification_id} not found",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    if notif.user_id != current_user.id:
        raise AppException(
            code="FORBIDDEN",
            message="You do not have permission to modify this notification",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    notif.is_read = True
    db.commit()
    db.refresh(notif)

    return wrap_success(
        NotificationResponse(
            id=notif.id,
            title=notif.title,
            body=notif.body,
            type=notif.type,
            is_read=notif.is_read,
            created_at=notif.created_at.isoformat(),
        ).model_dump()
    )
