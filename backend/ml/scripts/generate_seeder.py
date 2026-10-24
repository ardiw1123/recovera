"""Generator data sintetis (cold-start). Output CSV format datar yang SAMA dengan loader DB.

PERINGATAN JUJUR: label dibangkitkan dari rumus yang kita tulis sendiri. Model hanya akan
'menemukan kembali' rumus ini. Gunakan untuk (1) menguji pipeline end-to-end dan (2) demo,
BUKAN sebagai bukti performa di dunia nyata. Kolom _true_p dipakai untuk menghitung
batas atas (oracle) metrik & TIDAK BOLEH menjadi fitur.
"""
import argparse
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ai.config import BUSINESS_TYPES, CATEGORIES, DATA_DIR  # noqa: E402
from ai.guardrails import filter_eligible_buyers  # noqa: E402
from ai.rules import rule_start_discount  # noqa: E402

CENTER = (-7.7956, 110.3695)
STORAGE_OF = {"Dairy": "chilled", "Frozen": "frozen", "Oil": "ambient", "Flour": "ambient", "Canned": "ambient"}
BASE_PRICE = {"Dairy": 22000, "Frozen": 45000, "Oil": 18000, "Flour": 12000, "Canned": 15000}
CAT_ADJ = {"Dairy": 5.0, "Frozen": 4.0, "Oil": -3.0, "Flour": -2.0, "Canned": -4.0}
PERISHABLE = {"Dairy", "Frozen"}
BT_EFFECT = {"katering": 0.35, "resto": 0.20, "bakery": 0.0, "warung": -0.30}
COLD_P = {"bakery": .4, "katering": .6, "resto": .7, "warung": .2}


def make_buyers(rng, n):
    bt = rng.choice(BUSINESS_TYPES, n, p=[.2, .3, .3, .2])
    return pd.DataFrame({
        "buyer_id": np.arange(1, n + 1),
        "business_type": bt,
        "base_lat": CENTER[0] + rng.normal(0, .06, n),
        "base_lng": CENTER[1] + rng.normal(0, .06, n),
        "pref_categories": [list(rng.choice(CATEGORIES, rng.integers(1, 4), replace=False)) for _ in range(n)],
        "max_radius_km": rng.choice([5, 10, 15], n, p=[.2, .3, .5]),
        "has_cold_storage": [rng.random() < COLD_P[t] for t in bt],
        "total_orders_completed": rng.gamma(2.0, 8.0, n).astype(int),
        "payment_reliability_score": np.clip(rng.beta(8, 2, n), .3, 1.0).round(2),
        "_appetite": rng.normal(0, .5, n),   # faktor laten TIDAK teramati model
    })


def logit_core(r):
    """Logit tanpa intercept. Semua efek = asumsi domain (lihat README)."""
    perish = r["storage_type"] in ("chilled", "frozen")
    z = (1.3 * r["category_match"] - 0.16 * r["distance_km"] + 0.045 * r["offered_discount_pct"]
         + 1.5 * (r["payment_reliability_score"] - 0.8) + 0.35 * np.log1p(r["total_orders_completed"])
         + BT_EFFECT[r["business_type"]] + r["_appetite"])
    if perish:
        z += -0.05 * max(0, 45 - r["days_to_expiry"]) + 0.03 * r["offered_discount_pct"] * (r["days_to_expiry"] < 45)
    return z


def label_offers(off, rng, base_rate):
    """Kalibrasi intercept (bisection) agar rata2 p = base_rate, lalu sampel label. Kolom _true_p
    hanya untuk menghitung batas atas (oracle); JANGAN jadi fitur."""
    core = off.apply(logit_core, axis=1).to_numpy()
    lo, hi = -10.0, 10.0
    for _ in range(60):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if (1 / (1 + np.exp(-(core + mid)))).mean() < base_rate else (lo, mid)
    p = 1 / (1 + np.exp(-(core + (lo + hi) / 2)))
    off = off.copy()
    off["_true_p"] = p.round(4)
    off["label"] = (rng.random(len(off)) < p).astype(int)
    off["status"] = np.where(off["label"] == 1, "accepted", "expired")
    off.insert(0, "offer_id", np.arange(1, len(off) + 1))
    return off.drop(columns=["_appetite"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--n-buyers", type=int, default=300)
    ap.add_argument("--n-listings", type=int, default=600)
    ap.add_argument("--cands", type=int, default=15, help="kandidat per listing (>=15 agar Precision@5 bermakna)")
    ap.add_argument("--base-rate", type=float, default=0.22)
    ap.add_argument("--noise-pp", type=float, default=3.5, help="sigma noise clearing discount")
    ap.add_argument("--out", type=Path, default=DATA_DIR)
    a = ap.parse_args()
    rng = np.random.default_rng(a.seed)
    args_out = a.out
    args_out.mkdir(parents=True, exist_ok=True)

    buyers = make_buyers(rng, a.n_buyers)
    sellers = [(CENTER[0] + rng.normal(0, .05), CENTER[1] + rng.normal(0, .05)) for _ in range(12)]
    t0 = datetime(2026, 5, 1, tzinfo=timezone.utc)

    listings, offers = [], []
    for i in range(a.n_listings):
        cat = str(rng.choice(CATEGORIES, p=[.25, .2, .2, .15, .2]))
        days = int(rng.integers(15, 181))            # <15 hari = auto-divert, bukan lelang
        qty = int(np.clip(rng.lognormal(5.3, .6), 20, 2000))
        normal = float(round(BASE_PRICE[cat] * rng.lognormal(0, .25) / 500) * 500)
        min_price = float(round(normal * rng.uniform(.25, .40)))
        created = t0 + timedelta(days=120 * i / a.n_listings, hours=float(rng.uniform(0, 6)))
        lat, lng = sellers[int(rng.integers(0, len(sellers)))]
        tier = rule_start_discount(days)

        # ---- pricing: clearing discount (diskon saat Buy Now terjadi)
        perish_extra = 0.08 * max(0, 60 - days) if cat in PERISHABLE else 0.0
        clearing = (tier + 8.0 + CAT_ADJ[cat] + perish_extra + 2.0 * np.log(qty / 200)
                    + rng.normal(0, a.noise_pp))
        clearing = float(np.clip(clearing, 5, 70))
        final_price = normal * (1 - clearing / 100)
        sold = final_price >= min_price
        listings.append(dict(listing_id=i + 1, created_at=created, category=cat, storage_type=STORAGE_OF[cat],
                             days_to_expiry=days, qty=qty, normal_price=normal, min_price=min_price,
                             start_discount_pct=tier, sold=int(sold),
                             final_unit_price=round(final_price) if sold else np.nan,
                             clearing_discount_pct=round(clearing, 2) if sold else np.nan))

        # ---- ranking: kandidat lolos guardrail
        L = dict(category=cat, storage_type=STORAGE_OF[cat], warehouse_lat=lat, warehouse_lng=lng)
        cand = filter_eligible_buyers(L, buyers)
        if len(cand) < 5:
            continue
        cand = cand.sample(min(a.cands, len(cand)), random_state=int(rng.integers(1 << 30)))
        for _, b in cand.iterrows():
            offers.append(dict(
                listing_id=i + 1, buyer_id=int(b["buyer_id"]),
                sent_at=created + timedelta(hours=float(rng.uniform(0, 3))),
                distance_km=round(float(b["distance_km"]), 2), days_to_expiry=days,
                offered_discount_pct=round(tier + float(rng.uniform(0, 10)), 1),
                category_match=int(b["category_match"]), business_type=b["business_type"],
                storage_type=STORAGE_OF[cat], category=cat,
                total_orders_completed=int(b["total_orders_completed"]),
                payment_reliability_score=float(b["payment_reliability_score"]),
                _appetite=float(b["_appetite"])))

    off = label_offers(pd.DataFrame(offers), rng, a.base_rate)

    pd.DataFrame(listings).to_csv(a.out / "pricing_seed.csv", index=False)
    off.to_csv(a.out / "ranking_seed.csv", index=False)
    print(f"pricing_seed.csv: {len(listings)} baris | ranking_seed.csv: {len(off)} baris | "
          f"positive rate={off['label'].mean():.3f} | listing sold={np.mean([l['sold'] for l in listings]):.2%}")


if __name__ == "__main__":
    main()
