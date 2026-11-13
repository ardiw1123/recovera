import json
import sys
import types
from contextlib import ExitStack
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import get_settings
from app.database import Base
from app.models.notification import Notification
from app.models.user import DeviceToken, RefreshToken, User
from app.routers.auth import logout as logout_route
from app.routers.devices import register_device_token
from app.schemas.auth import LogoutRequest
from app.schemas.notification import DeviceTokenRequest
from app.services import auth_service, push_service


def _run_sync(coro):
    """Step a coroutine without asyncio.run so tests stay fast and socket-free."""
    try:
        coro.send(None)
    except StopIteration as exc:
        return exc.value
    raise AssertionError("Expected coroutine to complete synchronously")


def _make_db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    Session = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return Session(), engine


def _make_fake_firebase_admin():
    """Build an in-memory stub mimicking firebase_admin SDK v7.5+ project_id resolution."""
    state = {
        "app": None,
        "initialized_calls": [],
        "multicast_calls": [],
        "next_batch_handler": None,
    }

    class FakeFirebaseError(Exception):
        def __init__(self, code: str, message: str = ""):
            super().__init__(message or code)
            self.code = code

    class FakeNotFoundError(FakeFirebaseError):
        def __init__(self, message: str = "Requested entity was not found."):
            super().__init__("NOT_FOUND", message)

    class FakeUnregisteredError(FakeNotFoundError):
        pass

    class FakeInvalidArgumentError(FakeFirebaseError):
        def __init__(self, message: str = "Invalid argument"):
            super().__init__("INVALID_ARGUMENT", message)

    class FakeCertificate:
        def __init__(self, cred):
            if not isinstance(cred, dict) or cred.get("type") != "service_account":
                raise ValueError("Invalid service account certificate")
            self.cred = cred
            self.project_id = cred.get("project_id")

    class FakeApplicationDefault:
        def __init__(self):
            self.project_id = None

    class FakeApp:
        def __init__(self, credential, options):
            self.credential = credential
            self.options = options or {}
            self.project_id = (
                self.options.get("projectId")
                or getattr(credential, "project_id", None)
                or None
            )

    class FakeMulticastMessage:
        def __init__(self, tokens=None, fids=None, notification=None, data=None, android=None):
            if not tokens and not fids:
                raise ValueError("At least one of tokens or fids is required")
            self.tokens = list(tokens) if tokens else None
            self.fids = list(fids) if fids else None
            self.notification = notification
            self.data = data
            self.android = android

    class FakeNotification:
        def __init__(self, title=None, body=None):
            self.title = title
            self.body = body

    class FakeAndroidConfig:
        def __init__(self, priority=None, notification=None):
            self.priority = priority
            self.notification = notification

    class FakeAndroidNotification:
        def __init__(self, **kwargs):
            self.kwargs = kwargs

    class FakeSendResponse:
        def __init__(self, message_id=None, exception=None):
            self.message_id = message_id
            self.exception = exception

        @property
        def success(self):
            return self.exception is None

    class FakeBatchResponse:
        def __init__(self, responses):
            self.responses = responses
            self.success_count = sum(1 for r in responses if r.success)
            self.failure_count = sum(1 for r in responses if not r.success)

    def fake_initialize_app(credential=None, options=None, name="[DEFAULT]"):
        app = FakeApp(credential, options)
        firebase_admin_mod._apps.append(app)
        state["app"] = app
        state["initialized_calls"].append({"credential": credential, "options": options, "name": name})
        return app

    def fake_get_app(name="[DEFAULT]"):
        if not firebase_admin_mod._apps:
            raise ValueError("The default Firebase app does not exist.")
        return firebase_admin_mod._apps[0]

    def fake_send_each_for_multicast(message, dry_run=False, app=None):
        active_app = app or fake_get_app()
        resolved_project_id = (
            active_app.project_id
            or sys.modules["os"].environ.get("GOOGLE_CLOUD_PROJECT")
            or sys.modules["os"].environ.get("GCLOUD_PROJECT")
        )
        if not resolved_project_id:
            raise ValueError(
                "Project ID is required to access Cloud Messaging service. Either set the projectId option, "
                "or use service account credentials. Alternatively, set the GOOGLE_CLOUD_PROJECT environment variable."
            )
        state["multicast_calls"].append((message, resolved_project_id))
        handler = state["next_batch_handler"]
        if handler:
            return handler(message, FakeSendResponse, FakeBatchResponse, FakeUnregisteredError, FakeInvalidArgumentError)
        targets = (message.tokens or []) + (message.fids or [])
        return FakeBatchResponse([FakeSendResponse(message_id=f"msg-{i}") for i, _ in enumerate(targets)])

    firebase_admin_mod = types.ModuleType("firebase_admin")
    firebase_admin_mod._apps = []
    firebase_admin_mod.initialize_app = fake_initialize_app
    firebase_admin_mod.get_app = fake_get_app

    credentials_mod = types.ModuleType("firebase_admin.credentials")
    credentials_mod.Certificate = FakeCertificate
    credentials_mod.ApplicationDefault = FakeApplicationDefault

    messaging_mod = types.ModuleType("firebase_admin.messaging")
    messaging_mod.MulticastMessage = FakeMulticastMessage
    messaging_mod.Notification = FakeNotification
    messaging_mod.AndroidConfig = FakeAndroidConfig
    messaging_mod.AndroidNotification = FakeAndroidNotification
    messaging_mod.UnregisteredError = FakeUnregisteredError
    messaging_mod.InvalidArgumentError = FakeInvalidArgumentError
    messaging_mod.send_each_for_multicast = fake_send_each_for_multicast

    exceptions_mod = types.ModuleType("firebase_admin.exceptions")
    exceptions_mod.FirebaseError = FakeFirebaseError
    exceptions_mod.NotFoundError = FakeNotFoundError
    exceptions_mod.InvalidArgumentError = FakeInvalidArgumentError

    firebase_admin_mod.credentials = credentials_mod
    firebase_admin_mod.messaging = messaging_mod
    firebase_admin_mod.exceptions = exceptions_mod

    modules = {
        "firebase_admin": firebase_admin_mod,
        "firebase_admin.credentials": credentials_mod,
        "firebase_admin.messaging": messaging_mod,
        "firebase_admin.exceptions": exceptions_mod,
    }
    return modules, state


@pytest.fixture
def isolated_push_env(monkeypatch):
    modules, state = _make_fake_firebase_admin()
    for name, mod in modules.items():
        monkeypatch.setitem(sys.modules, name, mod)
    for var in (
        "FIREBASE_CREDENTIALS_JSON",
        "FIREBASE_ADMIN_JSON",
        "FIREBASE_SERVICE_ACCOUNT_JSON",
        "FIREBASE_CREDENTIALS_PATH",
        "FIREBASE_ADMIN_PATH",
        "FIREBASE_ADMIN",
        "FIREBASE_ADMIN_KEY",
        "FIREBASE_SERVICE_ACCOUNT",
        "FIREBASE_CREDENTIALS",
        "FIREBASE_CONFIG",
        "FIREBASE_PROJECT_ID",
        "GOOGLE_CLOUD_PROJECT",
        "GCLOUD_PROJECT",
    ):
        monkeypatch.delenv(var, raising=False)
    get_settings.cache_clear()
    yield state
    get_settings.cache_clear()


def _create_user(db, email: str, role: str = "buyer") -> User:
    user = User(
        email=email,
        password_hash="hashed",
        role=role,
        name=email.split("@")[0],
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def test_messaging_initializes_from_multiline_json_and_prefers_service_account_project_id(
    isolated_push_env, monkeypatch
):
    pretty_json = """{
  "type": "service_account",
  "project_id": "recovera-c5646",
  "private_key_id": "ae6a7d60285dfce8743893a94dd851a8fe57b21e",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nMIIEvQIBADANBg==\\n-----END PRIVATE KEY-----\\n",
  "client_email": "firebase-adminsdk@recovera-c5646.iam.gserviceaccount.com",
  "token_uri": "https://oauth2.googleapis.com/token"
}"""
    monkeypatch.setenv("FIREBASE_CREDENTIALS_JSON", pretty_json)
    monkeypatch.setenv("FIREBASE_CREDENTIALS_PATH", "secrets/does-not-exist.json")
    # Even if Railway GOOGLE_CLOUD_PROJECT has a typo ("recovera"), service account project_id wins.
    monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "recovera")
    get_settings.cache_clear()

    db, engine = _make_db_session()
    try:
        user = _create_user(db, "buyer163@recovera.id")
        db.add(DeviceToken(user_id=user.id, fcm_token="fcm-token-163"))
        db.commit()

        push_service.notify_user(db, user.id, "Pesanan", "Berhasil", "order_ready", {"order_id": 10})

        assert len(isolated_push_env["initialized_calls"]) == 1
        init_call = isolated_push_env["initialized_calls"][0]
        assert init_call["options"] == {"projectId": "recovera-c5646"}
        assert len(isolated_push_env["multicast_calls"]) == 1
        _, resolved_project_id = isolated_push_env["multicast_calls"][0]
        assert resolved_project_id == "recovera-c5646"
    finally:
        db.close()
        engine.dispose()


def test_messaging_handles_raw_newlines_inside_private_key_json(isolated_push_env, monkeypatch):
    # Simulates copy/paste into an env field that turned \n inside private_key into actual newlines.
    raw_newline_json = (
        '{\n'
        '  "type": "service_account",\n'
        '  "project_id": "recovera-c5646",\n'
        '  "private_key": "-----BEGIN PRIVATE KEY-----\nLINE1\nLINE2\n-----END PRIVATE KEY-----\n",\n'
        '  "client_email": "firebase@recovera-c5646.iam.gserviceaccount.com"\n'
        '}'
    )
    monkeypatch.setenv("FIREBASE_CREDENTIALS_JSON", raw_newline_json)
    get_settings.cache_clear()

    messaging = push_service._messaging()
    assert messaging is not None
    cred = isolated_push_env["initialized_calls"][0]["credential"]
    assert "-----BEGIN PRIVATE KEY-----\nLINE1\nLINE2\n-----END PRIVATE KEY-----" in cred.cred["private_key"]


def test_messaging_rejects_google_services_json_without_silent_application_default_fallback(
    isolated_push_env, monkeypatch
):
    client_google_services = json.dumps({
        "project_info": {"project_id": "recovera-c5646"},
        "client": [{"client_info": {"android_client_info": {"package_name": "com.example.recovera"}}}],
    })
    monkeypatch.setenv("FIREBASE_CREDENTIALS_JSON", client_google_services)
    get_settings.cache_clear()

    messaging = push_service._messaging()
    assert messaging is None
    assert isolated_push_env["initialized_calls"] == []


def test_send_to_user_splits_tokens_and_fids_and_deletes_exact_unregistered_rows(
    isolated_push_env, monkeypatch
):
    service_account = json.dumps({
        "type": "service_account",
        "project_id": "recovera-c5646",
        "private_key": "-----BEGIN PRIVATE KEY-----\\nABC\\n-----END PRIVATE KEY-----\\n",
        "client_email": "firebase@recovera-c5646.iam.gserviceaccount.com",
    })
    monkeypatch.setenv("FIREBASE_CREDENTIALS_JSON", service_account)
    get_settings.cache_clear()

    def batch_handler(message, SendResponse, BatchResponse, UnregisteredError, InvalidArgumentError):
        if message.tokens:
            responses = []
            for tok in message.tokens:
                if tok == "fcm-stale":
                    responses.append(SendResponse(exception=UnregisteredError("Requested entity was not found.")))
                else:
                    responses.append(SendResponse(message_id=f"id-{tok}"))
            return BatchResponse(responses)
        return BatchResponse([SendResponse(message_id=f"fid-{fid}") for fid in (message.fids or [])])

    isolated_push_env["next_batch_handler"] = batch_handler

    db, engine = _make_db_session()
    try:
        user = _create_user(db, "seller159@recovera.id", role="seller")
        empty_row = DeviceToken(user_id=user.id, fcm_token="", fid="")
        valid_fcm = DeviceToken(user_id=user.id, fcm_token="fcm-valid")
        stale_fcm = DeviceToken(user_id=user.id, fcm_token="fcm-stale")
        valid_fid = DeviceToken(user_id=user.id, fid="fid-active-1")
        db.add_all([empty_row, valid_fcm, stale_fcm, valid_fid])
        db.commit()

        push_service.send_to_user(db, user.id, "Pesanan Baru", "Ada pesanan", {"type": "new_order", "order_id": 5})

        assert len(isolated_push_env["multicast_calls"]) == 2
        first_msg, _ = isolated_push_env["multicast_calls"][0]
        second_msg, _ = isolated_push_env["multicast_calls"][1]

        assert first_msg.tokens == ["fcm-valid", "fcm-stale"]
        assert first_msg.fids is None
        assert first_msg.android.notification.kwargs["channel_id"] == "recovera_notifications"
        assert second_msg.fids == ["fid-active-1"]
        assert second_msg.tokens is None

        remaining = db.query(DeviceToken).filter(DeviceToken.user_id == user.id).all()
        remaining_fcm = {d.fcm_token for d in remaining if d.fcm_token}
        remaining_fid = {d.fid for d in remaining if d.fid}
        assert remaining_fcm == {"fcm-valid"}
        assert remaining_fid == {"fid-active-1"}
    finally:
        db.close()
        engine.dispose()


def test_register_device_transfers_token_ownership_on_account_switch():
    db, engine = _make_db_session()
    try:
        user_a = _create_user(db, "user_a@recovera.id", role="buyer")
        user_b = _create_user(db, "user_b@recovera.id", role="seller")

        _run_sync(register_device_token(db=db, current_user=user_a, payload=DeviceTokenRequest(fcm_token="shared-fcm-1")))
        _run_sync(register_device_token(db=db, current_user=user_b, payload=DeviceTokenRequest(fcm_token="shared-fcm-1")))

        rows = db.query(DeviceToken).filter(DeviceToken.fcm_token == "shared-fcm-1").all()
        assert len(rows) == 1
        assert rows[0].user_id == user_b.id

        _run_sync(register_device_token(db=db, current_user=user_a, payload=DeviceTokenRequest(fid="shared-fid-1")))
        _run_sync(register_device_token(db=db, current_user=user_b, payload=DeviceTokenRequest(fid="shared-fid-1")))

        fid_rows = db.query(DeviceToken).filter(DeviceToken.fid == "shared-fid-1").all()
        assert len(fid_rows) == 1
        assert fid_rows[0].user_id == user_b.id
    finally:
        db.close()
        engine.dispose()


def test_logout_unbinds_device_token_when_provided_and_keeps_legacy_optional_payload():
    db, engine = _make_db_session()
    try:
        user = _create_user(db, "logout_user@recovera.id")
        db.add(DeviceToken(user_id=user.id, fcm_token="logout-fcm-1"))
        db.add(DeviceToken(user_id=user.id, fcm_token="other-device-fcm"))
        db.commit()

        res = _run_sync(
            logout_route(
                db=db,
                current_user=user,
                payload=LogoutRequest(fcm_token="logout-fcm-1"),
            )
        )
        assert res["success"] is True

        remaining = [d.fcm_token for d in db.query(DeviceToken).filter(DeviceToken.user_id == user.id).all()]
        assert remaining == ["other-device-fcm"]

        # Backwards compatible when payload is None
        res_empty = _run_sync(logout_route(db=db, current_user=user, payload=None))
        assert res_empty["success"] is True
    finally:
        db.close()
        engine.dispose()
