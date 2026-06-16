"""Ogrenen katman (plan-15 Faz 1): adaptif ensemble + bias duzeltme.

Backtest'ten (model x ay hata) ogren:
  - recency-agirlikli MAPE → ensemble agirligi (iyi model agir; unutma faktoru ile yakin aylar onemli).
  - isaretli bias → de-bias (her model tahmini bias'tan arindirilip birlestirilir).
  - band: ensemble'in gecmis isaretli hatalarinin kantili (parametrik degil, gozlemlenen).
Hicbir sey sessiz: agirlik/bias/clamp loglanabilir (run.py JSON'a yazar).
"""
from __future__ import annotations

import numpy as np
import pandas as pd


def _recency_weights(aylar: pd.Series, lam: float = 0.9) -> pd.Series:
    """Unutma faktoru: en yeni ay agirlik 1, her ay geriye lam^k. (AEC forgetting.)"""
    sirali = sorted(aylar.unique())
    rank = {m: i for i, m in enumerate(sirali)}          # eski=0 ... yeni=N-1
    n = len(sirali)
    return aylar.map(lambda m: lam ** (n - 1 - rank[m]))


def ogren(bt: pd.DataFrame, lam: float = 0.9, mape_tavan: float = 40.0) -> dict:
    """Backtest → {model: {agirlik, bias_pct, wmape}} + ensemble band yuzdeleri."""
    bt = bt.copy()
    bt["rw"] = _recency_weights(bt["ay"], lam)

    info = {}
    for model, d in bt.groupby("model"):
        w = d["rw"]
        wmape = float((d["ape"] * w).sum() / w.sum()) * 100
        bias = float(((d["hata"] / d["gercek"]) * w).sum() / w.sum()) * 100
        info[model] = {"wmape": round(wmape, 2), "bias_pct": round(bias, 2)}

    # Agirlik: 1/wmape^2 (iyi model cok daha agir); MAPE tavanini asan model elenir (agirlik 0).
    ham = {m: (1.0 / (v["wmape"] ** 2) if v["wmape"] <= mape_tavan else 0.0) for m, v in info.items()}
    toplam = sum(ham.values()) or 1.0
    for m in info:
        info[m]["agirlik"] = round(ham[m] / toplam, 4)

    # Ensemble'i gecmise uygula → band icin isaretli hata dagilimi.
    resid = []
    for ay, d in bt.groupby("ay"):
        ens = _ensemble_point(d.set_index("model")["tahmin"].to_dict(), info)
        ger = float(d["gercek"].iloc[0])
        if ens is not None and ger > 0:
            resid.append((ens - ger) / ger)
    resid = np.array(resid) if resid else np.array([0.0])
    band = {
        "alt_pct": round(float(np.quantile(resid, 0.10)) * 100, 2),   # genelde negatif
        "ust_pct": round(float(np.quantile(resid, 0.90)) * 100, 2),
        "ensemble_mape": round(float(np.mean(np.abs(resid))) * 100, 2),
    }
    return {"modeller": info, "band": band, "lam": lam}


def _ensemble_point(model_tahmin: dict, info: dict):
    """De-bias edilmis agirlikli ortalama. model_tahmin: {model: ham_nokta}."""
    pay, agirlik_top = 0.0, 0.0
    for m, p in model_tahmin.items():
        if m not in info or not np.isfinite(p):
            continue
        a = info[m]["agirlik"]
        if a <= 0:
            continue
        debias = p / (1 + info[m]["bias_pct"] / 100)   # bias'tan arindir
        pay += a * debias
        agirlik_top += a
    return pay / agirlik_top if agirlik_top > 0 else None


def ensemble_tahmin(model_tahmin: dict, ogrenilen: dict) -> dict:
    """Aktif tahmin: de-bias agirlikli ensemble + ogrenilen band yuzdeleriyle alt/ust."""
    point = _ensemble_point(model_tahmin, ogrenilen["modeller"])
    if point is None:
        return {"point": None}
    b = ogrenilen["band"]
    return {
        "point": round(point),
        "alt": round(point * (1 + b["alt_pct"] / 100)),
        "ust": round(point * (1 + b["ust_pct"] / 100)),
    }


if __name__ == "__main__":
    from data import get_daily_series
    from backtest import rolling_backtest
    daily = get_daily_series()
    bt = rolling_backtest(daily, n_months=18)
    o = ogren(bt)
    print("Ogrenilen agirliklar (de-bias):")
    for m, v in sorted(o["modeller"].items(), key=lambda kv: -kv[1]["agirlik"]):
        print(f"  {m:16s} agirlik {v['agirlik']:.3f}  wMAPE {v['wmape']:5.1f}%  bias {v['bias_pct']:+6.1f}%")
    print(f"\nEnsemble band: [{o['band']['alt_pct']:+.1f}%, {o['band']['ust_pct']:+.1f}%]  ens-MAPE {o['band']['ensemble_mape']:.1f}%")
