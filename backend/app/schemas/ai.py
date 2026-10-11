from pydantic import BaseModel, Field


class InvoiceParsedItem(BaseModel):
    product_name: str
    brand: str | None = None
    category: str
    quantity: int = Field(gt=0)
    unit: str
    expiry_date: str
    normal_price: float = Field(gt=0)
    confidence: float = Field(ge=0.0, le=1.0, default=0.95)


class InvoiceOcrResponse(BaseModel):
    invoice_number: str | None = None
    supplier_name: str | None = None
    parsed_items: list[InvoiceParsedItem]
    fallback_used: bool = False


class PriceAdviceRequest(BaseModel):
    normal_price: float = Field(gt=0)
    expiry_date: str
    category: str | None = None
    qty: int = Field(default=1, gt=0)


class PriceAdviceResponse(BaseModel):
    suggested_price: float
    discount_pct: float
    rationale: str
    next_drop_at: str
