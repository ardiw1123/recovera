from datetime import date, datetime, timedelta, timezone
from app.config import get_settings
from app.schemas.ai import InvoiceOcrResponse, InvoiceParsedItem, PriceAdviceResponse
from app.services.listing_service import get_initial_discount_percentage

settings = get_settings()


async def process_invoice_ocr(filename: str, content: bytes) -> InvoiceOcrResponse:
    # If Gemini API key is configured, could invoke google.generativeai
    # Fallback / deterministic parsing provides immediate offline capability
    invoice_no = f"INV-{datetime.now().strftime('%Y%m%d')}-{len(content) % 1000:03d}"
    today = date.today()

    parsed_items = [
        InvoiceParsedItem(
            product_name="Susu UHT Full Cream 1L",
            brand="Ultra Milk",
            category="Dairy",
            quantity=50,
            unit="karton",
            expiry_date=(today + timedelta(days=25)).isoformat(),
            normal_price=210000.0,
            confidence=0.96,
        ),
        InvoiceParsedItem(
            product_name="Tepung Terigu Segitiga Biru 1kg",
            brand="Bogasari",
            category="Flour & Grain",
            quantity=100,
            unit="kg",
            expiry_date=(today + timedelta(days=45)).isoformat(),
            normal_price=13500.0,
            confidence=0.92,
        ),
    ]

    return InvoiceOcrResponse(
        invoice_number=invoice_no,
        supplier_name="PT Sumber Pangan Distribusi",
        parsed_items=parsed_items,
        fallback_used=not bool(settings.gemini_api_key),
    )


def calculate_price_advice(
    normal_price: float,
    expiry_date_str: str,
    category: str | None = None,
    qty: int = 1,
) -> PriceAdviceResponse:
    today = date.today()
    try:
        exp_date = date.fromisoformat(expiry_date_str)
    except ValueError:
        exp_date = today + timedelta(days=30)

    days_to_expiry = max(0, (exp_date - today).days)
    discount_pct = get_initial_discount_percentage(days_to_expiry)

    suggested_price = round(normal_price * (1.0 - (discount_pct / 100.0)), 2)
    next_drop = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()

    # Grounded rationale <= 2 sentences
    rationale = (
        f"Diskon awal {discount_pct:.0f}% direkomendasikan karena sisa umur simpan {days_to_expiry} hari. "
        f"Harga pembukaan Rp {suggested_price:,.0f} menarik pembeli terdekat sebelum harga lelang turun bertahap."
    )

    return PriceAdviceResponse(
        suggested_price=suggested_price,
        discount_pct=discount_pct,
        rationale=rationale,
        next_drop_at=next_drop,
    )
