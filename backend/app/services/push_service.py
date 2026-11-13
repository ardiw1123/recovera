import json
import logging
import os
from typing import Any

from sqlalchemy.orm import Session

from app.config import get_settings
from app.models.notification import Notification
from app.models.user import DeviceToken

logger = logging.getLogger(__name__)

_FCM_MULTICAST_BATCH_SIZE = 500
_JSON_CREDENTIAL_ENV_VARS = (
    "FIREBASE_CREDENTIALS_JSON",
    "FIREBASE_ADMIN_JSON",
    "FIREBASE_SERVICE_ACCOUNT_JSON",
    "FIREBASE_ADMIN",
    "FIREBASE_ADMIN_KEY",
    "FIREBASE_SERVICE_ACCOUNT",
    "FIREBASE_CREDENTIALS",
)
_DEFAULT_SECRET_PATHS = (
    "secrets/firebase-adminsdk.json",
    "firebase-adminsdk.json",
    "/app/secrets/firebase-adminsdk.json",
)


def _parse_credentials_json(raw: str) -> dict[str, Any] | None:
    """Parse Firebase Admin service account JSON, handling multi-line strings and PEM keys."""
    cleaned = raw.strip()
    if not cleaned:
        return None

    cred_dict: Any = None
    try:
        cred_dict = json.loads(cleaned)
    except json.JSONDecodeError:
        try:
            # Handle pasted JSON where PEM private_key contains unescaped literal newlines.
            cred_dict = json.loads(cleaned, strict=False)
        except json.JSONDecodeError as exc:
            logger.error("Failed to parse Firebase credentials JSON: %s", exc)
            return None

    if not isinstance(cred_dict, dict):
        logger.error("Invalid Firebase credentials JSON: expected object, got %s", type(cred_dict).__name__)
        return None

    cred_type = cred_dict.get("type")
    if cred_type != "service_account":
        if "project_info" in cred_dict or "client" in cred_dict:
            logger.error(
                "Invalid Firebase credentials: received Android client google-services.json "
                "instead of a Firebase Admin service_account JSON"
            )
        else:
            logger.error("Invalid Firebase credentials: expected type='service_account', got %r", cred_type)
        return None

    private_key = cred_dict.get("private_key")
    if isinstance(private_key, str):
        cred_dict["private_key"] = (
            private_key.replace("\\r\\n", "\n").replace("\\n", "\n").replace("\r\n", "\n")
        )

    return cred_dict


def _load_firebase_credentials(settings: Any, credentials_module: Any) -> tuple[Any, str | None, str | None]:
    """Load Firebase Admin credential and project_id without falling back after invalid config."""
    cred_json = (getattr(settings, "firebase_credentials_json", "") or "").strip()
    if not cred_json:
        for env_key in _JSON_CREDENTIAL_ENV_VARS:
            env_val = os.environ.get(env_key, "").strip()
            if env_val:
                cred_json = env_val
                break

    configured_project_id = (
        getattr(settings, "firebase_project_id", "")
        or os.environ.get("FIREBASE_PROJECT_ID", "")
        or os.environ.get("GOOGLE_CLOUD_PROJECT", "")
        or os.environ.get("GCLOUD_PROJECT", "")
    ).strip() or None

    if cred_json:
        cred_dict = _parse_credentials_json(cred_json)
        if cred_dict is None:
            return None, None, None

        cert_project_id = (cred_dict.get("project_id") or "").strip() or None
        if configured_project_id and cert_project_id and configured_project_id != cert_project_id:
            logger.warning(
                "Firebase project_id mismatch: env configured %r vs service account %r; "
                "using service account project_id",
                configured_project_id,
                cert_project_id,
            )

        credential = credentials_module.Certificate(cred_dict)
        project_id = cert_project_id or configured_project_id
        return credential, project_id, "json_env"

    configured_path = (getattr(settings, "firebase_credentials_path", "") or "").strip()
    candidate_paths = [configured_path] if configured_path else list(_DEFAULT_SECRET_PATHS)
    for path in candidate_paths:
        if path and os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as fh:
                    cred_dict = _parse_credentials_json(fh.read())
                if cred_dict is None:
                    return None, None, None
                credential = credentials_module.Certificate(cred_dict)
                project_id = (cred_dict.get("project_id") or "").strip() or configured_project_id
                return credential, project_id, f"file:{path}"
            except OSError as exc:
                logger.error("Failed reading Firebase credentials file %s: %s", path, exc)
                return None, None, None

    if os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        return credentials_module.ApplicationDefault(), configured_project_id, "application_default"

    return None, None, None


def _messaging() -> Any:
    """Return initialized firebase_admin.messaging module, or None if unavailable."""
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        if not firebase_admin._apps:
            settings = get_settings()
            credential, project_id, source = _load_firebase_credentials(settings, credentials)
            if credential is None:
                logger.warning(
                    "Firebase Admin SDK not configured; push notifications are disabled "
                    "(set valid FIREBASE_CREDENTIALS_JSON service_account credentials)."
                )
                return None

            options = {"projectId": project_id} if project_id else None
            firebase_admin.initialize_app(credential, options=options)
            logger.info("Firebase Admin SDK initialized via %s (project_id=%s)", source, project_id)

        return messaging
    except Exception as exc:
        logger.warning("Firebase Admin SDK unavailable: %s", exc)
        return None


def _is_unregistered_exception(exc: Any, messaging_module: Any) -> bool:
    """Return True when FCM indicates the registration token or FID is permanently invalid."""
    if exc is None:
        return False
    unregistered_cls = getattr(messaging_module, "UnregisteredError", None)
    if isinstance(unregistered_cls, type) and isinstance(exc, unregistered_cls):
        return True
    code = str(getattr(exc, "code", "") or "").lower()
    if code in {"unregistered", "registration-token-not-registered", "not_found", "not-found"}:
        return True
    text = str(exc).lower()
    return "unregistered" in text or "not registered" in text


def _send_multicast_batch(
    db: Session,
    messaging_module: Any,
    devices: list[DeviceToken],
    *,
    use_fids: bool,
    title: str,
    body: str,
    str_data: dict[str, str],
    user_id: int,
) -> None:
    """Send multicast FCM notifications for either registration tokens or FIDs and prune stale rows."""
    if not devices:
        return

    stale_ids: list[int] = []
    target_kind = "fids" if use_fids else "tokens"

    for offset in range(0, len(devices), _FCM_MULTICAST_BATCH_SIZE):
        batch = devices[offset : offset + _FCM_MULTICAST_BATCH_SIZE]
        targets = [d.fid if use_fids else d.fcm_token for d in batch]
        message_kwargs: dict[str, Any] = {
            target_kind: targets,
            "notification": messaging_module.Notification(title=title, body=body),
            "data": str_data,
            "android": messaging_module.AndroidConfig(
                priority="high",
                notification=messaging_module.AndroidNotification(
                    channel_id="recovera_notifications",
                    priority="high",
                    default_sound=True,
                    default_vibrate_timings=True,
                ),
            ),
        }

        try:
            message = messaging_module.MulticastMessage(**message_kwargs)
            result = messaging_module.send_each_for_multicast(message)
        except Exception as exc:
            logger.exception(
                "FCM multicast batch failed (%s, count=%s) for user %s: %s",
                target_kind,
                len(batch),
                user_id,
                exc,
            )
            continue

        logger.info(
            "FCM push (%s) user=%s success=%s failure=%s",
            target_kind,
            user_id,
            result.success_count,
            result.failure_count,
        )

        for device, resp in zip(batch, result.responses):
            if resp.success:
                continue
            err_code = getattr(resp.exception, "code", None)
            logger.warning(
                "FCM send error device_id=%s (%s) user=%s code=%s error=%s",
                device.id,
                target_kind,
                user_id,
                err_code,
                resp.exception,
            )
            if _is_unregistered_exception(resp.exception, messaging_module):
                stale_ids.append(device.id)

    if stale_ids:
        db.query(DeviceToken).filter(DeviceToken.id.in_(stale_ids)).delete(synchronize_session=False)
        db.commit()


def send_to_user(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> None:
    """Send FCM push notifications to all valid tokens and FIDs registered for user_id."""
    messaging = _messaging()
    if messaging is None:
        return

    devices = db.query(DeviceToken).filter(DeviceToken.user_id == user_id).all()
    if not devices:
        logger.debug("No registered devices for user %s; skipping push", user_id)
        return

    fcm_devices = [d for d in devices if d.fcm_token]
    fid_devices = [d for d in devices if not d.fcm_token and d.fid]
    if not fcm_devices and not fid_devices:
        return

    str_data = {k: str(v) for k, v in (data or {}).items()}
    _send_multicast_batch(
        db,
        messaging,
        fcm_devices,
        use_fids=False,
        title=title,
        body=body,
        str_data=str_data,
        user_id=user_id,
    )
    _send_multicast_batch(
        db,
        messaging,
        fid_devices,
        use_fids=True,
        title=title,
        body=body,
        str_data=str_data,
        user_id=user_id,
    )


def notify_user(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    notif_type: str,
    data: dict[str, Any] | None = None,
) -> Notification:
    """Persist an in-app notification row and trigger an FCM push to the target user."""
    notif = Notification(
        user_id=user_id,
        title=title,
        body=body,
        type=notif_type,
        data=data or {},
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)

    full_data = {"type": notif_type, "notification_id": str(notif.id), **(data or {})}
    send_to_user(db, user_id, title, body, full_data)
    return notif
