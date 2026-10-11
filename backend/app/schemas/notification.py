from pydantic import BaseModel, Field


class NotificationResponse(BaseModel):
    id: int
    title: str
    body: str
    type: str
    is_read: bool
    created_at: str


class DeviceTokenRequest(BaseModel):
    fcm_token: str = Field(min_length=1, description="FCM device token string")
