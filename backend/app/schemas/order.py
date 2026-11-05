from typing import Literal
from pydantic import BaseModel, Field


class OrderProductDetail(BaseModel):
    product_name: str
    category: str
    batch_number: str
    image_url: str | None = None
    buyer_name: str | None = None
    buyer_business_type: str | None = None
    warehouse_lat: float | None = None
    warehouse_lng: float | None = None
    warehouse_address: str | None = None


class OrderResponse(BaseModel):
    id: int
    listing_id: int
    buyer_id: int
    buyer_name: str | None = None
    buyer_business_type: str | None = None
    seller_name: str | None = None
    image_url: str | None = None
    qty: int
    final_unit_price: float
    total_price: float
    status: str
    created_at: str
    product_detail: OrderProductDetail | None = None


class OrderStatusUpdate(BaseModel):
    status: Literal["in_progress", "completed"] = Field(description="Order status update transition")
