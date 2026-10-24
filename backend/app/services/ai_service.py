import base64
import json
import logging
import os
from datetime import date, datetime, timedelta, timezone
from typing import Optional

try:
    from groq import AsyncGroq
except ImportError:
    AsyncGroq = None

from app.config import get_settings
from app.models.listing import Listing, Offer
from app.models.notification import Notification
from app.models.user import Buyer
from app.schemas.ai import InvoiceOcrResponse, InvoiceParsedItem, PriceAdviceResponse
from app.services.listing_service import get_initial_discount_percentage
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)
settings = get_settings()


async def process_invoice_ocr(filename: str, content: bytes) -> InvoiceOcrResponse:
    today = date.today()
    invoice_no = f"INV-{datetime.now().strftime('%Y%m%d')}-{len(content) % 1000:03d}"
    groq_api_key = (os.getenv("GROQ_API_KEY") or getattr(settings, "groq_api_key", "")).strip()

    if groq_api_key and AsyncGroq is not None:
        try:
            ext = filename.lower().split(".")[-1] if "." in filename else "jpg"
            mime_type = "image/png" if ext == "png" else "application/pdf" if ext == "pdf" else "image/jpeg"
            b64_content = base64.b64encode(content).decode("utf-8")

            prompt = (
                f"Analisis gambar ini untuk sistem B2B Recovera. "
                f"Hari ini adalah {today.isoformat()}. "
                f"Sebelum mengekstrak data, periksa dulu apakah gambar ini memang berisi faktur pembelian produk, "
                f"daftar harga produk pangan, atau foto produk pangan. "
                f"Jika gambar BUKAN salah satu dari itu (misalnya: selfie, screenshot aplikasi non-faktur, foto hewan, "
                f"pemandangan, dokumen non-pangan, atau konten tidak relevan lainnya), kembalikan HANYA JSON berikut:\n"
                f'{{"rejected": true, "rejection_reason": "Gambar yang dikirim bukan faktur atau produk pangan"}}\n\n'
                f"Hanya jika gambar memang berisi faktur atau produk pangan, lanjutkan ekstraksi data produk utama "
                f"dan kembalikan objek JSON valid dengan struktur berikut:\n"
                f"{{\n"
                f'  "rejected": false,\n'
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

            # Cek jika AI menolak gambar
            if parsed_data.get("rejected") is True:
                reason = parsed_data.get("rejection_reason") or "Gambar yang dikirim bukan faktur atau produk pangan"
                return InvoiceOcrResponse(
                    invoice_number=None,
                    supplier_name=None,
                    parsed_items=[],
                    fallback_used=False,
                    rejected=True,
                    rejection_reason=reason,
                )

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
                    rejected=False,
                    rejection_reason=None,
                )
            else:
                return InvoiceOcrResponse(
                    invoice_number=None,
                    supplier_name=None,
                    parsed_items=[],
                    fallback_used=False,
                    rejected=True,
                    rejection_reason="Tidak ada produk pangan atau faktur yang dapat dikenali dari gambar ini",
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
        rejected=False,
        rejection_reason=None,
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
            min_price_guardrail=min_price if min_price > 0 else round(normal_price * 0.3, 2),
            rationale=rationale,
            next_drop_at=(datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
            source=advice.source,
            model_version=advice.model_version,
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
        min_price_guardrail=min_price if min_price > 0 else round(normal_price * 0.3, 2),
        rationale=rationale,
        next_drop_at=(datetime.now(timezone.utc) + timedelta(hours=1)).isoformat(),
        source="rule",
        model_version=None,
    )


def match_and_create_offers_for_listing(
    db: Session,
    listing: Listing,
    ai_engine=None,
    top_k: int = 5,
) -> list[Offer]:
    """
    Dipanggil saat listing diaktifkan / dipublish:
    1. Filter & ranking buyer potensial via AI Engine (LightGBM ranking / rule fallback).
    2. Simpan record penawaran ke tabel `offers`.
    3. Buat notifikasi in-app untuk buyer terpilih.
    """
    if ai_engine is None:
        return {"total_offers_sent": 0, "top_buyers": []}

    seller = listing.seller
    if not seller or seller.warehouse_lat is None or seller.warehouse_lng is None:
        return {"total_offers_sent": 0, "top_buyers": []}

    # 1. Ambil kandidat buyer dari database
    buyers = db.query(Buyer).all()
    if not buyers:
        return {"total_offers_sent": 0, "top_buyers": []}

    buyers_data = []
    buyer_user_map = {}
    for b in buyers:
        if b.base_lat is None or b.base_lng is None:
            continue
        buyers_data.append({
            "buyer_id": b.id,
            "base_lat": float(b.base_lat),
            "base_lng": float(b.base_lng),
            "max_radius_km": float(b.max_radius_km or 15),
            "has_cold_storage": bool(b.has_cold_storage),
            "pref_categories": b.pref_categories or [],
            "business_type": b.business_type or "resto",
            "total_orders_completed": int(b.total_orders_completed or 0),
            "payment_reliability_score": float(b.payment_reliability_score or 1.0),
        })
        buyer_user_map[b.id] = b.user_id

    if not buyers_data:
        return {"total_offers_sent": 0, "top_buyers": []}

    import pandas as pd
    buyers_df = pd.DataFrame(buyers_data)

    today = date.today()
    days_to_expiry = max(0, (listing.expiry_date - today).days)
    normal_p = float(listing.normal_price)
    start_p = float(listing.start_price)
    offered_discount_pct = round(((normal_p - start_p) / normal_p) * 100, 2) if normal_p > 0 else 0.0

    product = listing.product
    listing_dict = {
        "warehouse_lat": float(seller.warehouse_lat),
        "warehouse_lng": float(seller.warehouse_lng),
        "days_to_expiry": days_to_expiry,
        "offered_discount_pct": offered_discount_pct,
        "storage_type": product.storage_type if product else "ambient",
        "category": product.category if product else "Canned",
    }

    # 2. Match pembeli menggunakan ranking model (Top-k)
    matched = ai_engine.match_buyers(listing_dict, buyers_df, k=top_k)
    if not matched:
        return {"total_offers_sent": 0, "top_buyers": []}

    created_offers = []
    top_buyers_summary = []
    for m in matched:
        buyer_id = int(m["buyer_id"])
        sel_source = m.get("selection_source", "model")
        offer = Offer(
            listing_id=listing.id,
            buyer_id=buyer_id,
            match_score=float(m["match_score"]),
            distance_km=float(m["distance_km"]),
            days_to_expiry=days_to_expiry,
            offered_discount_pct=offered_discount_pct,
            status="sent",
            selection_source=sel_source,
        )
        db.add(offer)
        created_offers.append(offer)
        top_buyers_summary.append({
            "buyer_id": buyer_id,
            "match_score": round(float(m["match_score"]), 3),
            "distance_km": round(float(m["distance_km"]), 2),
            "selection_source": sel_source,
        })

        # 3. Notifikasi in-app untuk pembeli
        user_id = buyer_user_map.get(buyer_id)
        if user_id:
            prod_name = product.name if product else "Produk Terpilih"
            seller_company = seller.company_name if seller and seller.company_name else "Distributor Terverifikasi"
            notif = Notification(
                user_id=user_id,
                title="Penawaran Eksklusif Produk Baru!",
                body=(
                    f"Penawaran terbatas: {prod_name} dari {seller_company} diskon {offered_discount_pct:.0f}% "
                    f"hanya berjarak {m['distance_km']} km dari lokasimu. "
                    f"Lihat detail lelang listing #{listing.id} sekarang sebelum penawaran berakhir!"
                ),
                type="deal_match",
            )
            db.add(notif)

    db.commit()
    return {
        "total_offers_sent": len(created_offers),
        "top_buyers": top_buyers_summary,
    }
