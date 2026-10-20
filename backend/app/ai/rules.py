"""Baseline deterministik: dipakai di MVP, sebagai pembanding, dan sebagai fail-safe."""
import pandas as pd
from .config import MAX_RADIUS_KM, ORDERS_NORM_CAP, RANK_WEIGHTS


def rule_start_discount(days_to_expiry: float) -> float:
    """Tier diskon awal (PRD US-06)."""
    d = days_to_expiry
    if d > 90:
        return 25.0
    if d >= 60:
        return 30.0
    if d >= 30:
        return 40.0
    if d >= 15:
        return 50.0
    return 55.0


def max_discount_for_floor(normal_price: float, min_price: float) -> float:
    """Diskon maksimum (%) agar harga tidak melewati min_price."""
    return max(0.0, (1.0 - min_price / normal_price) * 100.0)


def current_price(normal_price, start_discount_pct, steps_elapsed, drop_pct, min_price) -> float:
    """Dutch auction. ASUMSI: step_turun linear = steps * drop_pct (dipotong 0..1).
    Ganti di satu tempat ini bila PRD memakai kompaun."""
    step_turun = min(max(steps_elapsed * drop_pct / 100.0, 0.0), 1.0)
    price = normal_price * (1 - start_discount_pct / 100.0) * (1 - step_turun)
    return max(min_price, price)


def weighted_rank_score(df: pd.DataFrame) -> pd.Series:
    """Skor berbobot tetap 0.4/0.3/0.2/0.1 -> baseline & fallback ranking."""
    w_dist, w_cat, w_rel, w_ord = RANK_WEIGHTS
    dist = (1 - df["distance_km"].astype(float) / MAX_RADIUS_KM).clip(0, 1)
    orders = (df["total_orders_completed"].astype(float) / ORDERS_NORM_CAP).clip(0, 1)
    return (w_dist * dist + w_cat * df["category_match"].astype(float)
            + w_rel * df["payment_reliability_score"].astype(float) + w_ord * orders)
