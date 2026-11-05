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
    parsed_items: list[InvoiceParsedItem] = Field(default_factory=list)
    fallback_used: bool = False
    rejected: bool = False
    rejection_reason: str | None = None


class PriceAdviceRequest(BaseModel):
    normal_price: float = Field(gt=0, description="Harga normal produk", examples=[50000.0])
    expiry_date: str = Field(description="Tanggal kedaluwarsa YYYY-MM-DD", examples=["2026-11-20"])
    category: str | None = Field(default="Dairy", description="Kategori: Dairy | Frozen | Oil | Flour & Grain | Canned | Beverage", examples=["Dairy"])
    qty: int = Field(default=1, gt=0, description="Kuantitas stok", examples=[50])
    storage_type: str = Field(default="chilled", description="Tipe penyimpanan: ambient | chilled | frozen", examples=["chilled"])
    min_price: float = Field(default=0.0, ge=0.0, description="Harga minimum batas bawah seller (0 = auto 30%)", examples=[25000.0])

    model_config = {
        "json_schema_extra": {
            "example": {
                "normal_price": 50000.0,
                "expiry_date": "2026-11-20",
                "category": "Dairy",
                "qty": 50,
                "storage_type": "chilled",
                "min_price": 25000.0
            }
        }
    }


class PriceAdviceResponse(BaseModel):
    suggested_price: float
    discount_pct: float
    min_price_guardrail: float | None = None
    next_drop_at: str
    rationale: str
    source: str = "rule"                  # "ml" | "rule"
    model_version: str | None = None      # versi model jika source="ml"


class ChatHistoryItem(BaseModel):
    role: str = Field(description="'user' atau 'assistant'")
    content: str = Field(description="Isi pesan")


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000, description="Pesan dari user")
    history: list[ChatHistoryItem] = Field(default_factory=list, description="Riwayat obrolan sesi saat ini")


class RichCardAction(BaseModel):
    label: str
    route: str
    params: dict = Field(default_factory=dict)


class RichCardData(BaseModel):
    type: str = Field(description="'product_simulation' | 'market_stat' | 'quick_tip'")
    data: dict = Field(default_factory=dict)
    action: RichCardAction | None = None


class ChatResponse(BaseModel):
    reply: str
    intent: str = Field(default="general_faq", description="'general_faq' | 'product_opportunity' | 'market_trends' | 'rejected'")
    rich_card: RichCardData | None = None
    suggested_followups: list[str] = Field(default_factory=list)

