"""Bangun data latih dari KATALOG RIIL di DB-mu (listings + sellers + products + buyers).

Kenapa perlu: tabel `offers` hasil seeder-mu tidak bisa dilatih (1 penawaran/listing, tanpa
negatif 'expired', snapshot NULL). Skrip ini memakai listing, gudang, dan pembeli aslimu
(lokasi, tipe usaha, rantai dingin, kategori) lalu mensimulasikan PENAWARAN KANDIDAT + hasilnya
dengan rumus domain yang sama seperti generate_seeder.py. Output: data/ranking_seed.csv dan
data/pricing_seed.csv -> latih dengan `train_models.py --source csv`.

Kejujuran: label ranking = hasil simulasi (bukan perilaku pembeli nyata). Pricing = hanya listing
yang BENAR-BENAR terjual (order nyata di DB). Hanya SELECT; tidak menulis ke DB.
Pakai:  $env:DATABASE_URL="postgresql+psycopg://..."; python scripts/seed_from_catalog.py
"""
import argparse
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ai import config as C  # noqa: E402
from ai.guardrails import filter_eligible_buyers  # noqa: E402
from ai.rules import rule_start_discount  # noqa: E402
from scripts.generate_seeder import label_offers  # noqa: E402

LISTINGS_SQL = """
SELECT l.id AS listing_id, l.created_at, l.qty, l.normal_price, l.min_price, l.status,
       (l.expiry_date - l.auction_start_at::date) AS days_to_expiry,
       p.category, p.storage_type, s.warehouse_lat, s.warehouse_lng
FROM listings l JOIN products p ON p.id = l.product_id JOIN sellers s ON s.id = l.seller_id
"""
BUYERS_SQL = """
SELECT id AS buyer_id, business_type, base_lat, base_lng, pref_categories, max_radius_km,
       has_cold_storage, total_orders_completed, payment_reliability_score FROM buyers
"""
T0 = datetime(2026, 5, 1, tzinfo=timezone.utc)


def build_ranking(listings, buyers, rng, cands=15, base_rate=0.22):
    """Pure function (bisa diuji tanpa DB). Mengembalikan (df_offers, stat_kandidat)."""
    buyers = buyers.assign(_appetite=rng.normal(0, .5, len(buyers)))
    L = listings[listings["days_to_expiry"] >= C.DIVERSION_DAYS].sort_values("listing_id")
    n, rows, elig = len(L), [], []
    for rank, (_, l) in enumerate(L.iterrows()):
        cand = filter_eligible_buyers(l.to_dict(), buyers)
        elig.append(len(cand))
        if len(cand) < C.TOP_K:
            continue
        cand = cand.sample(min(cands, len(cand)), random_state=int(rng.integers(1 << 30)))
        tier = rule_start_discount(l["days_to_expiry"])
        sent = T0 + timedelta(days=120 * rank / max(n, 1))   # timeline sintetis menurut urutan listing
        for _, b in cand.iterrows():
            rows.append(dict(
                listing_id=int(l["listing_id"]), buyer_id=int(b["buyer_id"]),
                sent_at=sent + timedelta(hours=float(rng.uniform(0, 3))),
                distance_km=round(float(b["distance_km"]), 2), days_to_expiry=int(l["days_to_expiry"]),
                offered_discount_pct=round(tier + float(rng.uniform(0, 10)), 1),
                category_match=int(b["category_match"]), business_type=b["business_type"],
                storage_type=l["storage_type"], category=l["category"],
                total_orders_completed=int(b["total_orders_completed"]),
                payment_reliability_score=float(b["payment_reliability_score"]),
                _appetite=float(b["_appetite"])))
    if not rows:
        return pd.DataFrame(), np.array(elig)
    return label_offers(pd.DataFrame(rows), rng, base_rate), np.array(elig)


def filter_categories(listings, pricing):
    """Kategori mayor (>=2% listing) yang belum ada di config -> berhenti & beri baris untuk disalin.
    Kategori minor (mis. baris uji 'QA') -> dibuang dengan peringatan, bukan masuk kontrak model."""
    known = set(C.CATEGORIES)
    counts = listings["category"].value_counts()
    unknown = [c for c in counts.index if c not in known]
    if not unknown:
        return listings, pricing
    major = sorted(c for c, n in counts.items() if n / len(listings) >= 0.02)
    if any(c not in known for c in major):
        sys.exit(f"\nKategori mayor di DB-mu belum ada di ai/config.py: {[c for c in major if c not in known]}\n"
                 f"Ganti baris CATEGORIES di config.py dengan:\nCATEGORIES = {major}\n"
                 f"lalu jalankan ulang. (Daftar ini = kontrak training<->serving.)")
    print(f"[peringatan] membuang kategori minor di luar config: {{c: int(counts[c]) for c in unknown}}"
          .replace("{c: int(counts[c]) for c in unknown}", str({c: int(counts[c]) for c in unknown})))
    return (listings[listings["category"].isin(known)],
            pricing[pricing["category"].isin(known)])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--cands", type=int, default=15)
    ap.add_argument("--base-rate", type=float, default=0.22)
    ap.add_argument("--out", type=Path, default=C.DATA_DIR)
    a = ap.parse_args()
    from sqlalchemy import create_engine
    from scripts.load_from_db import PRICING_SQL
    eng = create_engine(os.environ["DATABASE_URL"])
    listings, buyers = pd.read_sql(LISTINGS_SQL, eng), pd.read_sql(BUYERS_SQL, eng)
    pricing = pd.read_sql(PRICING_SQL, eng)

    print(f"[katalog] listing={len(listings)} buyer={len(buyers)} | status listing: "
          f"{listings['status'].value_counts().to_dict()}")
    print(f"[katalog] kategori: {listings['category'].value_counts().to_dict()}")
    print(f"[katalog] storage_type: {listings['storage_type'].value_counts().to_dict()}")
    print(f"[katalog] days_to_expiry: min={listings['days_to_expiry'].min()} "
          f"median={listings['days_to_expiry'].median()} max={listings['days_to_expiry'].max()} | "
          f"listing <{C.DIVERSION_DAYS} hari (auto-divert): {(listings['days_to_expiry'] < C.DIVERSION_DAYS).sum()}")
    listings, pricing = filter_categories(listings, pricing)

    rng = np.random.default_rng(a.seed)
    off, elig = build_ranking(listings, buyers, rng, a.cands, a.base_rate)
    if off.empty:
        sys.exit("Tidak ada listing dengan >=5 pembeli lolos guardrail (radius 15 km / rantai dingin). "
                 "Cek sebaran koordinat seller vs buyer di DB-mu.")
    print(f"[kandidat] pembeli lolos guardrail per listing: median={np.median(elig):.0f} "
          f"p10={np.percentile(elig, 10):.0f} min={elig.min()} max={elig.max()} | "
          f"listing terpakai={off['listing_id'].nunique()}/{(listings['days_to_expiry'] >= C.DIVERSION_DAYS).sum()}")

    pricing = pricing.assign(sold=1, start_discount_pct=pricing["days_to_expiry"].map(rule_start_discount))
    if pricing["created_at"].nunique() < 20:   # seeder massal -> timeline proksi dari urutan listing
        pricing = pricing.sort_values("listing_id")
        pricing["created_at"] = [T0 + timedelta(days=120 * i / len(pricing)) for i in range(len(pricing))]
    a.out.mkdir(parents=True, exist_ok=True)
    off.to_csv(a.out / "ranking_seed.csv", index=False)
    pricing.to_csv(a.out / "pricing_seed.csv", index=False)
    print(f"[tulis] ranking_seed.csv={len(off)} baris (positif {off['label'].mean():.1%}) | "
          f"pricing_seed.csv={len(pricing)} listing terjual NYATA")


if __name__ == "__main__":
    main()