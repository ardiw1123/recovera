from pydantic import BaseModel, EmailStr


class SellerProfile(BaseModel):
    id: int
    company_name: str
    address: str
    warehouse_lat: float
    warehouse_lng: float
    city: str


class BuyerProfile(BaseModel):
    id: int
    business_type: str
    address: str
    base_lat: float
    base_lng: float
    pref_categories: list[str]
    max_radius_km: int
    has_cold_storage: bool
    total_orders_completed: int
    payment_reliability_score: float


class ProfileResponse(BaseModel):
    id: int
    email: EmailStr
    role: str
    name: str
    phone: str | None = None
    photo_url: str | None = None
    seller: SellerProfile | None = None
    buyer: BuyerProfile | None = None


class ProfileUpdateRequest(BaseModel):
    name: str | None = None
    phone: str | None = None
    photo_url: str | None = None

    # Seller updates
    company_name: str | None = None
    address: str | None = None
    warehouse_lat: float | None = None
    warehouse_lng: float | None = None
    city: str | None = None

    # Buyer updates
    business_type: str | None = None
    base_lat: float | None = None
    base_lng: float | None = None
    pref_categories: list[str] | None = None
    max_radius_km: int | None = None
    has_cold_storage: bool | None = None
