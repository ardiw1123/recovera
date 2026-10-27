import logging
import json
from typing import Any

from sqlalchemy.orm import Session

from app.config import get_settings
from app.models.notification import Notification
from app.models.user import DeviceToken

logger = logging.getLogger(__name__)


def _messaging():
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        if not firebase_admin._apps:
            settings = get_settings()
            if settings.firebase_credentials_json:
                credential = credentials.Certificate(json.loads(settings.firebase_credentials_json))
            elif settings.firebase_credentials_path:
                credential = credentials.Certificate(settings.firebase_credentials_path)
            else:
                credential = credentials.ApplicationDefault()
            firebase_admin.initialize_app(credential)
        return messaging
    except Exception:
        logger.info("Firebase Admin is not configured; keeping notifications in-app only.")
        return None


def send_to_user(db: Session, user_id: int, title: str, body: str, data: dict[str, Any] | None = None) -> None:
    devices = db.query(DeviceToken).filter(DeviceToken.user_id == user_id).all()
    messaging = _messaging()
    if not devices or messaging is None:
        return
    tokens = [device.fcm_token for device in devices if device.fcm_token]
    fids = [device.fid for device in devices if device.fid]
    message = messaging.MulticastMessage(
        tokens=tokens or None,
        fids=fids or None,
        notification=messaging.Notification(title=title, body=body),
        data={key: str(value) for key, value in (data or {}).items()},
    )
    try:
        result = messaging.send_each_for_multicast(message)
        token_devices = [device for device in devices if device.fcm_token]
        fid_devices = [device for device in devices if device.fid]
        stale_devices = []
        for device, response in zip(token_devices + fid_devices, result.responses):
            error_code = getattr(response.exception, "code", None) if response.exception else None
            if not response.success and error_code in {
                "registration-token-not-registered",
                "invalid-registration-token",
                "unregistered",
            }:
                stale_devices.append(device)
        for device in stale_devices:
            db.delete(device)
        if stale_devices:
            db.commit()
    except Exception:
        logger.exception("Failed to send FCM notification to user %s", user_id)


def notify_user(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    notification_type: str,
    data: dict[str, Any] | None = None,
) -> Notification:
    notification = Notification(
        user_id=user_id,
        title=title,
        body=body,
        type=notification_type,
        data=data or {},
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    send_to_user(db, user_id, title, body, {"type": notification_type, **(data or {})})
    return notification
