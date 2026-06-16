"""Aday tahmin yontemleri (plan-15 Faz 1) — 6 model yarisir.

Ortak arayuz:
    predict(train_daily, target_start, target_end) -> {"point": float, "components": {...}}
  train_daily : gunluk [ds,y], hedef aydan ONCE (cutoff = bilgi siniri — sizinti yok).
  target_start/end : hedef ay [ilk gun, sonraki ay ilk gunu) — TAM ay tahmini.
Band model-basina degil; backtest residual'undan (learn.py) turetilir.
"""
from __future__ import annotations

import warnings

import numpy as np
import pandas as pd

from calendar_reg import build_regressors

# ---------- yardimcilar ----------

def _monthly(daily: pd.DataFrame) -> pd.Series:
    """Gunluk → aylik toplam Series (index = ay-basi Timestamp)."""
    s = daily.set_index("ds")["y"].resample("MS").sum()
    return s


def _shift_month(ts: pd.Timestamp, n: int) -> pd.Timestamp:
    return (ts + pd.offsets.MonthBegin(n)) if n >= 0 else (ts - pd.offsets.MonthBegin(-n))


# ---------- 1. seasonal_naive ----------

def predict_seasonal_naive(train_daily, target_start, target_end):
    """Gecen yil ayni ay toplami."""
    gy_start = target_start - pd.DateOffset(years=1)
    gy_end = target_end - pd.DateOffset(years=1)
    mask = (train_daily["ds"] >= gy_start) & (train_daily["ds"] < gy_end)
    if not mask.any():
        return {"point": float("nan"), "components": {}}
    return {"point": float(train_daily.loc[mask, "y"].sum()), "components": {"gecen_yil": float(train_daily.loc[mask, "y"].sum())}}


# ---------- 2. heuristik (mevcut YoY x ivme) ----------

def predict_heuristik(train_daily, target_start, target_end):
    m = _monthly(train_daily)
    base = m.get(_shift_month(target_start, -12), np.nan)
    cutoff = _shift_month(target_start, -1)  # hedeften onceki ay = "bugun" ayi
    rates = []
    for i in range(1, 4):
        k = m.get(_shift_month(cutoff, -i + 1), np.nan)
        kp = m.get(_shift_month(cutoff, -i + 1 - 12), np.nan)
        if np.isfinite(k) and np.isfinite(kp) and kp > 0:
            rates.append(k / kp - 1)
    if not np.isfinite(base) or base <= 0 or len(rates) < 2:
        return {"point": float("nan"), "components": {}}
    ivme = float(np.mean(rates))
    return {"point": float(base * (1 + ivme)),
            "components": {"taban": float(base), "ivme_pct": round(100 * ivme, 2)}}


# ---------- 3. dow_ewma ----------

def predict_dow_ewma(train_daily, target_start, target_end):
    d = train_daily.copy()
    if len(d) < 90:
        return {"point": float("nan"), "components": {}}
    # Seviye: son 56 gun EWMA (span 28).
    level = float(d["y"].tail(56).ewm(span=28).mean().iloc[-1])
    # Gun-of-hafta profili (son 90 gun), ortalama 1'e normalize.
    recent = d.tail(90).copy()
    recent["dow"] = recent["ds"].dt.dayofweek
    dow_mean = recent.groupby("dow")["y"].mean()
    dow_prof = (dow_mean / dow_mean.mean()).reindex(range(7)).fillna(1.0)
    # Ay endeksi (tum gecmis), ortalama 1'e normalize.
    d2 = d.copy()
    d2["mon"] = d2["ds"].dt.month
    mon_mean = d2.groupby("mon")["y"].mean()
    mon_idx = (mon_mean / mon_mean.mean())
    midx = float(mon_idx.get(target_start.month, 1.0))
    rng = pd.date_range(target_start, target_end - pd.Timedelta(days=1), freq="D")
    total = sum(level * float(dow_prof[ts.dayofweek]) * midx for ts in rng)
    return {"point": float(total), "components": {"seviye_gun": round(level), "ay_endeksi": round(midx, 3)}}


# ---------- 4. glm_calendar (OLS: trend + Fourier + tatil regresor) ----------

_WEEK_K = 2
_YEAR_K = 3
_REG_COLS = ["bayram", "arife", "bayram_oncesi", "ulusal", "okul_acik", "sinav"]


def _design(ds: pd.DatetimeIndex, t0: pd.Timestamp) -> tuple[np.ndarray, list[str]]:
    ds = pd.DatetimeIndex(ds)
    n = len(ds)
    cols, names = [np.ones(n)], ["intercept"]
    # trend (yil cinsinden)
    t = (ds - t0).days.to_numpy(dtype=float) / 365.25
    cols.append(t); names.append("trend")
    # haftalik Fourier
    wk = ds.dayofweek.to_numpy(dtype=float)
    for k in range(1, _WEEK_K + 1):
        cols.append(np.sin(2 * np.pi * k * wk / 7)); names.append(f"wk_sin{k}")
        cols.append(np.cos(2 * np.pi * k * wk / 7)); names.append(f"wk_cos{k}")
    # yillik Fourier
    doy = ds.dayofyear.to_numpy(dtype=float)
    for k in range(1, _YEAR_K + 1):
        cols.append(np.sin(2 * np.pi * k * doy / 365.25)); names.append(f"yr_sin{k}")
        cols.append(np.cos(2 * np.pi * k * doy / 365.25)); names.append(f"yr_cos{k}")
    # tatil/okul regresor
    reg = build_regressors(ds)
    for c in _REG_COLS:
        cols.append(reg[c].to_numpy(dtype=float)); names.append(c)
    return np.column_stack(cols), names


def predict_glm_calendar(train_daily, target_start, target_end):
    """OLS LOG olcekte (log1p) — yuksek enflasyonda carpimsal buyume log'da lineer.
    Bilesen atifi: leave-one-out (grubu sifirla, fark = o grubun ay-toplamina katkisi)."""
    if len(train_daily) < 180:
        return {"point": float("nan"), "components": {}}
    t0 = train_daily["ds"].iloc[0]
    X, names = _design(pd.DatetimeIndex(train_daily["ds"]), t0)
    y = np.log1p(train_daily["y"].clip(lower=0).to_numpy(dtype=float))  # log olcek
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)

    rng = pd.date_range(target_start, target_end - pd.Timedelta(days=1), freq="D")
    Xf, _ = _design(rng, t0)
    daily_pred = np.expm1(Xf @ beta)            # log → seviye
    daily_pred = np.clip(daily_pred, 0, None)
    point = float(daily_pred.sum())

    # Bilesen atifi: grubu sifirla → toplam dususu = o grubun katkisi (log-carpimsal, level fark).
    groups = {
        "haftalik": [i for i, nm in enumerate(names) if nm.startswith("wk_")],
        "yillik": [i for i, nm in enumerate(names) if nm.startswith("yr_")],
        "tatil_okul": [i for i, nm in enumerate(names) if nm in _REG_COLS],
    }
    comp = {}
    for g, idx in groups.items():
        Xz = Xf.copy(); Xz[:, idx] = 0.0
        base_wo = float(np.clip(np.expm1(Xz @ beta), 0, None).sum())
        comp[g] = round(point - base_wo)
    comp["taban_trend"] = round(point - comp["haftalik"] - comp["yillik"] - comp["tatil_okul"])
    return {"point": point, "components": comp}


# ---------- 5/6. statsforecast (aylik AutoETS / AutoARIMA) ----------

def _sf_predict(model_ctor, train_daily, target_start, target_end):
    try:
        m = _monthly(train_daily)
        m = m[m.index < target_start]
        if len(m) < 24:
            return {"point": float("nan"), "components": {}}
        h = (target_start.to_period("M") - m.index[-1].to_period("M")).n
        if h < 1:
            return {"point": float("nan"), "components": {}}
        y = m.to_numpy(dtype=float)
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            mdl = model_ctor()
            fc = mdl.forecast(y=y, h=h)
        point = float(fc["mean"][-1])
        return {"point": point, "components": {"h_ay": h}}
    except Exception as e:  # statsforecast yoksa/patlarsa bu aday atlanir (sessiz degil — caller loglar)
        return {"point": float("nan"), "components": {"hata": str(e)[:80]}}


def predict_autoets(train_daily, target_start, target_end):
    from statsforecast.models import AutoETS
    return _sf_predict(lambda: AutoETS(season_length=12), train_daily, target_start, target_end)


def predict_autoarima(train_daily, target_start, target_end):
    from statsforecast.models import AutoARIMA
    return _sf_predict(lambda: AutoARIMA(season_length=12), train_daily, target_start, target_end)


# ---------- kayit ----------

MODELS = {
    "seasonal_naive": predict_seasonal_naive,
    "heuristik": predict_heuristik,
    "dow_ewma": predict_dow_ewma,
    "glm_calendar": predict_glm_calendar,
    "autoets": predict_autoets,
    "autoarima": predict_autoarima,
}


if __name__ == "__main__":
    from data import get_daily_series
    daily = get_daily_series()
    daily = daily[daily["ds"] < pd.Timestamp("2026-06-01")]  # bugunku kismi ayi cikar
    ts = pd.Timestamp("2026-05-01"); te = pd.Timestamp("2026-06-01")  # Mayis tahmini
    gercek = None
    print(f"Hedef: Mayis 2026 (train < {ts.date()})\n")
    for ad, fn in MODELS.items():
        r = fn(daily[daily["ds"] < ts], ts, te)
        p = r["point"]
        print(f"  {ad:16s} {p:>14,.0f}" if np.isfinite(p) else f"  {ad:16s} {'NaN':>14s}   {r['components']}")
