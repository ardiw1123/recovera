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
        import os
        import firebase_admin
        from firebase_admin import credentials, messaging

        if not firebase_admin._apps:
            settings = get_settings()
            cred_json = (
                getattr(settings, "firebase_credentials_json", "")
                or os.environ.get("FIREBASE_CREDENTIALS_JSON", "")
                or os.environ.get("FIREBASE_ADMIN_JSON", "")
                or os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "")
            )
            if cred_json and cred_json.strip():
                raw = cred_json.strip()
                try:
                    cred_dict = json.loads(raw)
                except Exception:
                    cred_dict = json.loads(raw.replace("\r\n", "\n").replace("\n", "\n"))
                credential = credentials.Certificate(cred_dict)
            elif settings.firebase_credentials_path and os.path.exists(settings.firebase_credentials_path):
                credential = credentials.Certificate(settings.firebase_credentials_path)
            elif os.path.exists("backend/sercrets/firebase-admin.json"):
                credential = credentials.Certificate("backend/sercrets/firebase-admin.json")
            elif os.path.exists("backend/secrets/firebase-admin.json"):
                credential = credentials.Certificate("backend/secrets/firebase-admin.json")
            elif os.path.exists("sercrets/firebase-admin.json"):
                credential = credentials.Certificate("sercrets/firebase-admin.json")
            elif os.path.exists("secrets/firebase-admin.json"):
                credential = credentials.Certificate("secrets/firebase-admin.json")
            else:
                credential = credentials.ApplicationDefault()
            firebase_admin.initialize_app(credential)
        return messaging
    except Exception as exc:
        logger.warning("Firebase Admin is not configured (%s); keeping notifications in-app only.", exc)
        return None


def send_to_user(db: Session, user_id: int, title: str, body: str, data: dict[str, Any] | None = None) -> None:
    devices = db.query(DeviceToken).filter(DeviceToken.user_id == user_id).all()
    messaging = _messaging()
    if not devices or messaging is None:
        return
    tokens = [device.fcm_token or device.fid for device in devices if (device.fcm_token or device.fid)]
    if not tokens:
        return

    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data={key: str(value) for key, value in (data or {}).items()},
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                title=title,
                body=body,
                channel_id="recovera_notifications",
                sound="default",
                priority="high",
                default_vibrate_timings=True,
                default_sound=True,
            ),
        ),
    )
    try:
        result = messaging.send_each_for_multicast(message)
        stale_devices = []
        for device, response in zip(devices, result.responses):
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
