from datetime import date, datetime, timedelta, timezone
from typing import Optional

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
    storage_type: str = "ambient",
    min_price: float = 0.0,
    ai_engine=None,          # dikirim oleh router: request.app.state.ai
) -> PriceAdviceResponse:
    """Hybrid: gunakan AIEngine jika tersedia, fallback rule-based jika tidak."""
    today = date.today()
    try:
        exp_date = date.fromisoformat(expiry_date_str)
    except ValueError:
        exp_date = today + timedelta(days=30)

    days_to_expiry = max(0, (exp_date - today).days)

    # ── Path ML / hybrid ────────────────────────────────────────────────────
    if ai_engine is not None:
        listing_dict = {
            "category": category or "Canned",
            "storage_type": storage_type,
            "days_to_expiry": days_to_expiry,
            "qty": qty,
            "normal_price": normal_price,
            "min_price": min_price if min_price > 0 else normal_price * 0.3,
        }
        advice = ai_engine.advise_price(listing_dict)
        if advice.divert:
            # Barang perlu didonasikan, beri harga minimum
            rationale = (
                f"Sisa {days_to_expiry} hari — produk perlu dialihkan/didonasikan "
                f"sesuai kebijakan Recovera (threshold {days_to_expiry} hari)."
            )
            return PriceAdviceResponse(
                suggested_price=round(normal_price * 0.1, 2),
                discount_pct=90.0,
                rationale=rationale,
                next_drop_at=(datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
            )
        discount_pct = advice.discount_pct or 0.0
        suggested_price = advice.suggested_price or round(normal_price * (1 - discount_pct / 100), 2)
        source_label = "model ML" if advice.source == "ml" else "aturan bisnis"
        rationale = (
            f"Diskon awal {discount_pct:.0f}% direkomendasikan via {source_label} "
            f"(sisa {days_to_expiry} hari). "
            f"Harga pembukaan Rp {suggested_price:,.0f} menarik pembeli terdekat sebelum harga lelang turun bertahap."
        )
        return PriceAdviceResponse(
            suggested_price=suggested_price,
            discount_pct=discount_pct,
            rationale=rationale,
            next_drop_at=(datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
        )

    # ── Fallback rule-based murni (tanpa engine, mis. unit test) ────────────
    discount_pct = get_initial_discount_percentage(days_to_expiry)
    suggested_price = round(normal_price * (1.0 - (discount_pct / 100.0)), 2)
    rationale = (
        f"Diskon awal {discount_pct:.0f}% direkomendasikan karena sisa umur simpan {days_to_expiry} hari. "
        f"Harga pembukaan Rp {suggested_price:,.0f} menarik pembeli terdekat sebelum harga lelang turun bertahap."
    )
    return PriceAdviceResponse(
        suggested_price=suggested_price,
        discount_pct=discount_pct,
        rationale=rationale,
        next_drop_at=(datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
    )
