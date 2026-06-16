"""Rolling-origin backtest + hata atifi (plan-15 Faz 1).

Her gecmis (tam) ay icin: train = o aydan ONCEKI gunler → her model tahmin → gercekle kiyas.
Veri sizintisi yok (cutoff = ay basi). Cikti: model x ay hata matrisi + ozet (MAPE, bias).
Bu, ogrenen katmanin (learn.py) egitim verisi.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from models import MODELS


def complete_months(daily: pd.DataFrame) -> list[pd.Timestamp]:
    """Veride TAM gozlenmis ay-basi listesi (son kismi ay haric)."""
    last = daily["ds"].max()
    last_complete_end = pd.Timestamp(last.year, last.month, 1)  # icinde bulunulan ayin basi = sinir
    months = pd.date_range(daily["ds"].min().to_period("M").to_timestamp(),
                           last_complete_end, freq="MS")
    # son eleman = mevcut (kismi) ay basi → onu cikar; bir onceki = son tam ay
    return [m for m in months if m < last_complete_end]


def rolling_backtest(daily: pd.DataFrame, n_months: int = 18) -> pd.DataFrame:
    """Son n_months tam ay icin rolling-origin tahmin/gercek/hata (her model)."""
    comps = complete_months(daily)
    hedefler = comps[-n_months:] if len(comps) > n_months else comps
    kayit = []
    for mt in hedefler:
        te = mt + pd.offsets.MonthBegin(1)
        train = daily[daily["ds"] < mt]
        actual = float(daily[(daily["ds"] >= mt) & (daily["ds"] < te)]["y"].sum())
        if actual <= 0:
            continue
        for ad, fn in MODELS.items():
            try:
                p = fn(train, mt, te)["point"]
            except Exception as e:
                p = float("nan")
                print(f"[backtest] {ad} {mt.date()} HATA: {str(e)[:60]}")
            if np.isfinite(p):
                kayit.append({"ay": mt, "model": ad, "tahmin": p, "gercek": actual,
                              "hata": p - actual, "ape": abs(p - actual) / actual})
    return pd.DataFrame(kayit)


def model_ozet(bt: pd.DataFrame) -> pd.DataFrame:
    """Model basina MAPE + bias (ort. isaretli % hata) + gozlem sayisi."""
    g = bt.groupby("model")
    out = pd.DataFrame({
        "mape": g["ape"].mean() * 100,
        "bias_pct": (g.apply(lambda d: (d["hata"] / d["gercek"]).mean(), include_groups=False)) * 100,
        "n": g.size(),
    })
    return out.sort_values("mape")


if __name__ == "__main__":
    import pandas as pd
    from data import get_daily_series
    daily = get_daily_series()
    bt = rolling_backtest(daily, n_months=18)
    ozet = model_ozet(bt)
    print(f"Backtest: {bt['ay'].nunique()} ay x {bt['model'].nunique()} model\n")
    print("Model dogruluk (MAPE artan):")
    for m, r in ozet.iterrows():
        print(f"  {m:16s} MAPE {r['mape']:5.1f}%  bias {r['bias_pct']:+6.1f}%  n={int(r['n'])}")
