from datetime import date

from pydantic import BaseModel, Field, HttpUrl
from app.schemas.product import ProductResponse


class MultiTimezoneSchedule(BaseModel):
    wib: str
    wita: str
    wit: str
    london: str


class ListingResponse(BaseModel):
    id: int
    product_id: int
    seller_id: int
    batch_number: str
    qty: int
    normal_price: float
    start_price: float
    min_price: float
    drop_interval_minutes: int
    drop_percentage: float
    expiry_date: str
    auction_start_at: str
    auction_end_at: str
    status: str
    created_at: str

    current_price: float
    next_drop_at: str | None = None
    auction_end_timezones: MultiTimezoneSchedule | None = None
    product: ProductResponse | None = None
    seller_company: str | None = None
    warehouse_lat: float | None = None
    warehouse_lng: float | None = None
    warehouse_city: str | None = None
    distance_km: float | None = None
    match_score: float | None = None
    discount_pct: float | None = None
    days_to_expiry: int | None = None
    matching_summary: object | None = None


class ListingDetailResponse(ListingResponse):
    pass


class ListingCreate(BaseModel):
    product_id: int
    batch_number: str
    qty: int = Field(gt=0)
    normal_price: float = Field(gt=0)
    start_price: float | None = None
    min_price: float = Field(gt=0)
    drop_interval_minutes: int = 60
    drop_percentage: float = 2.50
    expiry_date: str
    auction_start_at: str | None = None
    auction_end_at: str | None = None


class ListingUpdate(BaseModel):
    qty: int | None = Field(default=None, ge=0)
    min_price: float | None = Field(default=None, gt=0)
    status: str | None = None


class ListingBuyRequest(BaseModel):
    qty: int = Field(default=1, gt=0)
    biometric_verified: bool = True


class SellerInventoryDraftCreate(BaseModel):
    sku: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=150)
    category: str = Field(min_length=1, max_length=50)
    storage_type: str = Field(min_length=1, max_length=20)
    default_unit: str = Field(min_length=1, max_length=20)
    image_url: str = Field(min_length=1)
    brand: str | None = Field(default=None, max_length=100)
    barcode: str | None = Field(default=None, max_length=50)
    batch_number: str = Field(min_length=1, max_length=50)
    qty: int = Field(gt=0)
    normal_price: float = Field(gt=0)
    min_price: float = Field(gt=0)
    expiry_date: date


class SellerInventoryDraftUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    category: str | None = Field(default=None, min_length=1, max_length=50)
    storage_type: str | None = Field(default=None, min_length=1, max_length=20)
    default_unit: str | None = Field(default=None, min_length=1, max_length=20)
    image_url: str | None = None
    brand: str | None = Field(default=None, max_length=100)
    batch_number: str | None = Field(default=None, min_length=1, max_length=50)
    qty: int | None = Field(default=None, gt=0)
    normal_price: float | None = Field(default=None, gt=0)
    start_price: float | None = Field(default=None, gt=0)
    min_price: float | None = Field(default=None, gt=0)
    expiry_date: date | None = None


class SellerPublishRequest(BaseModel):
    acknowledge_price_warning: bool = False
