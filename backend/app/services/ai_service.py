import base64
import json
import logging
import os
from datetime import date, datetime, timedelta, timezone
from typing import Optional

try:
    from groq import AsyncGroq  # type: ignore
except ImportError:
    AsyncGroq = None

import httpx
import re
from sqlalchemy import func
from app.config import get_settings
from app.models.listing import Listing, Offer
from app.models.notification import Notification
from app.models.order import Order
from app.models.product import Product
from app.models.user import Buyer, Seller, User
from app.schemas.ai import (
    ChatHistoryItem,
    ChatRequest,
    ChatResponse,
    InvoiceOcrResponse,
    InvoiceParsedItem,
    PriceAdviceResponse,
    RichCardAction,
    RichCardData,
)
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
            logger.warning(f"OCR Model call failed: {e}")

    # Cek Gemini Vision API jika Groq tidak tersedia
    gemini_api_key = (os.getenv("GEMINI_API_KEY") or getattr(settings, "gemini_api_key", "")).strip()
    if gemini_api_key:
        try:
            ext = filename.lower().split(".")[-1] if "." in filename else "jpg"
            mime_type = "image/png" if ext == "png" else "application/pdf" if ext == "pdf" else "image/jpeg"
            b64_content = base64.b64encode(content).decode("utf-8")

            prompt = (
                f"Analisis gambar ini untuk sistem B2B Recovera. "
                f"Hari ini adalah {today.isoformat()}. "
                f"Periksa secara teliti apakah gambar ini memang berisi faktur, struk, nota, surat jalan pembelian produk pangan, daftar harga produk pangan, atau foto produk pangan. "
                f"Jika gambar BUKAN salah satu dari itu (misalnya: selfie, foto orang, hewan, pemandangan, meme, screenshot acak non-faktur, dokumen non-pangan, atau gambar tidak relevan lainnya), kembalikan HANYA JSON berikut:\n"
                f'{{"rejected": true, "rejection_reason": "Gambar yang diunggah terdeteksi bukan faktur atau produk pangan."}}\n\n'
                f"Jika gambar memang berisi faktur atau produk pangan, lanjutkan ekstraksi data produk utama dan kembalikan objek JSON valid:\n"
                f"{{\n"
                f'  "rejected": false,\n'
                f'  "supplier_name": "Nama distributor atau supplier pangan",\n'
                f'  "invoice_number": "{invoice_no}",\n'
                f'  "items": [\n'
                f"    {{\n"
                f'      "product_name": "Nama lengkap produk pangan",\n'
                f'      "brand": "Merk atau produsen pangan",\n'
                f'      "category": "Pilih: Dairy, Frozen, Flour & Grain, Oil & Condiment, Beverage, Canned & Preserved, General",\n'
                f'      "quantity": 10,\n'
                f'      "unit": "box, karton, kg, jerigen, karung, atau pcs",\n'
                f'      "expiry_date": "YYYY-MM-DD",\n'
                f'      "normal_price": 25000.0,\n'
                f'      "confidence": 0.95\n'
                f"    }}\n"
                f"  ]\n"
                f"}}\n"
                f"Keluarkan HANYA JSON murni tanpa markdown."
            )

            gemini_payload = {
                "contents": [
                    {
                        "role": "user",
                        "parts": [
                            {"text": prompt},
                            {
                                "inlineData": {
                                    "mimeType": mime_type,
                                    "data": b64_content,
                                }
                            }
                        ]
                    }
                ],
                "generationConfig": {
                    "temperature": 0.2,
                    "maxOutputTokens": 2048,
                    "responseMimeType": "application/json",
                }
            }

            models = ["gemini-2.5-flash", "gemini-1.5-flash"]
            async with httpx.AsyncClient(timeout=15.0) as http_client:
                for model in models:
                    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={gemini_api_key}"
                    res = await http_client.post(url, json=gemini_payload, headers={"Content-Type": "application/json"})
                    if res.status_code == 200:
                        data = res.json()
                        candidates = data.get("candidates", [])
                        if candidates and "content" in candidates[0]:
                            parts = candidates[0]["content"].get("parts", [])
                            if parts and "text" in parts[0]:
                                clean_text = parts[0]["text"].strip()
                                parsed_data = json.loads(clean_text)
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
            logger.warning(f"Gemini OCR model call failed: {e}")

    # Fallback deterministik sesuai PRD US-03 jika offline atau kuota habis
    # Periksa apakah nama file mengindikasikan bukan faktur (misal cat.jpg, selfie, foto hewan/orang)
    lower_fn = filename.lower()
    is_non_invoice = any(kw in lower_fn for kw in [
        "cat", "kucing", "selfie", "dog", "anjing", "avatar", "profile", "hewan", "pemandangan", "meme"
    ])
    if is_non_invoice:
        return InvoiceOcrResponse(
            invoice_number=None,
            supplier_name=None,
            parsed_items=[],
            fallback_used=True,
            rejected=True,
            rejection_reason="Gambar yang dikirim bukan faktur atau produk pangan",
        )
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
                type="new_listing",
                data={"listing_id": listing.id},
            )
            db.add(notif)

    db.commit()
    return {
        "total_offers_sent": len(created_offers),
        "top_buyers": top_buyers_summary,
    }


# =====================================================================
# CHATBOT ASSISTANT WITH GOOGLE GEMINI & MATCHING MODEL INTEGRATION
# =====================================================================

INJECTION_PATTERNS = [
    r"(?i)(ignore|forget)\s+(all\s+)?(previous|past|above)\s+instructions",
    r"(?i)(act\s+as\s+a?|behave\s+like|you\s+are\s+now)\s+(dan|jailbreak|unrestricted|developer\s+mode)",
    r"(?i)(reveal|show|tell|print|bocorkan)\s+(your|the)?\s*(system\s*prompt|secret|api_?key|token|source\s+code)",
    r"(?i)(bypass|disable)\s+(safety|guardrail|filter|restriction|aturan)",
    r"(?i)(drop\s+table|delete\s+from|insert\s+into|select\s+.*\s+from\s+users)",
]

RECOVERA_SYSTEM_KNOWLEDGE = """
Kamu adalah "Rera", asisten cerdas resmi untuk platform B2B Pangan Surplus "Recovera".
Gaya bicaramu ramah, luwes, solutif, profesional, dan menyenangkan layaknya konsultan bisnis pangan.

ATURAN FORMAT PENTING:
- JANGAN PERNAH MENGGUNAKAN SIMBOL ASTERISK ATAU BINTANG (seperti **teks** atau *teks*) dalam jawabanmu.
- Untuk penekanan atau penomoran, gunakan angka (1, 2, 3) atau poin biasa (•, -).
- Jawablah dengan bahasa Indonesia yang mengalir alami dan tidak kaku.

Prinsip dan Konteks Utama Recovera:
1. Lelang Dinamis (Dutch Auction):
   - Harga dibuka dengan diskon awal yang kompetitif (start_price), lalu turun bertahap secara berkala (misal tiap 60 menit sebesar 2.5%).
   - Pembeli pertama yang mengambil harga saat itu langsung memenangkan lot produk tanpa perlu perang harga.
   - Harga tidak akan pernah turun di bawah harga minimum (min_price guardrail) penjual.
2. Pengalihan Donasi Otomatis (Diversion Rule):
   - Sisa umur simpan kurang dari 15 hari dialihkan ke donasi sosial/bank pangan demi mencegah food waste.
3. Rantai Dingin (Cold Chain):
   - Produk kategori Frozen atau Chilled hanya dicocokkan dengan pembeli yang memiliki fasilitas pendingin terverifikasi (has_cold_storage = True).
4. Sertifikasi ESG & Jejak Karbon:
   - Setiap pangan surplus yang diselamatkan dicatat jejak karbonnya di blockchain dan dapat diunduh sebagai Sertifikat ESG resmi.
5. Pengetahuan Database Produk:
   - Gunakan data katalog produk lelang aktif yang disertakan di bawah untuk menjawab pertanyaan tentang produk termurah, terdekat, atau ketersediaan stok secara akurat.
"""


def _check_prompt_injection(message: str) -> bool:
    """Mendeteksi indikasi prompt injection, jailbreak, atau kebocoran data."""
    for pattern in INJECTION_PATTERNS:
        if re.search(pattern, message):
            return True
    return False


async def _call_gemini_api(system_instruction: str, user_prompt: str, history: list[ChatHistoryItem] | None = None) -> str | None:
    """Memanggil Google Gemini API via HTTP async (gemini-2.5-flash / gemini-1.5-flash)."""
    api_key = (os.getenv("GEMINI_API_KEY") or getattr(settings, "gemini_api_key", "")).strip()
    if not api_key:
        return None

    # Format percakapan untuk Gemini generateContent API
    contents = []
    if history:
        for h in history[-4:]:  # Ambil maksimal 4 interaksi terakhir agar efisien
            gemini_role = "user" if h.role == "user" else "model"
            contents.append({
                "role": gemini_role,
                "parts": [{"text": h.content.replace("**", "").replace("*", "")}]
            })

    contents.append({
        "role": "user",
        "parts": [{"text": user_prompt}]
    })

    payload = {
        "contents": contents,
        "systemInstruction": {
            "parts": [{"text": system_instruction}]
        },
        "generationConfig": {
            "temperature": 0.4,
            "maxOutputTokens": 1000,
            "topP": 0.9,
        }
    }

    models = ["gemini-2.5-flash", "gemini-1.5-flash"]
    async with httpx.AsyncClient(timeout=10.0) as client:
        for model in models:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
            try:
                res = await client.post(url, json=payload, headers={"Content-Type": "application/json"})
                if res.status_code == 200:
                    data = res.json()
                    candidates = data.get("candidates", [])
                    if candidates and "content" in candidates[0]:
                        parts = candidates[0]["content"].get("parts", [])
                        if parts and "text" in parts[0]:
                            raw_text = parts[0]["text"].strip()
                            return raw_text.replace("**", "").replace("*", "")
            except Exception as e:
                logger.warning(f"Gagal memanggil Gemini model {model}: {e}")
                continue

    return None


def _extract_product_simulation_params(query: str) -> dict:
    """Ekstraksi parameter simulasi produk secara heuristik dari bahasa alami."""
    q = query.lower()
    
    # 1. Kategori & Storage
    cat = "General"
    storage = "ambient"
    if any(w in q for w in ["susu", "dairy", "keju", "yogurt", "mentega"]):
        cat = "Dairy"
        storage = "chilled"
    elif any(w in q for w in ["frozen", "beku", "daging", "ikan", "ayam", "sosis", "nugget"]):
        cat = "Frozen"
        storage = "frozen"
    elif any(w in q for w in ["minyak", "oil", "kecap", "saus", "bumbu"]):
        cat = "Oil & Condiment"
        storage = "ambient"
    elif any(w in q for w in ["tepung", "beras", "flour", "grain", "gandum"]):
        cat = "Flour & Grain"
        storage = "ambient"
    elif any(w in q for w in ["kaleng", "canned", "sarden", "kornet"]):
        cat = "Canned & Preserved"
        storage = "ambient"
    elif any(w in q for w in ["minuman", "beverage", "jus", "kopi", "teh"]):
        cat = "Beverage"
        storage = "ambient"

    # 2. Hari menuju expired
    days = 45
    days_match = re.search(r"(\d+)\s*(?:hari|hr|days?)", q)
    if days_match:
        days = max(1, int(days_match.group(1)))
    elif "1 bulan" in q:
        days = 30
    elif "2 bulan" in q:
        days = 60
    elif "3 bulan" in q:
        days = 90

    # 3. Kuantitas
    qty = 20
    qty_match = re.search(r"(\d+)\s*(?:karton|box|dus|kg|pcs|pack|sak|jerigen|unit)?", q)
    if qty_match:
        qty = max(1, int(qty_match.group(1)))

    # 4. Harga normal
    normal_price = 50000.0
    price_match = re.search(r"(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d+)\s*(?:rb|ribu)?", q)
    if price_match:
        raw_val = price_match.group(1).replace(".", "")
        try:
            val = float(raw_val)
            if "rb" in q or "ribu" in q:
                if val < 1000:
                    val *= 1000
            if val >= 1000:
                normal_price = val
        except ValueError:
            pass

    return {
        "category": cat,
        "storage_type": storage,
        "days_to_expiry": days,
        "qty": qty,
        "normal_price": normal_price,
    }


def _calc_haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    import math
    p = 0.017453292519943295
    a = 0.5 - math.cos((lat2 - lat1) * p) / 2 + math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2
    return 12742 * math.asin(math.sqrt(a))


async def process_chat_message(
    db: Session,
    user: User,
    payload: ChatRequest,
    ai_engine=None,
) -> ChatResponse:
    """
    Memproses obrolan masuk:
    1. Pre-flight prompt injection & jailbreak check
    2. Deteksi intent katalog database: Produk termurah, terdekat, pencarian stok
    3. Deteksi intent simulasi produk & tren pasar
    4. Sintesis jawaban via Google Gemini tanpa tanda asteriks
    """
    raw_message = payload.message.strip()

    # ── 1. Pre-flight Guardrail ──────────────────────────────────────────────
    if _check_prompt_injection(raw_message):
        return ChatResponse(
            reply=(
                "Maaf, saya adalah Asisten Resmi Recovera. Saya hanya dapat menjawab "
                "pertanyaan seputar operasional platform Recovera, potensi produk pangan surplus, "
                "mekanisme lelang dinamis, serta panduan sertifikasi dampak lingkungan."
            ),
            intent="rejected",
            rich_card=None,
            suggested_followups=[
                "Produk lelang apa yang paling murah saat ini?",
                "Produk apa yang paling dekat dari jangkauan saya?",
                "Bagaimana cara kerja lelang dinamis?",
            ],
        )

    lower_msg = raw_message.lower()

    # Lokasi pengguna saat ini
    u_lat = -6.2088
    u_lng = 106.8456
    u_city = "Jakarta"
    if user.role == "buyer" and user.buyer:
        u_lat = float(user.buyer.base_lat) if user.buyer.base_lat is not None else -6.2088
        u_lng = float(user.buyer.base_lng) if user.buyer.base_lng is not None else 106.8456
        u_city = user.buyer.address or "Jakarta"
    elif user.role == "seller" and user.seller:
        u_lat = float(user.seller.warehouse_lat) if user.seller.warehouse_lat is not None else -6.2088
        u_lng = float(user.seller.warehouse_lng) if user.seller.warehouse_lng is not None else 106.8456
        u_city = user.seller.city or "Jakarta"

    # Ambil katalog produk lelang aktif dari database riil
    active_listings = (
        db.query(Listing)
        .join(Product, Listing.product_id == Product.id)
        .filter(Listing.status == "active")
        .all()
    )

    # ── 2. Intent: Pertanyaan Katalog Database (Termurah / Terdekat / Stok) ──
    is_cheapest = any(w in lower_msg for w in ["termurah", "paling murah", "harga terendah", "murah"])
    is_nearest = any(w in lower_msg for w in ["terdekat", "paling dekat", "radius", "jangkauan", "lokasi", "sekitar"])
    is_product_search = any(w in lower_msg for w in ["susu", "keju", "minyak", "daging", "tepung", "frozen", "dairy", "produk apa", "katalog", "stok"])

    if (is_cheapest or is_nearest or is_product_search) and active_listings:
        # Susun ringkasan katalog aktual dari database untuk Gemini
        catalog_items = []
        for l in active_listings:
            p = l.product
            s = l.seller
            s_lat = float(s.warehouse_lat) if (s and s.warehouse_lat) else -6.2088
            s_lng = float(s.warehouse_lng) if (s and s.warehouse_lng) else 106.8456
            dist = _calc_haversine(u_lat, u_lng, s_lat, s_lng)
            diskon = round(((float(l.normal_price) - float(l.start_price)) / float(l.normal_price)) * 100) if float(l.normal_price) > 0 else 0
            catalog_items.append({
                "nama": p.name if p else "Produk Pangan",
                "brand": p.brand if p else "-",
                "kategori": p.category if p else "General",
                "penyimpanan": p.storage_type if p else "ambient",
                "harga_lelang": float(l.start_price),
                "harga_normal": float(l.normal_price),
                "diskon_persen": diskon,
                "stok": l.qty,
                "penjual": s.company_name if s else "Distributor",
                "kota": s.city if s else "Jakarta",
                "jarak_km": round(dist, 1),
            })

        if is_cheapest:
            catalog_items.sort(key=lambda x: x["harga_lelang"])
        elif is_nearest:
            catalog_items.sort(key=lambda x: x["jarak_km"])

        top_catalog_summary = "\n".join([
            f"- {c['nama']} ({c['brand']}) | Harga lelang: Rp {c['harga_lelang']:,.0f} (Diskon {c['diskon_persen']}%) | Stok: {c['stok']} | Penjual: {c['penjual']} ({c['kota']}) | Jarak: ~{c['jarak_km']} km | Penyimpanan: {c['penyimpanan']}"
            for c in catalog_items[:5]
        ])

        db_context = (
            f"Data Katalog Real-Time Database Recovera untuk Lokasi Pengguna ({u_city}):\n"
            f"{top_catalog_summary}\n\n"
            f"Instruksi: Jawab pertanyaan pengguna dengan merekomendasikan produk riil dari data di atas secara ramah, detail, dan luwes. "
            f"PENTING: Jangan gunakan tanda bintang / asteriks (** atau *) sama sekali."
        )

        gemini_reply = await _call_gemini_api(
            system_instruction=RECOVERA_SYSTEM_KNOWLEDGE,
            user_prompt=f"<user_query>{raw_message}</user_query>\n\n{db_context}",
            history=payload.history,
        )

        if not gemini_reply:
            if is_cheapest:
                top = catalog_items[:3]
                sb = ["Tentu! Berikut 3 produk lelang dengan harga pembuka termurah yang sedang aktif di Recovera:\n"]
                for i, c in enumerate(top, 1):
                    sb.append(f"{i}. {c['nama']} ({c['brand']})")
                    sb.append(f"   Penjual: {c['penjual']} - {c['kota']}")
                    sb.append(f"   Harga lelang: Rp {c['harga_lelang']:,.0f} (Diskon {c['diskon_persen']}% dari Rp {c['harga_normal']:,.0f})")
                    sb.append(f"   Sisa stok: {c['stok']} unit\n")
                sb.append("Anda dapat langsung melihat dan membeli produk ini di halaman Beranda lelang.")
                gemini_reply = "\n".join(sb)
            elif is_nearest:
                top = catalog_items[:3]
                sb = [f"Berdasarkan jangkauan lokasi Anda ({u_city}), ini dia 3 produk lelang yang jaraknya paling dekat:\n"]
                for i, c in enumerate(top, 1):
                    sb.append(f"{i}. {c['nama']}")
                    sb.append(f"   Jarak: sekitar {c['jarak_km']} km dari lokasimu (Gudang: {c['kota']})")
                    sb.append(f"   Harga lelang: Rp {c['harga_lelang']:,.0f} (Diskon {c['diskon_persen']}%)")
                    sb.append(f"   Penyimpanan: {c['penyimpanan']}\n")
                sb.append("Karena lokasinya dekat, pengiriman jadi jauh lebih cepat dan hemat ongkir.")
                gemini_reply = "\n".join(sb)

        gemini_reply = (gemini_reply or "").replace("**", "").replace("*", "")
        return ChatResponse(
            reply=gemini_reply,
            intent="product_catalog",
            rich_card=None,
            suggested_followups=[
                "Produk lelang apa yang paling murah saat ini?",
                "Produk apa yang paling dekat dari jangkauan saya?",
                "Bagaimana cara memastikan kualitas rantai dingin?",
            ],
        )

    # ── 3. Intent: Simulasi Peluang Produk & Harga (Seller/Pre-listing) ───────
    is_simulation = any(w in lower_msg for w in [
        "jual", "tertarik", "peminat", "peluang", "cocok", "harga segini",
        "ada yang mau", "kira-kira", "diskon berapa", "berapa pembeli"
    ])

    if is_simulation and user.role == "seller":
        params = _extract_product_simulation_params(raw_message)
        normal_price = params["normal_price"]
        days = params["days_to_expiry"]
        category = params["category"]
        storage_type = params["storage_type"]
        qty = params["qty"]

        # Jalankan advice price
        suggested_price = round(normal_price * 0.7, 0)
        discount_pct = 30.0
        if ai_engine is not None:
            advice = ai_engine.advise_price({
                "category": category,
                "storage_type": storage_type,
                "days_to_expiry": days,
                "qty": qty,
                "normal_price": normal_price,
                "min_price": normal_price * 0.3,
            })
            if advice.suggested_price:
                suggested_price = advice.suggested_price
            if advice.discount_pct:
                discount_pct = advice.discount_pct

        matched_count = 0
        avg_dist = 6.5
        all_buyers = db.query(Buyer).all()
        if all_buyers and ai_engine is not None:
            import pandas as pd
            b_list = []
            for b in all_buyers:
                if b.base_lat is not None and b.base_lng is not None:
                    b_list.append({
                        "buyer_id": b.id,
                        "base_lat": float(b.base_lat),
                        "base_lng": float(b.base_lng),
                        "max_radius_km": float(b.max_radius_km or 15),
                        "has_cold_storage": bool(b.has_cold_storage),
                        "pref_categories": b.pref_categories or [],
                        "total_orders_completed": int(b.total_orders_completed or 0),
                        "payment_reliability_score": float(b.payment_reliability_score or 1.0),
                    })
            if b_list:
                df = pd.DataFrame(b_list)
                listing_spec = {
                    "warehouse_lat": u_lat,
                    "warehouse_lng": u_lng,
                    "days_to_expiry": days,
                    "offered_discount_pct": discount_pct,
                    "storage_type": storage_type,
                    "category": category,
                }
                matched = ai_engine.match_buyers(listing_spec, df, k=10)
                matched_count = len(matched)
                if matched:
                    avg_dist = round(sum(m["distance_km"] for m in matched) / len(matched), 1)
        else:
            matched_count = min(len(all_buyers), 5) if all_buyers else 4

        # Buat Rich Action Card
        rich_card = RichCardData(
            type="product_simulation",
            data={
                "category": category,
                "qty": qty,
                "normal_price": normal_price,
                "suggested_start_price": suggested_price,
                "suggested_discount_pct": discount_pct,
                "matched_buyers_count": matched_count,
                "average_distance_km": avg_dist,
                "disclaimer": "Hasil ini merupakan estimasi potensi kecocokan kebutuhan pembeli terdekat, bukan kepastian transaksi.",
            },
            action=RichCardAction(
                label="Terapkan ke Listing Baru",
                route="/seller/tambah-stok",
                params={
                    "category": category,
                    "normal_price": normal_price,
                    "start_price": suggested_price,
                    "qty": qty,
                },
            ),
        )

        prompt_context = (
            f"Pengguna adalah Penjual yang menanyakan potensi produk {category} kuantitas {qty} "
            f"dengan harga normal Rp {normal_price:,.0f} dan sisa waktu kedaluwarsa {days} hari. "
            f"Model Recovera memproyeksikan diskon awal yang ideal adalah {discount_pct:.0f}% "
            f"(harga lelang pembuka Rp {suggested_price:,.0f}) dan mendeteksi ada {matched_count} calon pembeli "
            f"dalam radius rata-rata {avg_dist} km yang sesuai kriteria cold chain & kategori. "
            f"Jelaskan hasil ini dengan jelas, ramah, dan beri catatan bahwa ini adalah proyeksi kecocokan. "
            f"PENTING: Jangan gunakan tanda bintang / asteriks (** atau *)."
        )

        gemini_reply = await _call_gemini_api(
            system_instruction=RECOVERA_SYSTEM_KNOWLEDGE,
            user_prompt=f"<user_query>{raw_message}</user_query>\n\nKonteks Data:\n{prompt_context}",
            history=payload.history,
        )

        if not gemini_reply:
            gemini_reply = (
                f"Berdasarkan analisis model Recovera untuk produk kategori {category} (sisa kedaluwarsa {days} hari):\n\n"
                f"1. Potensi Pembeli: Ditemukan sekitar {matched_count} calon pembeli di sekitar lokasi Anda (radius rata-rata {avg_dist} km) yang memiliki kebutuhan dan fasilitas penyimpanan sesuai.\n"
                f"2. Rekomendasi Diskon Awal: Disarankan diskon awal {discount_pct:.0f}% dengan harga lelang pembuka Rp {suggested_price:,.0f} agar cepat menarik perhatian pembeli pada jam-jam pertama.\n\n"
                f"Catatan: Hasil di atas merupakan proyeksi kecocokan kebutuhan, bukan kepastian terjadinya transaksi."
            )

        gemini_reply = (gemini_reply or "").replace("**", "").replace("*", "")
        return ChatResponse(
            reply=gemini_reply,
            intent="product_opportunity",
            rich_card=rich_card,
            suggested_followups=[
                "Berapa harga batas bawah (min_price) yang aman?",
                "Bagaimana interval penurunan harga lelang?",
                "Apakah pembeli di sekitar memiliki fasilitas cold storage?",
            ],
        )

    # ── 4. Intent: Tren Pasar & Data Penjualan ────────────────────────────────
    is_market_inquiry = any(w in lower_msg for w in [
        "tren", "terlaris", "paling dicari", "permintaan", "daerah", "pasar", "sebaran"
    ])

    if is_market_inquiry:
        top_cats = (
            db.query(Product.category, func.count(Order.id).label("total_orders"))
            .join(Listing, Listing.product_id == Product.id)
            .join(Order, Order.listing_id == Listing.id)
            .group_by(Product.category)
            .order_by(func.count(Order.id).desc())
            .limit(3)
            .all()
        )
        cat_summary = ", ".join([f"{c[0]} ({c[1]} pesanan)" for c in top_cats]) if top_cats else "Dairy, Frozen, dan Flour & Grain"

        market_context = (
            f"Konteks Data Riil Recovera:\n"
            f"- Kategori dengan perputaran transaksi tertinggi saat ini: {cat_summary}.\n"
            f"- Wilayah transaksi dan konsentrasi pembeli aktif utama berpusat pada radius 10-15 km dari sentra kuliner & horeca kota.\n"
            f"- Rata-rata transaksi lelang selesai dalam 2-4 putaran penurunan harga.\n"
            f"PENTING: Jangan gunakan tanda bintang / asteriks (** atau *)."
        )

        gemini_reply = await _call_gemini_api(
            system_instruction=RECOVERA_SYSTEM_KNOWLEDGE,
            user_prompt=f"<user_query>{raw_message}</user_query>\n\n{market_context}",
            history=payload.history,
        )

        if not gemini_reply:
            gemini_reply = (
                f"Berikut adalah ringkasan tren pasar di platform Recovera:\n\n"
                f"1. Kategori Paling Diminati: {cat_summary} memiliki tingkat penyerapan tercepat oleh pembeli bisnis (resto & katering).\n"
                f"2. Sebaran Permintaan: Permintaan tertinggi terkonsentrasi di radius 5–15 km dari area komersial kuliner.\n"
                f"3. Pola Pembelian: Pembeli cenderung melakukan transaksi saat diskon mencapai 25%–40% sebelum barang masuk ke hari kritis."
            )

        gemini_reply = (gemini_reply or "").replace("**", "").replace("*", "")
        return ChatResponse(
            reply=gemini_reply,
            intent="market_trends",
            rich_card=None,
            suggested_followups=[
                "Bagaimana cara memaksimalkan harga lelang?",
                "Kapan waktu terbaik untuk mengunggah produk?",
            ],
        )

    # ── 5. Intent: Pertanyaan Umum Seputar Aplikasi (FAQ) ────────────────────
    gemini_reply = await _call_gemini_api(
        system_instruction=RECOVERA_SYSTEM_KNOWLEDGE,
        user_prompt=f"<user_query>{raw_message}</user_query>",
        history=payload.history,
    )

    if not gemini_reply:
        if "lelang" in lower_msg or "dutch" in lower_msg:
            gemini_reply = (
                "Lelang di Recovera menggunakan sistem Dutch Auction (Lelang Turun):\n\n"
                "1. Harga Pembuka: Produk dibuka dengan diskon awal tertentu yang ditentukan penjual.\n"
                "2. Penurunan Berkala: Harga turun otomatis tiap interval (misal 2.5% per jam) seiring berjalannya waktu.\n"
                "3. Siapa Cepat Dia Dapat: Pembeli pertama yang mengonfirmasi harga saat itu langsung memenangkan lot produk tanpa perlu saling menawar.\n"
                "4. Batas Aman: Harga tidak akan pernah turun melewati harga batas bawah (min_price) yang ditentukan penjual."
            )
        elif "rantai dingin" in lower_msg or "cold chain" in lower_msg or "pendingin" in lower_msg:
            gemini_reply = (
                "Untuk menjaga kesegaran produk pangan dingin (Chilled) dan beku (Frozen), Recovera menerapkan standar verifikasi rantai dingin:\n\n"
                "1. Verifikasi Fasilitas: Pembeli dan penjual wajib memiliki sertifikasi unit pendingin yang valid di profil mereka.\n"
                "2. Pencocokan Otomatis: Sistem hanya mencocokkan produk dingin dengan pembeli yang memiliki fasilitas cold storage.\n"
                "3. Kontrol Suhu: Saat serah terima barang, suhu dicek agar tetap stabil (0-4 derajat Celcius untuk chilled, -18 derajat Celcius untuk frozen)."
            )
        elif "donasi" in lower_msg or "expired" in lower_msg or "kedaluwarsa" in lower_msg:
            gemini_reply = (
                "Untuk mencegah food waste, Recovera memiliki fitur Donasi Otomatis (SOS Diversion).\n\n"
                "Jika produk surplus pangan memiliki sisa umur simpan kurang dari 15 hari dan belum terjual di lelang, sistem otomatis membuka jalur pengalihan donasi ke mitra bank pangan sosial terdaftar agar makanan tetap tersalurkan kepada yang membutuhkan."
            )
        elif "esg" in lower_msg or "karbon" in lower_msg or "sertifikat" in lower_msg:
            gemini_reply = (
                "Setiap kilogram pangan surplus yang berhasil diselamatkan dari tempat pembuangan akhir dihitung pengurangan emisi karbonnya (kg CO2e).\n\n"
                "Data transaksi ini diverifikasi di jaringan blockchain dan dapat diunduh langsung sebagai Sertifikat Dampak ESG resmi untuk laporan keberlanjutan bisnis Anda."
            )
        else:
            gemini_reply = (
                "Halo! Saya Asisten Recovera. Saya terhubung langsung dengan katalog dan database lelang kami.\n\n"
                "Anda bisa tanyakan hal seperti:\n"
                "• Produk apa saja yang harganya paling murah saat ini?\n"
                "• Produk apa yang lokasinya paling dekat dengan saya?\n"
                "• Ketersediaan produk tertentu (misal: susu, minyak, keju)\n"
                "• Simulasi peluang produk lelang baru (khusus penjual)\n"
                "• Cara kerja lelang dinamis, rantai dingin, dan sertifikat ESG\n\n"
                "Ada yang ingin Anda cari atau tanyakan?"
            )

    gemini_reply = (gemini_reply or "").replace("**", "").replace("*", "")
    return ChatResponse(
        reply=gemini_reply,
        intent="general_faq",
        rich_card=None,
        suggested_followups=[
            "Produk lelang apa yang paling murah saat ini?",
            "Produk apa yang paling dekat dari jangkauan saya?",
            "Bagaimana cara kerja lelang dinamis?",
        ],
    )


