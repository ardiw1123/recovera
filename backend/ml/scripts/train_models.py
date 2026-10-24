"""Latih + evaluasi + serialisasi pricing_model.pkl & ranking_model.pkl.
Pakai:  python scripts/train_models.py --source csv           (seeder CSV)
        python scripts/train_models.py --source db --audit-only
        python scripts/train_models.py --source db
"""
import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd
import sklearn
from sklearn.metrics import brier_score_loss, log_loss, mean_absolute_error, roc_auc_score

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ai import config as C  # noqa: E402
from ai.engine import AIEngine  # noqa: E402
from ai.features import make_X  # noqa: E402
from ai.rules import rule_start_discount, weighted_rank_score  # noqa: E402

MIN_RANK_ROWS, MIN_RANK_POS, MIN_PRICE_ROWS = 1000, 150, 150


# ----------------------------------------------------------------- util
def time_split(df, time_col, group_col=None, fr=(0.70, 0.85)):
    """Split WAKTU (bukan acak). Untuk ranking, satu listing tidak boleh terbelah antar split."""
    t = pd.to_datetime(df[time_col], utc=True, format="ISO8601")
    if group_col:
        t = t.groupby(df[group_col]).transform("min")
    if t.nunique() < 20:   # seeder massal: semua timestamp nyaris sama -> split waktu tak bermakna
        print(f"[peringatan] hanya {t.nunique()} timestamp unik di '{time_col}'; "
              f"memakai urutan {group_col or 'baris'} sebagai proksi waktu")
        key = df[group_col] if group_col else pd.Series(np.arange(len(df)), index=df.index)
        t = key.rank(method="dense")
    q1, q2 = t.quantile(fr[0]), t.quantile(fr[1])
    return df[t <= q1], df[(t > q1) & (t <= q2)], df[t > q2]


def mono_list(features, mono: dict):
    return [mono.get(f, 0) for f in features]


def precision_at_k(df, score, k=C.TOP_K):
    tmp = pd.DataFrame({"listing_id": df["listing_id"].to_numpy(), "label": df["label"].to_numpy(),
                        "score": np.asarray(score, float)})
    vals = [g.nlargest(k, "score")["label"].mean() for _, g in tmp.groupby("listing_id") if len(g) >= k]
    return (float(np.mean(vals)) if vals else float("nan")), len(vals)


def bootstrap_p5_diff(df, score_a, score_b, k=C.TOP_K, n_boot=1000, seed=0):
    """Selisih P@5 (a - b) + CI 95% via bootstrap antar-listing. CI memotong 0 => belum terbukti."""
    tmp = pd.DataFrame({"listing_id": df["listing_id"].to_numpy(), "label": df["label"].to_numpy(),
                        "a": np.asarray(score_a, float), "b": np.asarray(score_b, float)})
    d = np.array([g.nlargest(k, "a")["label"].mean() - g.nlargest(k, "b")["label"].mean()
                  for _, g in tmp.groupby("listing_id") if len(g) >= k])
    rng = np.random.default_rng(seed)
    boots = np.array([rng.choice(d, len(d)).mean() for _ in range(n_boot)])
    return {"mean": float(d.mean()), "ci95_lo": float(np.percentile(boots, 2.5)),
            "ci95_hi": float(np.percentile(boots, 97.5))}


def preflight(pr, rk, min_rank_rows=MIN_RANK_ROWS, min_rank_pos=MIN_RANK_POS, min_price_rows=MIN_PRICE_ROWS):
    problems = []
    if len(rk) < min_rank_rows: problems.append(f"ranking: {len(rk)} baris < {min_rank_rows}")
    if rk["label"].sum() < min_rank_pos: problems.append(f"ranking: positif {int(rk['label'].sum())} < {min_rank_pos}")
    if rk["label"].nunique() < 2: problems.append("ranking: hanya satu kelas label")
    if len(pr) < min_price_rows: problems.append(f"pricing: {len(pr)} listing terjual < {min_price_rows}")
    for name, df in (("ranking", rk), ("pricing", pr)):
        if len(df) == 0: continue
        badc = set(df["category"]) - set(C.CATEGORIES)
        if badc: problems.append(f"{name}: kategori di luar config.CATEGORIES: {sorted(badc)}")
        bads = set(df["storage_type"]) - set(C.STORAGE_TYPES)
        if bads: problems.append(f"{name}: storage_type tak dikenal: {sorted(bads)}")
    print(f"[audit] ranking={len(rk)} baris, positif={rk['label'].mean():.1%}, listing={rk['listing_id'].nunique()}, "
          f"rata2 kandidat/listing={len(rk)/max(rk['listing_id'].nunique(),1):.1f}")
    print(f"[audit] pricing={len(pr)} listing terjual, clearing_discount mean={pr['clearing_discount_pct'].mean():.1f} "
          f"sd={pr['clearing_discount_pct'].std():.1f}")
    for p in problems: print("[audit] MASALAH:", p)
    return problems


# ----------------------------------------------------------------- ranking
def train_ranking(rk, seed):
    tr, va, te = time_split(rk, "sent_at", "listing_id")
    f, cat = C.RANKING_FEATURES, C.RANKING_CATEGORICAL
    Xtr, Xva, Xte = (make_X(d, f, cat) for d in (tr, va, te))
    params = dict(n_estimators=800, learning_rate=0.04, num_leaves=15, min_child_samples=25,
                  subsample=0.8, subsample_freq=1, colsample_bytree=0.8, reg_lambda=2.0,
                  monotone_constraints=mono_list(f, C.RANKING_MONOTONE), random_state=seed,
                  n_jobs=1, verbose=-1)
    m = lgb.LGBMClassifier(**params)
    m.fit(Xtr, tr["label"], eval_X=Xva, eval_y=va["label"], eval_metric="binary_logloss",
          callbacks=[lgb.early_stopping(40, verbose=False)])
    best = int(m.best_iteration_ or params["n_estimators"])
    p = m.predict_proba(Xte)[:, 1]
    y = te["label"].to_numpy()

    rep = {"n_train": len(tr), "n_valid": len(va), "n_test": len(te), "best_iteration": best,
           "auc": roc_auc_score(y, p), "logloss": log_loss(y, p), "brier": brier_score_loss(y, p),
           "brier_constant_baseline": brier_score_loss(y, np.full_like(p, tr["label"].mean(), dtype=float)),
           "auc_distance_baseline": roc_auc_score(y, -te["distance_km"]),
           "auc_weighted_baseline": roc_auc_score(y, weighted_rank_score(te))}
    rep["p5_model"], rep["n_listings_eval"] = precision_at_k(te, p)
    rep["p5_distance_baseline"], _ = precision_at_k(te, -te["distance_km"].to_numpy())
    rep["p5_weighted_baseline"], _ = precision_at_k(te, weighted_rank_score(te))
    rep["p5_diff_model_vs_weighted"] = bootstrap_p5_diff(te, p, weighted_rank_score(te))
    rep["p5_random"], _ = precision_at_k(te, np.random.default_rng(seed).random(len(te)))
    if "_true_p" in te:                       # hanya ada di data sintetis
        rep["p5_oracle_ceiling"], _ = precision_at_k(te, te["_true_p"])
        rep["p5_model_vs_oracle"] = rep["p5_model"] / rep["p5_oracle_ceiling"]

    # refit pada semua data dgn jumlah pohon terbaik -> artefak produksi
    full = pd.concat([tr, va, te])
    final = lgb.LGBMClassifier(**{**params, "n_estimators": best})
    final.fit(make_X(full, f, cat), full["label"])
    return final, rep


# ----------------------------------------------------------------- pricing
def pricing_predict_discount(model, df):
    """Pipeline lengkap seperti produksi: model -> headroom -> band -> clip min_price."""
    from ai.guardrails import clip_discount
    clearing = model.predict(make_X(df, C.PRICING_FEATURES, C.PRICING_CATEGORICAL))
    base = df["days_to_expiry"].map(rule_start_discount).to_numpy()
    d = np.clip(clearing - C.HEADROOM_PP, base - C.BAND_PP, base + C.BAND_PP)
    return np.array([clip_discount(x, n, m)[0] for x, n, m in zip(d, df["normal_price"], df["min_price"])])


def train_pricing(pr, seed):
    pr = pr.assign(label=1)
    tr, va, te = time_split(pr, "created_at")
    f, cat = C.PRICING_FEATURES, C.PRICING_CATEGORICAL
    Xtr, Xva, Xte = (make_X(d, f, cat) for d in (tr, va, te))
    params = dict(objective="huber", alpha=5.0, n_estimators=800, learning_rate=0.04, num_leaves=15,
                  min_child_samples=15, subsample=0.8, subsample_freq=1, colsample_bytree=0.9,
                  reg_lambda=1.0, monotone_constraints=mono_list(f, C.PRICING_MONOTONE),
                  random_state=seed, n_jobs=1, verbose=-1)
    m = lgb.LGBMRegressor(**params)
    m.fit(Xtr, tr["clearing_discount_pct"], eval_X=Xva, eval_y=va["clearing_discount_pct"],
          eval_metric="l1", callbacks=[lgb.early_stopping(40, verbose=False)])
    best = int(m.best_iteration_ or params["n_estimators"])
    y = te["clearing_discount_pct"].to_numpy()
    pred = m.predict(Xte)
    base_clear = te["days_to_expiry"].map(rule_start_discount).to_numpy() + C.HEADROOM_PP
    rep = {"n_train": len(tr), "n_valid": len(va), "n_test": len(te), "best_iteration": best,
           "mae_model_pp": mean_absolute_error(y, pred),
           "mae_rule_baseline_pp": mean_absolute_error(y, base_clear),
           "mae_constant_median_pp": mean_absolute_error(y, np.full_like(y, tr["clearing_discount_pct"].median()))}
    d_final = pricing_predict_discount(m, te)
    price = te["normal_price"].to_numpy() * (1 - d_final / 100)
    rep["guardrail_violations_min_price"] = int((price < te["min_price"].to_numpy() - 1e-6).sum())

    full = pd.concat([tr, va, te])
    final = lgb.LGBMRegressor(**{**params, "n_estimators": best})
    final.fit(make_X(full, f, cat), full["clearing_discount_pct"])
    return final, rep


# ----------------------------------------------------------------- simpan & ukur
def save(model, features, categorical, name, version, metrics, out: Path):
    bundle = dict(model=model, features=features, categorical=categorical, cat_levels=C.CAT_LEVELS,
                  version=version, trained_at=datetime.now(timezone.utc).isoformat(),
                  lib_versions={"lightgbm": lgb.__version__, "sklearn": sklearn.__version__},
                  metrics=metrics)
    path = out / name
    joblib.dump(bundle, path, compress=3)
    return path.stat().st_size


def measure_latency(out: Path, n=300):
    rng = np.random.default_rng(0)
    eng = AIEngine(out)
    buyers = pd.DataFrame({
        "buyer_id": np.arange(200), "base_lat": -7.7956 + rng.normal(0, .03, 200),
        "base_lng": 110.3695 + rng.normal(0, .03, 200), "max_radius_km": 15,
        "has_cold_storage": True, "pref_categories": [["Dairy", "Oil"]] * 200,
        "business_type": rng.choice(C.BUSINESS_TYPES, 200),
        "total_orders_completed": rng.integers(0, 60, 200),
        "payment_reliability_score": rng.uniform(.5, 1, 200)})
    L = dict(category="Dairy", storage_type="chilled", days_to_expiry=40, qty=300, normal_price=22000,
             min_price=6000, warehouse_lat=-7.7956, warehouse_lng=110.3695, offered_discount_pct=45)
    t_p, t_r = [], []
    for _ in range(n):
        s = time.perf_counter(); eng.advise_price(L); t_p.append((time.perf_counter() - s) * 1e3)
        s = time.perf_counter(); eng.match_buyers(L, buyers); t_r.append((time.perf_counter() - s) * 1e3)
    q = lambda a: {"p50_ms": float(np.percentile(a, 50)), "p95_ms": float(np.percentile(a, 95))}
    return {"advise_price": q(t_p), "match_buyers_200_candidates": q(t_r)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=["csv", "db"], default="csv")
    ap.add_argument("--data-dir", type=Path, default=C.DATA_DIR)
    ap.add_argument("--out", type=Path, default=C.MODEL_DIR)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--audit-only", action="store_true")
    ap.add_argument("--min-rank-rows", type=int, default=MIN_RANK_ROWS)
    ap.add_argument("--min-rank-pos", type=int, default=MIN_RANK_POS)
    ap.add_argument("--min-price-rows", type=int, default=MIN_PRICE_ROWS,
                    help="turunkan hanya sadar risiko: <150 listing => MAE uji sangat berisik")
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)

    if a.source == "csv":
        pr = pd.read_csv(a.data_dir / "pricing_seed.csv"); pr = pr[pr["sold"] == 1]
        rk = pd.read_csv(a.data_dir / "ranking_seed.csv")
    else:
        from scripts.load_from_db import load_frames
        pr, rk = load_frames()
    problems = preflight(pr, rk, a.min_rank_rows, a.min_rank_pos, a.min_price_rows)
    if a.audit_only:
        return
    if problems:
        sys.exit("Data belum layak dilatih -> tetap pakai rule-based. Perbaiki masalah di atas.")

    version = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M") + f"-{a.source}"
    rk_model, rk_rep = train_ranking(rk, a.seed)
    pr_model, pr_rep = train_pricing(pr, a.seed)
    s1 = save(rk_model, C.RANKING_FEATURES, C.RANKING_CATEGORICAL, "ranking_model.pkl", version, rk_rep, a.out)
    s2 = save(pr_model, C.PRICING_FEATURES, C.PRICING_CATEGORICAL, "pricing_model.pkl", version, pr_rep, a.out)
    lat = measure_latency(a.out)
    report = {"version": version, "source": a.source, "ranking": rk_rep, "pricing": pr_rep,
              "size_kb": {"ranking": s1 / 1024, "pricing": s2 / 1024}, "latency": lat}
    (a.out / "metrics.json").write_text(json.dumps(report, indent=2, default=float))

    gates = {
        "ranking AUC > distance baseline": rk_rep["auc"] > rk_rep["auc_distance_baseline"],
        "ranking P@5 >= weighted baseline": rk_rep["p5_model"] >= rk_rep["p5_weighted_baseline"],
        "ranking P@5 > weighted, signifikan (CI95 > 0)": rk_rep["p5_diff_model_vs_weighted"]["ci95_lo"] > 0,
        "ranking P@5 >= 0.70 (absolut, PRD)": rk_rep["p5_model"] >= 0.70,
        "pricing MAE <= 5 pp": pr_rep["mae_model_pp"] <= 5.0,
        "pricing MAE < rule baseline": pr_rep["mae_model_pp"] < pr_rep["mae_rule_baseline_pp"],
        "guardrail violation == 0": pr_rep["guardrail_violations_min_price"] == 0,
        "ukuran .pkl < 1 MB": max(s1, s2) < 1_048_576,
        "latensi p95 < 10 ms": max(v["p95_ms"] for v in lat.values()) < 10,
    }
    print(json.dumps(rk_rep, indent=1, default=lambda v: round(float(v), 4)))
    print(json.dumps(pr_rep, indent=1, default=lambda v: round(float(v), 4)))
    print("size KB:", {k: round(v, 1) for k, v in report["size_kb"].items()}, "| latency:", json.dumps(lat))
    for k, v in gates.items():
        print(("PASS " if v else "FAIL "), k)


if __name__ == "__main__":
    main()
