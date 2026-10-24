"""Satu sumber kebenaran untuk semua konstanta AI Recovera.
Semua angka bisnis diubah DI SINI, bukan di dalam fungsi."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = Path(__file__).resolve().parent / "artifacts"
DATA_DIR = ROOT / "data"

# ---------- Hard rules (guardrail, tidak boleh dilanggar model) ----------
MAX_RADIUS_KM = 15.0
# PRD menulis "<15 hari" dan "<14 hari" di tempat berbeda -> PUTUSKAN SATU nilai.
DIVERSION_DAYS = 15
COLD_CHAIN_STORAGE = {"chilled", "frozen"}

# ---------- Kategori baku (dropdown) ----------
CATEGORIES = ['Beverage', 'Canned', 'Dairy', 'Flour & Grain', 'Frozen', 'Oil']
STORAGE_TYPES = ["ambient", "chilled", "frozen"]
BUSINESS_TYPES = ["bakery", "katering", "resto", "warung"]
CAT_LEVELS = {
    "category": CATEGORIES,
    "storage_type": STORAGE_TYPES,
    "business_type": BUSINESS_TYPES,
}

# ---------- Baseline rule-based (MVP + fallback) ----------
RANK_WEIGHTS = (0.4, 0.3, 0.2, 0.1)  # jarak, kecocokan kategori, reliabilitas, riwayat order
ORDERS_NORM_CAP = 50                 # total_orders >= 50 dianggap "penuh"

# ---------- Pricing: hubungan model <-> aturan ----------
# Model memprediksi CLEARING discount (diskon saat pembeli benar2 menekan Buy Now).
# Start discount = clearing - HEADROOM (ruang agar lelang punya ruang turun).
# Kira2: 3 interval turun x drop_percentage 2.5% ~ 8 poin. Kalibrasi dgn data nyata.
HEADROOM_PP = 8.0
# Model hanya boleh menyimpang +-BAND dari tier aturan -> kerusakan terburuk terbatas.
BAND_PP = 10.0

TOP_K = 5

# ---------- Fitur (urutan = kontrak training <-> serving) ----------
PRICING_FEATURES = ["category", "storage_type", "days_to_expiry", "qty", "normal_price"]
PRICING_CATEGORICAL = ["category", "storage_type"]
PRICING_MONOTONE = {"days_to_expiry": -1}  # makin sedikit sisa hari -> diskon tidak turun

# storage_type DITAMBAHKAN (tidak ada di spesifikasi awal): efek days_to_expiry
# berbeda untuk barang beku/dingin vs kering; tanpa ini model tak bisa belajar interaksinya.
RANKING_FEATURES = [
    "distance_km", "days_to_expiry", "offered_discount_pct", "category_match",
    "business_type", "storage_type", "total_orders_completed", "payment_reliability_score",
]
RANKING_CATEGORICAL = ["business_type", "storage_type"]
RANKING_MONOTONE = {  # asumsi domain; HAPUS bila data nyata membantahnya
    "distance_km": -1, "offered_discount_pct": 1, "category_match": 1,
    "total_orders_completed": 1, "payment_reliability_score": 1,
}
