import base64
import json
import logging
import os
from datetime import date, datetime, timedelta, timezone
from groq import AsyncGroq
from app.config import get_settings
from app.schemas.ai import InvoiceOcrResponse, InvoiceParsedItem, PriceAdviceResponse
from app.services.listing_service import get_initial_discount_percentage

logger = logging.getLogger(__name__)
settings = get_settings()


async def process_invoice_ocr(filename: str, content: bytes) -> InvoiceOcrResponse:
    today = date.today()
    invoice_no = f"INV-{datetime.now().strftime('%Y%m%d')}-{len(content) % 1000:03d}"
    groq_api_key = (os.getenv("GROQ_API_KEY") or getattr(settings, "groq_api_key", "")).strip()

    if groq_api_key:
        try:
            ext = filename.lower().split(".")[-1] if "." in filename else "jpg"
            mime_type = "image/png" if ext == "png" else "application/pdf" if ext == "pdf" else "image/jpeg"
            b64_content = base64.b64encode(content).decode("utf-8")

            prompt = (
                f"Analisis gambar faktur atau produk pangan ini untuk sistem B2B Recovera. "
                f"Hari ini adalah {today.isoformat()}. "
                f"Ekstrak data produk utama dan kembalikan hanya objek JSON valid dengan struktur berikut:\n"
                f"{{\n"
                f'  "supplier_name": "Nama distributor atau supplier pangan",\n'
                f'  "invoice_number": "{invoice_no}",\n'
                f'  "items": [\n'
                f"    {{\n"
                f'      "product_name": "Nama lengkap produk pangan",\n'
                f'      "brand": "Merk atau produsen pangan",\n'
                f'      "category": "Pilih salah satu: Dairy, Frozen, Flour & Grain, Oil & Condiment, Beverage, Canned & Preserved, General",\n'
                f'      "quantity": 10,\n'
                f'      "unit": "Satuan: box, karton, kg, jerigen, karung, atau pcs",\n'
                f'      "expiry_date": "YYYY-MM-DD (minimal 45 hari dari hari ini)",\n'
                f'      "normal_price": 25000.0,\n'
                f'      "confidence": 0.95\n'
                f"    }}\n"
                f"  ]\n"
                f"}}\n"
                f"Pastikan field expiry_date valid format YYYY-MM-DD dan minimal 30 hari ke depan. "
                f"Keluarkan HANYA JSON murni tanpa markdown."
            )

            client = AsyncGroq(api_key=groq_api_key)
            completion = await client.chat.completions.create(
                model="qwen/qwen3.8-27b",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:{mime_type};base64,{b64_content}"
                                },
                            },
                        ],
                    }
                ],
                temperature=0.2,
                max_completion_tokens=2048,
                top_p=0.95,
                response_format={"type": "json_object"},
            )

            clean_text = (completion.choices[0].message.content or "").strip()
            if clean_text.startswith("```json"):
                clean_text = clean_text[7:]
            if clean_text.endswith("```"):
                clean_text = clean_text[:-3]
            parsed_data = json.loads(clean_text.strip())

            items_data = parsed_data.get("items", [])
            parsed_items = []
            for it in items_data:
                exp_val = it.get("expiry_date")
                try:
                    exp_d = date.fromisoformat(str(exp_val))
                    if (exp_d - today).days < 30:
                        exp_d = today + timedelta(days=45)
                    exp_str = exp_d.isoformat()
                except Exception:
                    exp_str = (today + timedelta(days=45)).isoformat()

                parsed_items.append(
                    InvoiceParsedItem(
                        product_name=str(it.get("product_name", "Produk Pangan")).strip(),
                        brand=it.get("brand"),
                        category=str(it.get("category", "General")).strip(),
                        quantity=max(1, int(it.get("quantity", 1))),
                        unit=str(it.get("unit", "box")).strip(),
                        expiry_date=exp_str,
                        normal_price=max(1000.0, float(it.get("normal_price", 15000.0))),
                        confidence=min(1.0, max(0.1, float(it.get("confidence", 0.9)))),
                    )
                )

            if parsed_items:
                return InvoiceOcrResponse(
                    invoice_number=parsed_data.get("invoice_number") or invoice_no,
                    supplier_name=parsed_data.get("supplier_name") or "Distributor Pangan Terdaftar",
                    parsed_items=parsed_items,
                    fallback_used=False,
                )
        except Exception as e:
            logger.warning(f"OCR Model call failed, falling back to deterministic response: {e}")

    # Fallback deterministik sesuai PRD US-03 jika offline atau kuota habis
    parsed_items = [
        InvoiceParsedItem(
            product_name="Susu UHT Full Cream 1L",
            brand="Ultra Milk",
            category="Dairy",
            quantity=50,
            unit="karton",
            expiry_date=(today + timedelta(days=45)).isoformat(),
            normal_price=210000.0,
            confidence=0.96,
        ),
        InvoiceParsedItem(
            product_name="Tepung Terigu Segitiga Biru 1kg",
            brand="Bogasari",
            category="Flour & Grain",
            quantity=100,
            unit="kg",
            expiry_date=(today + timedelta(days=60)).isoformat(),
            normal_price=13500.0,
            confidence=0.92,
        ),
    ]

    return InvoiceOcrResponse(
        invoice_number=invoice_no,
        supplier_name="PT Sumber Pangan Distribusi",
        parsed_items=parsed_items,
        fallback_used=True,
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
