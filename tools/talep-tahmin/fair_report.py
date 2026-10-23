"""Adil (sansür-farkında) ölçüt raporu: cWAPE / c_sRMSE, katman × sezon/normal, eşleştirilmiş bootstrap.
Kullanım: python fair_report.py <points.csv>"""
import sys

import numpy as np
import pandas as pd

d = pd.read_csv(sys.argv[1])
d["dönem"] = np.where(d.sezon.fillna("normal").str.startswith("sezon"), "sezon", "normal")
METH = ["MA(13)", "SES(0.5)", "v3:global-GBM(fiyatsız)", "v4:geo(v3,SES0.5)", "v5:+sansür", "v5:+sansür ⊕SES(geo,ilk1000)",
        "v6:+sansür+takvim+büyüme", "v6:+sansür+takvim+büyüme ⊕SES(geo,ilk1000)"]
d = d[d.yöntem.isin(METH)]
pd.set_option("display.width", 220)
rng = np.random.default_rng(0)


def boot(x):
    b = [rng.choice(x, len(x)).mean() for _ in range(5000)]
    return np.quantile(b, [0.025, 0.975])


for kt in ("ilk100", "ilk1000", "kuyruk", "tümü"):
    t = d[(d.faz == "test") & (d.katman == kt)]
    a = d[(d.faz == "ayar") & (d.katman == kt)].groupby("yöntem").cWAPE.mean().rename("ayar_cWAPE")
    tab = t.groupby(["yöntem", "dönem"]).agg(cWAPE=("cWAPE", "mean"), c_sRMSE=("c_sRMSE", "mean"),
                                           sansür=("sansür_oranı", "mean"), origin=("T", "nunique")).unstack("dönem")
    tab.columns = [f"{m}·{p}" for m, p in tab.columns]
    tab["cWAPE·tümü"] = t.groupby("yöntem").cWAPE.mean()
    tab = tab.join(a).sort_values("ayar_cWAPE")
    print(f"\n== {kt} — TEST adil ölçüt (sıra: AYAR cWAPE)")
    print(tab[["ayar_cWAPE", "cWAPE·tümü", "cWAPE·normal", "cWAPE·sezon", "c_sRMSE·normal", "c_sRMSE·sezon",
               "sansür·normal", "sansür·sezon", "origin·normal", "origin·sezon"]].round(3).to_string())
    best_ayar = tab.index[0]
    for ref in ("MA(13)", "v4:geo(v3,SES0.5)", "v3:global-GBM(fiyatsız)"):
        for cand in ("v6:+sansür+takvim+büyüme ⊕SES(geo,ilk1000)", "v6:+sansür+takvim+büyüme"):
            if cand == ref: continue
            x = t[t.yöntem == cand].set_index("T").cWAPE; y = t[t.yöntem == ref].set_index("T").cWAPE
            df = (x - y).dropna().to_numpy(); lo, hi = boot(df)
            print(f"   {cand[:34]:34s} − {ref:24s}: {df.mean():+.3f} [{lo:+.3f},{hi:+.3f}] daha iyi {int((df < 0).sum())}/{len(df)}")
    print(f"   AYAR'a göre seçilen: {best_ayar}")
