from typing import Any
from pydantic import BaseModel, Field, model_validator


class NotificationResponse(BaseModel):
    id: int
    title: str
    body: str
    type: str
    is_read: bool
    created_at: str
    data: dict[str, Any] = Field(default_factory=dict)


class DeviceTokenRequest(BaseModel):
    fid: str | None = Field(default=None, min_length=1, description="Firebase Installation ID")
    fcm_token: str | None = Field(default=None, min_length=1, description="Legacy FCM registration token")

    @model_validator(mode="after")
    def require_single_device_identifier(self):
        if bool(self.fid) == bool(self.fcm_token):
            raise ValueError("Provide exactly one of fid or fcm_token")
        return self
