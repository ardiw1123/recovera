import io
from datetime import date, datetime, timedelta, timezone
import pytest
from app.models.listing import Listing, Offer
from app.models.notification import Notification
from app.models.donation import Donation, Offtaker
from app.services.donation_service import divert_listing_to_donation, check_and_divert_expired_listings


def test_acceptance_criteria_ai_models_loaded_on_startup(client):
    """
    AC 1: Model AI untuk harga dan model AI untuk peringkat pembeli
    siap digunakan saat backend menyala.
    """
    from app.main import app
    ai_engine = getattr(app.state, "ai", None)
    assert ai_engine is not None, "AIEngine should be initialized in app.state.ai"
    assert ai_engine.pricing is not None, "Pricing model (.pkl) should be loaded in memory"
    assert ai_engine.ranking is not None, "Ranking model (.pkl) should be loaded in memory"


def test_acceptance_criteria_full_stock_upload_and_ranking_flow(client, db_session):
    """
    AC 2, 3, 4, 5, 6, 7:
    - Saran harga berasal dari model AI (bukan hanya aturan manual).
    - Seller bisa memilih saran sistem atau menetapkan harga sendiri.
    - Saat stok diterbitkan, sistem mencari pembeli dalam radius 15 km & memberi peringkat.
    - Tepat 5 pembeli dengan peringkat terbaik menerima notifikasi penawaran produk.
    - Pembeli yang menerima notifikasi bisa melihat detail listing produk dari seller.
    - Jika stok tidak terjual dan umur < 15 hari, lelang dihentikan dan stok dialihkan ke donasi.
    """
    # ── 1. Setup Seller ───────────────────────────────────────────────────────
    # Lokasi gudang seller: Jakarta Pusat (-6.1800, 106.8300)
    seller_res = client.post("/auth/register", json={
        "email": "seller_ac@recovera.id",
        "password": "Password123!",
        "role": "seller",
        "name": "Budi Distributor Pangan",
        "company_name": "PT Sumber Segar Abadi",
        "phone": "+628111222333",
        "address": "Jl. Hayam Wuruk No. 12",
        "warehouse_lat": -6.1800,
        "warehouse_lng": 106.8300,
        "city": "Jakarta Pusat",
    })
    assert seller_res.status_code == 201
    seller_token = seller_res.json()["data"]["access_token"]
    seller_headers = {"Authorization": f"Bearer {seller_token}"}

    # ── 2. Setup 7 Buyers: 6 within 15 km, 1 far away (> 20 km) ──────────────
    # Buyer 1-6 are close (~0.5 km to ~10 km), Buyer 7 is far in Bogor (> 40 km)
    buyer_tokens = []
    buyer_coords = [
        (-6.1820, 106.8310, "Buyer Resto 1", "resto"),     # ~0.2 km
        (-6.1750, 106.8250, "Buyer Bakery 2", "bakery"),   # ~0.8 km
        (-6.1900, 106.8200, "Buyer Katering 3", "katering"), # ~1.5 km
        (-6.2100, 106.8400, "Buyer Resto 4", "resto"),     # ~3.5 km
        (-6.2300, 106.8100, "Buyer Warung 5", "warung"),   # ~6.0 km
        (-6.2500, 106.8000, "Buyer Resto 6", "resto"),     # ~8.5 km
        (-6.5971, 106.8060, "Buyer Bogor Far 7", "resto"), # ~46 km (OUTSIDE 15 KM)
    ]
    for idx, (b_lat, b_lng, b_name, b_type) in enumerate(buyer_coords, 1):
        b_res = client.post("/auth/register", json={
            "email": f"buyer_ac_{idx}@recovera.id",
            "password": "Password123!",
            "role": "buyer",
            "name": b_name,
            "phone": f"+628777000{idx:03d}",
            "business_type": b_type,
            "address": f"Jl. Konsumen No. {idx}",
            "base_lat": b_lat,
            "base_lng": b_lng,
            "pref_categories": ["Dairy", "Beverage"],
        })
        assert b_res.status_code == 201
        buyer_tokens.append(b_res.json()["data"]["access_token"])

    # ── 3. Seller Unggah Stok Baru (Draft) ───────────────────────────────────
    # AC 2: Saran harga berasal dari model AI (source == "ml")
    exp_date_str = (date.today() + timedelta(days=40)).isoformat()
    draft_payload = {
        "sku": "SKU-AC-MILK-01",
        "barcode": "899202600101",
        "name": "Susu UHT Fresh 1L",
        "category": "Dairy",
        "brand": "Ultra Fresh",
        "storage_type": "ambient",
        "default_unit": "karton",
        "batch_number": "BATCH-AC-2026",
        "qty": 50,
        "normal_price": 200000.0,
        "min_price": 50000.0,
        "expiry_date": exp_date_str,
        "image_url": "https://storage.recovera.id/products/susu_uht.jpg",
    }
    draft_res = client.post(
        "/listings/seller/inventory/drafts",
        json=draft_payload,
        headers=seller_headers,
    )
    assert draft_res.status_code == 201
    draft_data = draft_res.json()["data"]
    listing_id = draft_data["listing"]["id"]
    price_rec = draft_data["price_recommendation"]

    # Pastikan saran harga berasal dari model AI (ML)
    assert price_rec["source"] == "ml", "Harga rekomendasi saat upload draft harus berasal dari model AI (ML)"
    assert price_rec["suggested_price"] > 0
    assert price_rec["discount_pct"] > 0
    suggested_price = price_rec["suggested_price"]

    # Cek endpoint rekomendasi ulang harga seller
    rec_res = client.post(
        f"/listings/seller/inventory/{listing_id}/recommendation",
        headers=seller_headers,
    )
    assert rec_res.status_code == 200
    rec_data = rec_res.json()["data"]["recommendation"]
    assert rec_data["source"] == "ml", "Rekomendasi ulang juga harus berasal dari model AI"

    # ── 4. AC 3: Seller bisa memilih saran sistem atau menetapkan harga sendiri
    # Skenario 4a: Seller menetapkan harga sendiri (custom price)
    custom_start_price = round(suggested_price * 1.05)  # Seller menaikkan sedikit harga
    patch_res = client.patch(
        f"/listings/seller/inventory/{listing_id}",
        json={"start_price": custom_start_price},
        headers=seller_headers,
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["data"]["listing"]["start_price"] == custom_start_price

    # ── 5. AC 4 & 5: Penerbitan Stok & Perangkingan AI Top 5 Pembeli ─────────
    # Saat stok diterbitkan, AI ranking model mencari pembeli dlm 15 km dan merangking
    publish_res = client.post(
        f"/listings/seller/inventory/{listing_id}/publish",
        json={"acknowledge_price_warning": True},
        headers=seller_headers,
    )
    assert publish_res.status_code == 200
    pub_data = publish_res.json()["data"]
    assert pub_data["status"] == "active"

    # Cek matching summary: pembeli dalam radius 15 km berhasil diranking
    matching_summary = pub_data.get("matching_summary")
    assert matching_summary is not None
    # Ada 6 pembeli dlm radius 15 km, tepat Top 5 terpilih
    assert matching_summary["total_offers_sent"] == 5, "Tepat lima pembeli terbaik harus menerima tawaran"
    assert len(matching_summary["top_buyers"]) == 5

    for buyer_info in matching_summary["top_buyers"]:
        assert buyer_info["distance_km"] <= 15.0, "Hanya pembeli dlm radius 15 km yang boleh dirangking"
        assert 0.0 <= buyer_info["match_score"] <= 1.0, "Probabilitas ranking harus di antara 0.0 dan 1.0"

    # ── 6. AC 5: Notifikasi diterima oleh 5 pembeli terpilih ──────────────────
    # Verifikasi notifikasi di database / inbox pembeli
    offers = db_session.query(Offer).filter(Offer.listing_id == listing_id).all()
    assert len(offers) == 5

    notifs = db_session.query(Notification).filter(Notification.type.in_(["deal_match", "offer"])).all()
    assert len(notifs) >= 5

    # Cek bahwa notifikasi berisi info produk, diskon, jarak, dan penawaran terbatas
    sample_notif = notifs[-1]
    assert "Susu UHT Fresh 1L" in sample_notif.body or "Penawaran" in sample_notif.body
    assert "terbatas" in sample_notif.body.lower()
    assert f"#{listing_id}" in sample_notif.body

    # ── 7. AC 6: Pembeli yang menerima notifikasi bisa melihat detail listing
    # Ambil token dari salah satu buyer penerima
    buyer_headers = {"Authorization": f"Bearer {buyer_tokens[0]}"}
    detail_res = client.get(f"/listings/{listing_id}", headers=buyer_headers)
    assert detail_res.status_code == 200
    detail_data = detail_res.json()["data"]
    assert detail_data["id"] == listing_id
    assert detail_data["status"] == "active"
    assert detail_data["product"]["name"] == "Susu UHT Fresh 1L"
    assert detail_data["seller_company"] == "PT Sumber Segar Abadi"
    assert detail_data["current_price"] > 0

    # ── 8. AC 7: Pengalihan ke Donasi bila sisa umur < 15 hari ───────────────
    # Simulasikan stok belum terjual dan sisa umur mencapai batas kritis (< 15 hari)
    listing_obj = db_session.query(Listing).filter(Listing.id == listing_id).first()
    assert listing_obj is not None
    listing_obj.expiry_date = date.today() + timedelta(days=10) # 10 hari (< 15 hari)
    db_session.commit()

    # Eksekusi aturan pengalihan donasi
    donation = divert_listing_to_donation(db_session, listing_obj)
    assert donation is not None
    assert listing_obj.status == "diverted", "Lelang otomatis dihentikan dan status menjadi diverted"
    assert donation.qty_diverted == listing_obj.qty
    assert donation.carbon_saved_kg > 0
    assert donation.certificate_no.startswith("ESG-ID-2026-")

    # Verifikasi sertifikat donasi dapat diakses
    cert_res = client.get(f"/donations/{donation.id}/certificate")
    assert cert_res.status_code == 200
    cert_data = cert_res.json()["data"]
    assert cert_data["certificate_no"] == donation.certificate_no
    assert cert_data["qty_diverted"] == 50
    assert cert_data["monetary_value"]["idr"] > 0
