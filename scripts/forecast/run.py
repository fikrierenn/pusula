"""Orkestrasyon (plan-15 Faz 1): backtest → ogren → aktif tahmin → JSON.

Cikti (dashboard/data/forecast/ — C# ForecastOkuService okur):
  tahmin-aylik.json     aktif aylar (bu ay + sonraki 3) ensemble + bilesen + model katki
  backtest-gecmis.json  rolling-origin model x ay (dashboard backtest dogruluk paneli)
  yontem-agirlik.json   ogrenilen agirlik/bias/band (seffaflik)
"""
from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

from data import get_daily_series
from models import MODELS, predict_glm_calendar
from backtest import rolling_backtest, model_ozet
from learn import ogren, ensemble_tahmin

_OUT = Path(__file__).resolve().parent.parent.parent / "dashboard" / "data" / "forecast"


def _ay_tahmin(daily, yil, ay, ogrenilen):
    """Bir hedef ay: tum modeller + ensemble + glm bilesen yorumu."""
    ts = pd.Timestamp(yil, ay, 1)
    te = ts + pd.offsets.MonthBegin(1)
    train = daily[daily["ds"] < ts]
    model_nokta, katki = {}, {}
    for ad, fn in MODELS.items():
        try:
            p = fn(train, ts, te)["point"]
        except Exception:
            p = float("nan")
        if np.isfinite(p):
            model_nokta[ad] = float(p)
            katki[ad] = {"tahmin": round(p), "agirlik": ogrenilen["modeller"].get(ad, {}).get("agirlik", 0)}
    ens = ensemble_tahmin(model_nokta, ogrenilen)
    glm = predict_glm_calendar(train, ts, te)  # yorumlanabilir bilesen (ensemble noktasi degil)
    return {
        "yil": yil, "ay": ay,
        "point": ens.get("point"), "alt": ens.get("alt"), "ust": ens.get("ust"),
        "modeller": katki,
        "bilesen": glm.get("components", {}),  # glm_calendar yorumu (taban_trend/haftalik/yillik/tatil_okul)
    }


def main(n_ileri: int = 3):
    daily = get_daily_series()
    son = daily["ds"].max()
    print(f"[run] gunluk seri {daily['ds'].min().date()} - {son.date()} ({len(daily)} gun)")

    bt = rolling_backtest(daily, n_months=18)
    ogrenilen = ogren(bt)
    ozet = model_ozet(bt)
    print("[run] backtest + ogrenme tamam")

    # Aktif aylar: bu ay + sonraki n_ileri.
    bu = pd.Timestamp(son.year, son.month, 1)
    aylar = []
    for k in range(0, n_ileri + 1):
        t = bu + pd.offsets.MonthBegin(k)
        aylar.append(_ay_tahmin(daily, t.year, t.month, ogrenilen))

    uretim = datetime.now().strftime("%d.%m.%Y %H:%M")
    _OUT.mkdir(parents=True, exist_ok=True)
    _yaz(_OUT / "tahmin-aylik.json", {"uretim": uretim, "seri_son": str(son.date()), "aylar": aylar})
    _yaz(_OUT / "yontem-agirlik.json", {"uretim": uretim, **ogrenilen,
         "ozet": {m: {"mape": round(r["mape"], 2), "bias_pct": round(r["bias_pct"], 2), "n": int(r["n"])}
                  for m, r in ozet.iterrows()}})
    _yaz(_OUT / "backtest-gecmis.json", {"uretim": uretim,
         "kayitlar": [{"ay": str(r["ay"].date()), "model": r["model"], "tahmin": round(r["tahmin"]),
                       "gercek": round(r["gercek"]), "ape": round(r["ape"] * 100, 2)}
                      for _, r in bt.iterrows()]})
    print(f"[run] JSON yazildi -> {_OUT}")
    for a in aylar:
        print(f"  {a['yil']}-{a['ay']:02d}: ensemble {a['point']:,} band [{a['alt']:,} - {a['ust']:,}]")


def _yaz(path: Path, obj: dict):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
