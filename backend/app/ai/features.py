"""Pembangun fitur TUNGGAL untuk training & serving (mencegah training-serving skew)."""
import pandas as pd
try:
    from .config import CAT_LEVELS
except ImportError:
    from app.ai.config import CAT_LEVELS


class FeatureError(ValueError):
    pass


def make_X(df: pd.DataFrame, features: list[str], categorical: list[str],
           cat_levels: dict | None = None) -> pd.DataFrame:
    cat_levels = cat_levels or CAT_LEVELS
    missing = [c for c in features if c not in df.columns]
    if missing:
        raise FeatureError(f"kolom fitur hilang: {missing}")
    X = df[features].copy()                       # urutan kolom DIKUNCI oleh `features`
    for c in features:
        if c in categorical:
            bad = X[c].notna() & ~X[c].isin(cat_levels[c])
            if bad.any():
                raise FeatureError(f"kategori tak dikenal di '{c}': {sorted(set(X[c][bad]))}")
            X[c] = pd.Categorical(X[c], categories=cat_levels[c])
        else:
            X[c] = X[c].astype(float)
    return X


def make_matrix(df: pd.DataFrame, features: list[str], categorical: list[str],
                cat_levels: dict | None = None):
    """Jalur CEPAT untuk serving (tanpa overhead pandas Categorical). Kolom kategorikal -> kode
    integer = posisi di cat_levels, IDENTIK dengan kode pandas saat training (teruji di tests)."""
    import numpy as np
    cat_levels = cat_levels or CAT_LEVELS
    missing = [c for c in features if c not in df.columns]
    if missing:
        raise FeatureError(f"kolom fitur hilang: {missing}")
    cols = []
    for c in features:
        if c in categorical:
            codes = pd.Index(cat_levels[c]).get_indexer(df[c].to_numpy())
            if (codes < 0).any():
                raise FeatureError(f"kategori tak dikenal di '{c}': {sorted(set(df[c].to_numpy()[codes < 0]))}")
            cols.append(codes.astype(float))
        else:
            cols.append(df[c].to_numpy(dtype=float))
    return np.column_stack(cols)
