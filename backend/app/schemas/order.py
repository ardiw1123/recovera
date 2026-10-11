from typing import Literal
from pydantic import BaseModel, Field


class OrderProductDetail(BaseModel):
    product_name: str
    category: str
    batch_number: str
    warehouse_lat: float | None = None
    warehouse_lng: float | None = None
    warehouse_address: str | None = None


class OrderResponse(BaseModel):
    id: int
    listing_id: int
    buyer_id: int
    qty: int
    final_unit_price: float
    total_price: float
    status: str
    created_at: str
    product_detail: OrderProductDetail | None = None


class OrderStatusUpdate(BaseModel):
    status: Literal["picked_up", "completed"] = Field(description="Order status update transition")
