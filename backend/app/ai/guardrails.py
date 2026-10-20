"""Hard rules. Dijalankan SEBELUM model & dipakai ulang oleh seeder (satu logika)."""
import json
import numpy as np
import pandas as pd
from .config import COLD_CHAIN_STORAGE, DIVERSION_DAYS, MAX_RADIUS_KM
from .rules import max_discount_for_floor


def haversine_km(lat1, lng1, lat2, lng2):
    lat1, lng1, lat2, lng2 = map(np.radians, (lat1, lng1, lat2, lng2))
    a = np.sin((lat2 - lat1) / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin((lng2 - lng1) / 2) ** 2
    return 6371.0088 * 2 * np.arcsin(np.sqrt(a))


def must_divert(days_to_expiry: float) -> bool:
    return days_to_expiry < DIVERSION_DAYS


def requires_cold_chain(storage_type: str) -> bool:
    return storage_type in COLD_CHAIN_STORAGE


def as_list(x) -> list:
    """pref_categories bisa list (DB/jsonb) atau string JSON (CSV)."""
    if isinstance(x, (list, tuple, np.ndarray)):
        return list(x)
    if isinstance(x, str):
        try:
            v = json.loads(x)
            return list(v) if isinstance(v, list) else []
        except json.JSONDecodeError:
            return []
    return []


def category_match(pref_categories, category: str) -> int:
    return int(category.lower() in {str(c).lower() for c in as_list(pref_categories)})


def filter_eligible_buyers(listing: dict, buyers: pd.DataFrame) -> pd.DataFrame:
    """Radius (<=15 km & max_radius_km pembeli) + syarat rantai dingin.
    Mengembalikan salinan dengan kolom distance_km & category_match."""
    if buyers.empty:
        return buyers.assign(distance_km=[], category_match=[])
    dist = haversine_km(listing["warehouse_lat"], listing["warehouse_lng"],
                        buyers["base_lat"].to_numpy(float), buyers["base_lng"].to_numpy(float))
    radius = np.minimum(MAX_RADIUS_KM, buyers["max_radius_km"].to_numpy(float))
    mask = dist <= radius
    if requires_cold_chain(listing["storage_type"]):
        mask &= buyers["has_cold_storage"].to_numpy(bool)
    out = buyers.loc[mask].copy()
    out["distance_km"] = dist[mask]
    out["category_match"] = [category_match(p, listing["category"]) for p in out["pref_categories"]]
    return out


def clip_discount(discount_pct: float, normal_price: float, min_price: float) -> tuple[float, bool]:
    """Pastikan harga hasil >= min_price. Return (diskon_final, apakah_terpotong)."""
    cap = max_discount_for_floor(normal_price, min_price)
    final = min(max(discount_pct, 0.0), cap)
    return final, final != discount_pct
