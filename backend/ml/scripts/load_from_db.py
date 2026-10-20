"""Ekstraksi data latih dari PostgreSQL (skema Recovera). BELUM DIUJI terhadap DB asli --
jalankan `--audit-only` dulu dan periksa hasilnya sebelum percaya angka metrik."""
import os
import warnings
import pandas as pd

# Label: accepted=1, expired=0. 'sent'/'opened' DIBUANG (hasil belum final = censoring).
RANKING_SQL_SNAPSHOT = """
SELECT o.id AS offer_id, o.listing_id, o.buyer_id, o.sent_at, o.status,
       o.distance_km, o.days_to_expiry, o.offered_discount_pct,
       o.category_match, o.buyer_orders_snapshot AS total_orders_completed,
       o.buyer_reliability_snapshot AS payment_reliability_score,
       b.business_type, p.category, p.storage_type
FROM offers o
JOIN buyers b ON b.id = o.buyer_id
JOIN listings l ON l.id = o.listing_id
JOIN products p ON p.id = l.product_id
WHERE o.status IN ('accepted','expired') AND o.category_match IS NOT NULL
"""
# Fallback sebelum migrasi snapshot: pakai nilai buyers SEKARANG -> ada risiko kebocoran
# (total_orders_completed bertambah SETELAH menerima penawaran). Hanya untuk eksplorasi.
RANKING_SQL_LEGACY = """
SELECT o.id AS offer_id, o.listing_id, o.buyer_id, o.sent_at, o.status,
       o.distance_km, o.days_to_expiry, o.offered_discount_pct,
       b.pref_categories, b.total_orders_completed, b.payment_reliability_score,
       b.business_type, p.category, p.storage_type
FROM offers o
JOIN buyers b ON b.id = o.buyer_id
JOIN listings l ON l.id = o.listing_id
JOIN products p ON p.id = l.product_id
WHERE o.status IN ('accepted','expired')
"""
# Pricing: target = diskon saat order PERTAMA terjadi (revealed willingness-to-pay).
PRICING_SQL = """
SELECT DISTINCT ON (l.id)
       l.id AS listing_id, l.created_at, p.category, p.storage_type, l.qty,
       l.normal_price, l.min_price,
       (l.expiry_date - l.auction_start_at::date) AS days_to_expiry,
       o.final_unit_price,
       100.0 * (1 - o.final_unit_price / l.normal_price) AS clearing_discount_pct
FROM listings l
JOIN products p ON p.id = l.product_id
JOIN orders o ON o.listing_id = l.id
ORDER BY l.id, o.created_at
"""


def _engine():
    from sqlalchemy import create_engine
    return create_engine(os.environ["DATABASE_URL"])  # postgresql+psycopg://user:pw@host/db


def load_frames():
    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from ai.guardrails import category_match

    eng = _engine()
    try:
        rk = pd.read_sql(RANKING_SQL_SNAPSHOT, eng)
        if rk.empty:
            raise ValueError("snapshot kosong")
    except Exception:
        warnings.warn("kolom snapshot belum ada (jalankan sql/001_offers_snapshot.sql). "
                      "Memakai nilai buyers SAAT INI -> metrik ranking berpotensi bocor/optimistis.")
        rk = pd.read_sql(RANKING_SQL_LEGACY, eng)
        rk["category_match"] = [category_match(p, c) for p, c in zip(rk.pop("pref_categories"), rk["category"])]
    rk["label"] = (rk["status"] == "accepted").astype(int)
    pr = pd.read_sql(PRICING_SQL, eng)
    pr["sold"] = 1
    return pr, rk
