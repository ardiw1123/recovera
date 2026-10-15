from typing import Literal
from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, description="Password with minimum 8 characters")
    role: Literal["seller", "buyer"]
    name: str = Field(min_length=1)
    phone: str | None = None

    # Seller specific fields
    company_name: str | None = None
    warehouse_lat: float | None = None
    warehouse_lng: float | None = None
    city: str | None = None

    # Buyer specific fields
    business_type: str | None = None
    base_lat: float | None = None
    base_lng: float | None = None
    pref_categories: list[str] = Field(default_factory=list)

    # General address
    address: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = 3600
    user_id: int
    role: str
    name: str
