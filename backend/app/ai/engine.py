"""Inferensi hibrida: guardrail -> (model | fallback) -> guardrail.
Model gagal dimuat / error saat prediksi => otomatis rule-based, API tidak crash."""
import logging
from dataclasses import dataclass, asdict
from pathlib import Path

import joblib
import lightgbm
import numpy as np
import pandas as pd
import sklearn

try:
    from .config import (BAND_PP, HEADROOM_PP, MODEL_DIR, PRICING_CATEGORICAL, PRICING_FEATURES,
                         RANKING_CATEGORICAL, RANKING_FEATURES, TOP_K)
    from .features import make_matrix
    from .guardrails import clip_discount, filter_eligible_buyers, must_divert
    from .rules import rule_start_discount, weighted_rank_score
except ImportError:
    from app.ai.config import (BAND_PP, HEADROOM_PP, MODEL_DIR, PRICING_CATEGORICAL, PRICING_FEATURES,
                             RANKING_CATEGORICAL, RANKING_FEATURES, TOP_K)
    from app.ai.features import make_matrix
    from app.ai.guardrails import clip_discount, filter_eligible_buyers, must_divert
    from app.ai.rules import rule_start_discount, weighted_rank_score

log = logging.getLogger("recovera.ai")


@dataclass
class PriceAdvice:
    divert: bool
    discount_pct: float | None
    suggested_price: float | None
    baseline_discount_pct: float | None
    source: str              # "ml" | "rule"
    cap_applied: bool = False
    model_version: str | None = None

    def to_dict(self):
        return asdict(self)


def _load_bundle(path: Path):
    if not path.exists():
        log.warning("model %s tidak ada -> fallback rule-based", path.name)
        return None
    try:
        b = joblib.load(path)          # hanya muat .pkl buatan sendiri (pickle = eksekusi kode)
        for k in ("model", "features", "categorical", "cat_levels", "version"):
            if k not in b:
                raise KeyError(k)
        v = b.get("lib_versions", {})
        if v.get("lightgbm") != lightgbm.__version__ or v.get("sklearn") != sklearn.__version__:
            log.warning("versi library beda dari saat training: %s vs now lgbm=%s sk=%s",
                        v, lightgbm.__version__, sklearn.__version__)
        return b
    except Exception:
        log.exception("gagal memuat %s -> fallback rule-based", path.name)
        return None


class AIEngine:
    def __init__(self, model_dir: Path = MODEL_DIR, use_ml: bool = True):
        self.use_ml = use_ml            # feature flag (PRD D1/D2: ML = v1.1)
        self.pricing = self.ranking = None
        if use_ml:
            self.pricing = _load_bundle(Path(model_dir) / "pricing_model.pkl")
            self.ranking = _load_bundle(Path(model_dir) / "ranking_model.pkl")

    # ------------------------------------------------------------------ pricing
    def advise_price(self, listing: dict) -> PriceAdvice:
        """listing: category, storage_type, days_to_expiry, qty, normal_price, min_price"""
        days = listing["days_to_expiry"]
        if must_divert(days):
            return PriceAdvice(True, None, None, None, "rule")

        base = rule_start_discount(days)
        d, source, version = base, "rule", None
        if self.pricing is not None:
            try:
                b = self.pricing
                M = make_matrix(pd.DataFrame([listing]), b["features"], b["categorical"], b["cat_levels"])
                clearing = float(b["model"].booster_.predict(M, num_threads=1)[0])
                d = float(np.clip(clearing - HEADROOM_PP, base - BAND_PP, base + BAND_PP))
                source, version = "ml", b["version"]
            except Exception:
                log.exception("prediksi pricing gagal -> rule-based")
                d = base
        d, capped = clip_discount(d, listing["normal_price"], listing["min_price"])
        price = listing["normal_price"] * (1 - d / 100.0)
        assert price >= listing["min_price"] - 1e-6, "INVARIANT: harga < min_price"
        return PriceAdvice(False, round(d, 1), round(price), base, source, capped, version)

    # ------------------------------------------------------------------ ranking
    def match_buyers(self, listing: dict, buyers: pd.DataFrame, k: int = TOP_K) -> list[dict]:
        """listing: + warehouse_lat/lng, offered_discount_pct. buyers: baris tabel buyers
        (+ kolom id sebagai buyer_id). Hanya pembeli yang LOLOS guardrail yang pernah dinilai."""
        if must_divert(listing["days_to_expiry"]):
            return []
        cand = filter_eligible_buyers(listing, buyers)
        if cand.empty:
            return []
        cand = cand.assign(days_to_expiry=listing["days_to_expiry"],
                           offered_discount_pct=listing["offered_discount_pct"],
                           storage_type=listing["storage_type"])
        scores, source, version = None, "rule", None
        if self.ranking is not None:
            try:
                b = self.ranking
                M = make_matrix(cand, b["features"], b["categorical"], b["cat_levels"])
                scores = b["model"].booster_.predict(M, num_threads=1)
                source, version = "ml", b["version"]
            except Exception:
                log.exception("prediksi ranking gagal -> skor berbobot")
                scores = None
        if scores is None:
            scores = weighted_rank_score(cand).to_numpy()
        cand = cand.assign(match_score=np.round(scores, 3)).sort_values("match_score", ascending=False)
        
        # Aturan Eksplorasi: 4 Model + 1 Explore agar bebas dari selection bias
        result = []
        if len(cand) <= k:
            for _, r in cand.iterrows():
                result.append(dict(
                    buyer_id=int(r["buyer_id"]),
                    match_score=float(r["match_score"]),
                    distance_km=round(float(r["distance_km"]), 2),
                    selection_source="model",
                    source=source,
                    model_version=version,
                ))
        else:
            model_top = cand.head(k - 1)
            for _, r in model_top.iterrows():
                result.append(dict(
                    buyer_id=int(r["buyer_id"]),
                    match_score=float(r["match_score"]),
                    distance_km=round(float(r["distance_km"]), 2),
                    selection_source="model",
                    source=source,
                    model_version=version,
                ))
            remaining = cand.iloc[k - 1:]
            explore_pick = remaining.sample(n=1, random_state=None).iloc[0]
            result.append(dict(
                buyer_id=int(explore_pick["buyer_id"]),
                match_score=float(explore_pick["match_score"]),
                distance_km=round(float(explore_pick["distance_km"]), 2),
                selection_source="explore",
                source=source,
                model_version=version,
            ))
        return result
